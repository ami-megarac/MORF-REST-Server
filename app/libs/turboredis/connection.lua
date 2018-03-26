local turbo = require("turbo")
local middleclass =  require("turbo.3rdparty.middleclass")
local ffi = require("ffi")
local yield = coroutine.yield
local task = turbo.async.task
local util = require("turboredis.util")
local Command = require("turboredis.command")
local PipeLine = require("turboredis.pipeline")
local COMMANDS = require("turboredis.commands")

-- ## Connection ##
-- The main class that handles connecting and issuing commands.
--
local Connection = class("Connection")

-- Create a new connection object, ready to connect to Redis.
--
-- Parameters:
--
-- - host[string|nil]: Redis instance hostname or IP address.
--   If set to nil this defaults to "127.0.0.1"
-- - port[int]: Port
-- - opts[table]: Table of options.
--      - ioloop: The ioloop to use, defaults to turbo.ioloop.instance()
--      - connect_timeout[int]: The connect timeout in seconds. Defaults to 5.
--
function Connection:initialize(host, port, opts)
    opts = opts or {}
    self.host = host or "127.0.0.1"
    self.port = port or 6379
    self.family = 2
    self.ioloop = opts.ioloop or turbo.ioloop.instance()
    self.connect_timeout = opts.connect_timeout or 5
end

function Connection:_connect(callback, callback_arg)
    local function connect_done(a1, a2)
        if callback_arg then
            callback(callback_arg, a1, a2)
        else
            callback(a1, a2)
        end
    end
    
    local connect_timeout_ref
    local function handle_connect()
        self.ioloop:remove_timeout(connect_timeout_ref)
        connect_done(true, {msg="OK"})
    end

    local function handle_connect_timeout()
        self.ioloop:remove_timeout(connect_timeout_ref)
        connect_done(false, {err=-1, msg="Connect timeout"})
    end

    local function handle_connect_error(err, strerror)
        self.ioloop:remove_timeout(connect_timeout_ref)
        connect_done(false, {err=err, msg=strerror})
    end

    self.ioloop = turbo.ioloop.instance()
    timeout = (self.connect_timeout * 1000) + turbo.util.gettimeofday()
    connect_timeout_ref = self.ioloop:add_timeout(timeout,
                                                  handle_connect_timeout)
    self.sock, msg = turbo.socket.new_nonblock_socket(self.family,
                                                      turbo.socket.SOCK_STREAM,
                                                      0)
    if self.sock == -1 then
        handle_connect_error(-1, msg)
        return -1
    end

    self.stream = turbo.iostream.IOStream:new(self.sock, self.ioloop)
    local rc, msg = self.stream:connect(self.host,
                                   self.port,
                                   self.family,
                                   handle_connect,
                                   handle_connect_error,
                                   self)
    if rc ~= 0 then
        handle_connect_error(-1, "Connect failed")
        return -1 --wtf
    end
end


function Connection:connect(callback, callback_arg)
    if callback then
        return self:_connect(callback, callback_arg)
    else
        return task(self._connect, self)
    end
end

function Connection:_disconnect(callback, callback_arg)
    function handle_disconnect()
        if callback_arg then
            callback(callback_arg, true)
        else
            callback(true)
        end
    end
    self.stream:set_close_callback(handle_disconnect, self)
    self.stream:close()
    self:deallocate()
end

function Connection:disconnect(callback, callback_arg)
    if callback then
        return self:_disconnect(callback, callback_arg)
    else
        return task(self._disconnect, self)
    end
end

-- Create a new `Command` and run it.
function Connection:_run(cmd, callback, callback_arg)
    local command = Command:new(cmd, self.stream, {})
    return command:execute(callback, callback_arg)
end

-- Run a command without reading the reply
function Connection:_run_noreply(cmd, callback, callback_arg)
    local command = Command:new(cmd, self.stream, {})
    return command:execute_noreply(callback, callback_arg)
end

function Connection:cmd(cmd, callback, callback_arg)
    if callback then
        return self:_run(cmd, callback, callback_arg)
    else
        return task(self._run, self, cmd)
    end
end

function Connection:cmd_noreply(cmd, callback, callback_arg)
    if callback then
        return self:_run_noreply(cmd, callback, callback_arg)
    else
        return task(self._run_noreply, self, cmd)
    end
end

function Connection:pipeline()
    return PipeLine:new(self)
end

function Connection:deallocate()
    self.stream = nil
    self.host = nil
    self.port = nil
    self.family = nil
    self.ioloop = nil
    self.connect_timeout = nil
end

-- Generate functions for all commands in `COMMANDS`
--
-- This applies to all commands except for
-- SUBSCRIBE/UNSUBSCRIBE pubsub commands.
--
-- See http://redis.io for documentation for specific commands.
--
for _, v in ipairs(COMMANDS) do
    Connection[v:lower():gsub(" ", "_")] = function (self, ...)
        local cmd = util.flatten({v:split(" "), ...})
        local callback = false
        local callback_arg = nil
        if type(cmd[#cmd]) == "function" then
            callback = cmd[#cmd]
            cmd[#cmd] = nil
        elseif type(cmd[#cmd-1]) == "function" then
            callback = cmd[#cmd-1]
            callback_arg = cmd[#cmd]
            cmd[#cmd-1] = nil
            cmd[#cmd] = nil
        end

        if callback then
            return self:_run(cmd, callback, callback_arg)
        else
            return task(self._run, self, cmd)
        end
    end
end

return Connection
