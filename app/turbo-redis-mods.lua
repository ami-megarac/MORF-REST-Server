-------------
-- Turboredis Mods
-- @module turboredis mods
-- @author AMI MegaRAC
-- @license AMI
-- @copyright AMI 2015

-- [See "turbo library"](http://turbolua.org)
local turbo = require("turbo")
-- [See "odata-handler.lua"](/odata-handler.html)
local ODataHandler = require("odata-handler")
local _ = require("underscore")
-- [See "config.lua"](/config.html)
local CONFIG = require("config")
-- [See "constants.lua"](/constants.html)
local CONSTANTS = require("constants")
-- [See "turboredis.lua"](/turboredis.html)
local turboredis = require("turboredis")
-- [See "utils.lua"](/utils.html)
local utils = require("utils")
-- [See "luajit ffi"](http://luajit.org/ext_ffi.html)
local ffi = require('ffi')

local yield = coroutine.yield
local task = turbo.async.task

-- This file contains some modified turboredis and turbo functions that are used in place of the stock functions to give Redfish some
-- extra capabilities.
--
-- list of modifications:
-- 1. redis pipelines w/ transactions
-- 2. turboredis.Connection w/ socket family option
-- 3. turbo.iostream.connect w/ unix sockets

local turboredis_mods = {}

-----------------------------------------------------------------------------------------------------------------------

-- MOD 1: redis pipelines w/ transactions
-- This function is a modified version of turboredis.pipeline._run that adds a redis transaction (MULTI/EXEC)
-- block around the pipeline commands to ensure database access is atomic

local resp = turboredis.resp
turboredis_mods._pipeline_run_with_transaction = function(self, callback, callback_arg)
    self.running = true
    -- Don't re-create the buffer if the user is reusing
    -- this pipeline
    if self.buf == nil then
        -- FIXME: This should probably be tweaked/configurable
        self.buf = turbo.structs.buffer(128*#self.pending_commands)
    end
    -- surround pipeline commands with MULTI/EXEC to make it a transaction block
    self.buf:append_luastr_right(resp.pack({"MULTI"}))
    for i, cmdt in ipairs(self.pending_commands) do
        local cmdstr = resp.pack(cmdt)
        self.buf:append_luastr_right(cmdstr)
    end
    self.buf:append_luastr_right(resp.pack({"EXEC"}))
    self.con.stream:write_buffer(self.buf, function ()
        local replies = {}
        local multi_res = yield(task(resp.read_resp_reply, self.con.stream, false))
        if not multi_res[1] then
            turbo.log.notice(turbo.log.stringify(multi_res, "MULTI"))
        end
        for i, v in ipairs(self.pending_commands) do
            local res = yield(task(resp.read_resp_reply,
                self.con.stream, false))
            if not res[1] then
                turbo.log.error("Error while adding command to redis transaction:")
                turbo.log.error(res[2])
                turbo.log.error(turbo.log.stringify(v, "Command"))
            end
        end
        local replies = yield(task(resp.read_resp_reply, self.con.stream, false))
        self.running = false
        if callback_arg then
            callback(callback_arg, replies)
        else
            callback(replies)
        end
    end)
end

-----------------------------------------------------------------------------------------------------------------------

-- MOD 2: turboredis.Connection w/ socket family option
-- This function is a modified version of turboredis.connection.initialize that allows the socket family to be given
-- in the options table (opts.family)
-- NOTE: to actually use a certain socket family, it must be added to the underlying implementation (turbo.iostream)
-- Mod 3 adds support for the AF_UNIX family (UNIX domain sockets) to turbo.iostream


turboredis_mods._new_connection_with_family = function(self, host, port, opts)
    opts = opts or {}
    self.host = host or "127.0.0.1"
    self.port = port or 6379
    self.family = opts.family or turbo.socket.AF_INET
    self.ioloop = opts.ioloop or turbo.ioloop.instance()
    self.connect_timeout = opts.connect_timeout or 5
end


-----------------------------------------------------------------------------------------------------------------------

-- MOD 3: turbo.iostream.connect w/ unix sockets
-- This function is a modified version of turbo.iostream.IOStream.connect that adds support for UNIX domain sockets
-- To use UDS with this mod, the socket path should be passed via the address parameter, and the family parameter should be set to AF_UNIX
-- NOTE: This mod is required to for Mod 2 to use AF_UNIX sockets


ffi.cdef[[
    struct sockaddr_un{
        unsigned short sun_family;
        char sun_path[108];
    };
]]
turboredis_mods._iostream_connect_with_uds = function (self, address, port, family,
    callback, errhandler, arg)
    assert(type(address) == "string",
        "argument #1, address, is not a string.")
    assert(type(port) == "number",
        "argument #2, ports, is not a number.")
    assert((not family or type(family) == "number"),
        "argument #3, family, is not a number or nil")

    local hints = ffi.new("struct addrinfo[1]")
    local servinfo = ffi.new("struct addrinfo *[1]")
    local rc

    self.address = address
    self.port = port
    self._connect_fail_callback = errhandler
    self._connecting = true
    if family == turbo.socket.AF_UNIX then
        local addr_un = ffi.new("struct sockaddr_un[1]")
        local info_un = ffi.new("struct addrinfo[1]")
        ffi.fill(info_un[0], ffi.sizeof(info_un[0]))

        addr_un[0].sun_family = family
        ffi.copy(addr_un[0].sun_path, address)

        info_un[0].ai_socktype = turbo.socket.SOCK_STREAM
        info_un[0].ai_family = family
        info_un[0].ai_protocol = 0

        info_un[0].ai_addrlen = ffi.sizeof(addr_un[0])
        info_un[0].ai_addr = ffi.cast("struct sockaddr *", addr_un)

        servinfo[0] = info_un
    else
        ffi.fill(hints[0], ffi.sizeof(hints[0]))
        hints[0].ai_socktype = turbo.socket.SOCK_STREAM
        hints[0].ai_family = family or turbo.socket.AF_UNSPEC
        hints[0].ai_protocol = 0
        rc = ffi.C.getaddrinfo(address, tostring(port), hints, servinfo)
        if rc ~= 0 then
            return -1, string.format("Could not resolve hostname '%s': %s",
                address, ffi.string(ffi.C.gai_strerror(rc)))
        end
        ffi.gc(servinfo, function (ai) ffi.C.freeaddrinfo(ai[0]) end)
    end

    local ai, err = turbo.sockutil.connect_addrinfo(self.socket, servinfo)
    if not ai then
        return -1, err
    end
    self._connect_callback = callback
    self._connect_callback_arg = arg
    self:_add_io_state(turbo.ioloop.WRITE)
    return 0
end

return turboredis_mods