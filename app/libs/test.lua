--
-- A set of very basic tests for turboredis
--
--


function trace (event, line)
  local s = debug.getinfo(2).short_src
  print(s .. ":" .. line)
end

local turbo = require("turbo")
LuaUnit = require("luaunit")
local turboredis = require("turboredis")
local yield = coroutine.yield
local ffi = require("ffi")
local os = require("os")
local dump = turbo.log.dump
ffi.cdef([[
unsigned int sleep(unsigned int seconds);
]])

local usage = [[
test.lua [-f/--fast] [--redis-host REDIS_HOST] [--redis-port REDIS_PORT] [-h/--help]
         [-U/--include-unstable-tests] [-I/--include-unsupported]
]]

local options = {
    host="127.0.0.1",
    port=6379,
    fast=false,
    include_unsupported=false,
    unstable=false
}

local i = 1
while i <= #arg do
    if arg[i] == "-f" or arg[i] == "--fast" then
        options.fast = true
    elseif arg[i] == "--include-unsupported" or arg[i] == "-I" then
        options.include_unsupported = true
    elseif arg[i] == "--include-unstable-tests" or arg[i] == "-U" then
        options.unstable = true
    elseif arg[i] == "--redis-host" then
        options.host = arg[i+1]
        if options.host == nil then
            print("Invalid option supplied to --redis-host")
            os.exit(1)
        end
        i = i + 1
    elseif arg[i] == "--redis-port" then
        options.port = tonumber(arg[i+1])
        if options.port == nil then
            print("Invalid option supplied to --redis-port")
            os.exit(1)
        end
        i = i + 1
    elseif arg[i] == "-h" or arg[i] == "--help" then
        print(usage)
        os.exit()
    end
    i = i+1
end
arg = {}

if not options.include_unsupported then
    print("IMPORTANT: Ignoring tests for unsupported / potentially unsupported commands")
end


function table_findval(haystack, needle)

end

function assertTableHas(t, needle)
    local r = false
    for _, v in ipairs(t) do
        if v == needle then
            r = true
        end
    end
    assert(r, "Could not find '" .. tostring(needle) .. "' in table.")
end


TestTurboRedis = {}

function TestTurboRedis:setUp()
    local r
    self.con = turboredis.Connection:new(options.host, options.port)
    r = yield(self.con:connect())
    assert(r)
    r = yield(self.con:flushall())
    assert(r)
    self.con2 = turboredis.Connection:new(options.host, options.port)
    r = yield(self.con2:connect())
    assert(r)
end

function TestTurboRedis:tearDown()
    local r
    r = yield(self.con:disconnect())
    assert(r)
    r = yield(self.con2:disconnect())
    assert(r)
end


function TestTurboRedis:test_plaincmd()
    local r
    r = yield(self.con:cmd({"SET", "foo", "bar"}))
    assertEquals(r, true)
    r = yield(self.con:cmd({"GET", "foo"}))
    assertEquals(r, "bar")
end


--- Test by command

function TestTurboRedis:test_append()
    local r
    r = yield(self.con:set("test", "123"))
    assert(r)
    r = yield(self.con:get("test"))
    assertEquals(r, "123")
    r = yield(self.con:append("test", "456"))
    assert(r)
    r = yield(self.con:get("test"))
    assertEquals(r, "123456")
end

function TestTurboRedis:test_auth()
    local r
    r = yield(self.con:set("foo", "bar"))
    assertEquals(r, true)
    r = yield(self.con:config_set("requirepass", "hello123"))
    assertEquals(r, true)
    r = yield(self.con:get("foo"))
    assertEquals(r, false)
    r = yield(self.con:auth("hello"))
    assertEquals(r, false)
    r = yield(self.con:auth("hello123"))
    assertEquals(r, true)
    r = yield(self.con:get("foo"))
    assertEquals(r, "bar")
    r = yield(self.con:config_set("requirepass", ""))
    assertEquals(r, true)
end

if options.include_unsupported then
    function TestTurboRedis:test_bgrewriteaof()
        assert(false, "'BGREWRITEAOF' has no test yet.")
    end
end

if not options.fast and options.unstable then
    -- This occasionally fails due to a currently
    -- running background save operation
    function TestTurboRedis:test_bgsave()
        local r
        local time
        time = yield(self.con:lastsave())
        assert(time)
        r = yield(self.con:bgsave())
        assert(r)
        r = yield(self.con:lastsave())
        assert(time ~= r)
    end
end

function TestTurboRedis:test_bitcount()
    local r
    r = yield(self.con:set("test", "foobar"))
    assert(r)
    r = yield(self.con:bitcount("test", 0, 0))
    assertEquals(r, 4)
    r = yield(self.con:bitcount("test", 1, 1))
    assertEquals(r, 6)
    r = yield(self.con:bitcount("test", 1))
    assertEquals(r, false) -- Error reply
end

function TestTurboRedis:test_bitop()
    local r
    r = yield(self.con:set("t1", "aaabbb"))
    assert(r)
    r = yield(self.con:set("t2", "bbbccc"))
    assert(r)

    r = yield(self.con:bitop_and("dst", "t1", "t2"))
    assertEquals(r, 6)
    r = yield(self.con:get("dst"))
    assertEquals(r, "```bbb")

    r = yield(self.con:bitop_or("dst", "t1", "t2"))
    assertEquals(r, 6)
    r = yield(self.con:get("dst"))
    assertEquals(r, "cccccc")

    r = yield(self.con:bitop_xor("dst", "t1", "t2"))
    assertEquals(r, 6)
    r = yield(self.con:get("dst"))
    assertEquals(r, "\x03\x03\x03\x01\x01\x01")

    r = yield(self.con:bitop_xor("dst", "t1", "t2"))
    assertEquals(r, 6)
    r = yield(self.con:get("dst"))
    assertEquals(r, "\x03\x03\x03\x01\x01\x01")

    r = yield(self.con:bitop_not("dst", "t1"))
    assertEquals(r, 6)
    r = yield(self.con:get("dst"))
    assertEquals(r, "\x9e\x9e\x9e\x9d\x9d\x9d")
end

function TestTurboRedis:test_blpop()
    local r
    r = yield(self.con:rpush("foo", "bar"))
    assertEquals(r, 1)
    r = yield(self.con:blpop("foo", 1))
    assertEquals(r[1], "foo")
    assertEquals(r[2], "bar")
end

function TestTurboRedis:test_brpop()
    local r
    r = yield(self.con:rpush("foo", "bar"))
    assertEquals(r, 1)
    r = yield(self.con:rpush("foo", "barbar"))
    assertEquals(r, 2)
    r = yield(self.con:brpop("foo", 1))
    assertEquals(r[1], "foo")
    assertEquals(r[2], "barbar")
end

function TestTurboRedis:test_brpoplpush()
    local r
    r = yield(self.con:rpush("foolist", "foo"))
    assertEquals(r, 1)
    r = yield(self.con:rpush("foolist", "bar"))
    assertEquals(r, 2)
    r = yield(self.con:rpush("foolist", "foobar"))
    assertEquals(r, 3)
    r = yield(self.con:brpoplpush("foolist", "barlist", 1))
    assertEquals(r, "foobar")
    r = yield(self.con:lrange("barlist", 0, -1))
    assertEquals(r, {"foobar"})
end

if options.include_unsupported then
    function TestTurboRedis:test_client_kill()
        -- TODO: 1. Make another connection
        --       2. Kill it
        --       3. Verify that it is no longer working
        assert(false, "'CLIENT KILL' has no test yet.")
    end
end

function TestTurboRedis:test_client_list()
    local r
    r = turboredis.util.parse_client_list(yield(self.con:client_list()))
    assertEquals(type(r), "table")
    assert(#r >= 1)
    assert(type(r[1].fd) == "number")
    -- FIXME: Write serious test for this?
end

function TestTurboRedis:test_client_getname()
    local r
    r = yield(self.con:client_setname("foo"))
    assert(r)
    r = yield(self.con:client_getname())
    assertEquals(r, "foo")
end

function TestTurboRedis:test_client_setname()
    local r
    r = yield(self.con:client_setname("bar"))
    assert(r)
    r = yield(self.con:client_getname())
    assertEquals(r, "bar")
end

function TestTurboRedis:test_config_get()
    local r
    r = yield(self.con:config_get("port"))
    assert(r)
    assertEquals(r[1], "port")
    assertEquals(r[2], tostring(self.con.port))
    r = turboredis.util.from_kvlist(r)
    assertEquals(r["port"], tostring(self.con.port))
end

if options.include_unsupported then
    function TestTurboRedis:test_config_rewrite()
        assert(false, "'CONFIG REWRITE' has no test yet.")
    end
end

function TestTurboRedis:test_config_set()
    local r
    local old_appendonly = turboredis.util.from_kvlist(yield(
        self.con:config_get("appendonly")))["appendonly"]
    local new_appendonly = old_appendonly and "yes" or "no"
    r = yield(self.con:config_set("appendonly", new_appendonly))
    assert(r)
    r = turboredis.util.from_kvlist(
        yield(self.con:config_get("appendonly")))["appendonly"]
    assertEquals(r, new_appendonly)
    r = yield(self.con:config_set("appendonly", old_appendonly))
    assert(r)
end

if options.include_unsupported then
    function TestTurboRedis:test_config_resetstat()
        assert(false, "'CONFIG RESETSTAT' has no test yet.")
    end
end

function TestTurboRedis:test_dbsize()
    local r
    r = yield(self.con:dbsize())
    assertEquals(r, 0)
    r = yield(self.con:set("abcdefg", "hijklmnop"))
    assert(r)
    r = yield(self.con:dbsize())
    assertEquals(r, 1)
end

if options.include_unsupported then
    function TestTurboRedis:test_debug_object()
        assert(false, "'DEBUG OBJECT' has no test yet.")
    end
end

if options.include_unsupported then
    function TestTurboRedis:test_debug_segfault()
        assert(false, "'DEBUG SEGAFAULT' has no test yet.")
    end
end

function TestTurboRedis:test_decr()
    local r
    r = yield(self.con:set("foo", 1))
    assert(r)
    r = yield(self.con:decr("foo"))
    assertEquals(r, 0)
    r = yield(self.con:get("foo"))
    assertEquals(r, "0")
end

function TestTurboRedis:test_decrby()
    local r
    r = yield(self.con:set("foo", 10))
    assert(r)
    r = yield(self.con:decrby("foo", 5))
    assertEquals(r, 5)
    r = yield(self.con:get("foo"))
    assertEquals(r, "5")
end

function TestTurboRedis:test_del()
    local r
    r = yield(self.con:set("foo", 1))
    assert(r)
    r = yield(self.con:get("foo"))
    assertEquals(r, "1")
    r = yield(self.con:del("foo"))
    assert(r)
    r = yield(self.con:get("foo"))
    assert(not r)
end


function TestTurboRedis:test_discard()
    local r
    r = yield(self.con:multi())
    assert(r)
    r = yield(self.con:set("foo", "bar"))
    assert(r)
    r = yield(self.con:discard())
    assert(r)
    r = yield(self.con:get("foo"))
    assert(not r)
end

function TestTurboRedis:test_dump()
    local r
    r = yield(self.con:set("foo", "bar"))
    assert(r)
    r = yield(self.con:dump("foo"))
    assertEquals(r, "\x00\x03bar\x06\x00pS!\xe0\x1b3\xc1\x84")
end

function TestTurboRedis:test_echo()
    local r
    r = yield(self.con:echo("Foo"))
    assertEquals(r, "Foo")
    r = yield(self.con:echo("Bar"))
    assertEquals(r, "Bar")
end

function TestTurboRedis:test_eval()
    local r
    r = yield(self.con:eval("return redis.call('set','foo','bar')", 0))
    assert(r)
    r = yield(self.con:get("foo"))
    assertEquals(r, "bar")
end

function TestTurboRedis:test_evalsha()
    local r
    local ssha
    ssha = yield(self.con:script_load("return redis.call('set','foo','bar')"))
    assert(ssha == "2fa2b029f72572e803ff55a09b1282699aecae6a")
    -- TODO: Should argument count be implied?
    r = yield(self.con:evalsha(ssha, 0))
    assert(r)
    r = yield(self.con:get("foo"))
    assertEquals(r, "bar")
end

function TestTurboRedis:test_exec()
    local r
    r = yield(self.con:multi())
    assert(r)
    r = yield(self.con:set("foo", "bar"))
    assert(r)
    r = yield(self.con:set("bar", "foo"))
    assert(r)
    r = yield(self.con:set("fortytwo", 42))
    assert(r)
    r = yield(self.con:decr("fortytwo"))
    assert(r)
    r = yield(self.con:exec())
    assert(r[1][1] == true)
    assert(r[2][1] == true)
    assert(r[3][1] == true)
    assert(r[4] == 41)
end

function TestTurboRedis:test_exists()
    local r
    r = yield(self.con:set("foo", "bar"))
    assertEquals(r, true)
    r = yield(self.con:set("bar", "foo"))
    assertEquals(r, true)
    r = yield(self.con:get("foo"))
    assertEquals(r, "bar")
    r = yield(self.con:exists("foo"))
    assertEquals(r, 1)
    r = yield(self.con:exists("abc"))
    assertEquals(r, 0)
end

if not options.fast then
    function TestTurboRedis:test_expire()
        local r
        r = yield(self.con:set("foo", "bar"))
        assert(r)
        r = yield(self.con:get("foo"))
        assertEquals(r, "bar")
        r = yield(self.con:expire("foo", 3))
        ffi.C.sleep(5)
        r = yield(self.con:get("foo"))
        assert(not r)
    end
end

if not options.fast then
    function TestTurboRedis:test_expireat()
        local r
        local ts
        r = yield(self.con:set("foo", "bar"))
        assert(r)
        r = yield(self.con:get("foo"))
        assertEquals(r, "bar")
        r = yield(self.con:expireat("foo", os.time()+5))
        ffi.C.sleep(2)
        r = yield(self.con:get("foo"))
        assertEquals(r, "bar")
        ffi.C.sleep(3)
        r = yield(self.con:get("foo"))
        assert(not r)
    end
end

function TestTurboRedis:test_flushall()
    local r
    r = yield(self.con:select(0))
    assert(r)
    r = yield(self.con:set("foo", "bar"))
    assert(r)
    r = yield(self.con:select(1))
    assert(r)
    r = yield(self.con:set("bar", "foo"))
    assert(r)
    r = yield(self.con:flushall())
    assert(r)
    r = yield(self.con:select(0))
    assert(r)
    r = yield(self.con:get("foo"))
    assert(not r)
    r = yield(self.con:select(1))
    assert(r)
    r = yield(self.con:get("bar"))
    assert(not r)
end

function TestTurboRedis:test_flushdb()
    local r
    r = yield(self.con:flushdb())
    assert(r)
    r = yield(self.con:set("test1", "123"))
    assert(r)
    r = yield(self.con:set("test2", "123"))
    assert(r)
    r = yield(self.con:dbsize())
    assertEquals(r, 2)
    r = yield(self.con:flushdb())
    assert(r)
    r = yield(self.con:dbsize())
    assertEquals(r, 0)
end

function TestTurboRedis:test_get()
    -- FIXME: Arrogance
end

function TestTurboRedis:test_getbit()
    local r
    r = yield(self.con:setbit("foo", 7, 1))
    assert(r)
    r = yield(self.con:getbit("foo", 7))
    assertEquals(r, 1)
    r = yield(self.con:setbit("foo", 7, 0))
    assert(r)
    r = yield(self.con:getbit("foo", 7))
    assertEquals(r, 0)
end

function TestTurboRedis:test_getrange()
    local r
    r = yield(self.con:set("foo", "foobar"))
    assert(r)
    r = yield(self.con:getrange("foo", 0, 2))
    assertEquals(r, "foo")
    r = yield(self.con:getrange("foo", 3, 5))
    assertEquals(r, "bar")
    r = yield(self.con:getrange("foo", 3, 1000))
    assertEquals(r, "bar")
    r = yield(self.con:getrange("foo", -3, -1))
    assertEquals(r, "bar")
end

function TestTurboRedis:test_getset()
    local r
    r = yield(self.con:set("foo", "bar"))
    assert(r)
    r = yield(self.con:getset("foo", "foo"))
    assertEquals(r, "bar")
    r = yield(self.con:get("foo"))
    assertEquals(r, "foo")
end

function TestTurboRedis:test_hdel()
    local r
    r = yield(self.con:hset("foohash", "foo", "bar"))
    assert(r)
    r = yield(self.con:hset("foohash", "bar", "foo"))
    assert(r)
    r = yield(self.con:hdel("foohash", "foo"))
    assertEquals(r, 1)
    r = yield(self.con:hdel("foohash", "bar"))
    assertEquals(r, 1)
end

function TestTurboRedis:test_hexists()
    local r
    r = yield(self.con:hset("foohash", "foo", "bar"))
    assertEquals(r, 1)
    r = yield(self.con:hexists("foohash", "foo"))
    assertEquals(r, 1)
    r = yield(self.con:hdel("foohash", "foo"))
    assertEquals(r, 1)
    r = yield(self.con:hexists("foohash", "foo"))
    assertEquals(r, 0)
end

function TestTurboRedis:test_hget()
    local r
    r = yield(self.con:hset("foohash", "foo", "bar"))
    assert(r)
    r = yield(self.con:hget("foohash", "foo"))
    assertEquals(r, "bar")
end

function TestTurboRedis:test_hgetall()
    local r
    r = yield(self.con:hset("foohash", "foo", "bar"))
    assertEquals(r, 1)
    r = yield(self.con:hset("foohash", "bar", "foo"))
    assertEquals(r, 1)
    r = yield(self.con:hgetall("foohash"))
    assertItemsEquals(r, {"foo", "bar", "bar", "foo"})
    r = turboredis.util.from_kvlist(r)
    for i, v in ipairs(r) do
        if v == "foo" then
            assertEquals(r[i+1], "bar")
        elseif v == "bar" then
            assertEquals(r[i+1], "foo")
        end
    end
end

function TestTurboRedis:test_hincrby()
    local r
    r = yield(self.con:hset("foohash", "foo", 10))
    assert(r)
    r = yield(self.con:hincrby("foohash", "foo", 2))
    assertEquals(r, 12)
    r = yield(self.con:hget("foohash", "foo"))
    assertEquals(r, "12")
end

function TestTurboRedis:test_hincrybyfloat()
    local r
    r = yield(self.con:hset("foohash", "foo", "13.4"))
    assert(r)
    r = yield(self.con:hincrbyfloat("foohash", "foo", 0.3))
    assertEquals(r, "13.7")
    r = yield(self.con:hget("foohash", "foo"))
    assertEquals(r, "13.7")
end

function TestTurboRedis:test_hkeys()
    local r
    r = yield(self.con:hset("foohash", "foo", "bar"))
    assert(r)
    r = yield(self.con:hset("foohash", "bar", "foo"))
    assert(r)
    r = yield(self.con:hkeys("foohash"))
    assertEquals({"foo", "bar"}, r)
end

function TestTurboRedis:test_hlen()
    local r
    r = yield(self.con:hset("foohash", "foo", "bar"))
    assert(r)
    r = yield(self.con:hlen("foohash"))
    assertEquals(r, 1)
    r = yield(self.con:hset("foohash", "bar", "foo"))
    assert(r)
    r = yield(self.con:hlen("foohash"))
    assertEquals(r, 2)
end

function TestTurboRedis:test_hmget()
    local r
    r = yield(self.con:hset("foohash", "foo", "123"))
    assert(r)
    r = yield(self.con:hset("foohash", "bar", "456"))
    assert(r)
    r = yield(self.con:hmget("foohash", "foo", "bar"))
    assertEquals(r, {"123", "456"})
    r = yield(self.con:hmget("foohash", "bar", "foo"))
    assertEquals(r, {"456", "123"})
end

function TestTurboRedis:test_hmset()
    local r
    r = yield(self.con:hmset("foohash", "foo", "abc", "bar", "123"))
    assert(r)
    r = yield(self.con:hget("foohash", "foo"))
    assertEquals(r, "abc")
    r = yield(self.con:hget("foohash", "bar"))
    assertEquals(r, "123")
end

function TestTurboRedis:test_hset()
    local r
    r = yield(self.con:hset("foohash", "foo", "bar"))
    assert(r)
    r = yield(self.con:hget("foohash", "foo"))
    assertEquals(r, "bar")
end

function TestTurboRedis:test_hsetnx()
    local r
    r = yield(self.con:hset("foohash", "foo", "bar"))
    assert(r)
    r = yield(self.con:hget("foohash", "foo"))
    assertEquals(r, "bar")
    r = yield(self.con:hsetnx("foohash", "foo", "test"))
    assertEquals(r, 0)
    r = yield(self.con:hget("foohash", "foo"))
    assertEquals(r, "bar")
end

function TestTurboRedis:test_hvals()
    local r
    r = yield(self.con:hset("foohash", "foo", "abc"))
    assert(r)
    r = yield(self.con:hset("foohash", "bar", "123"))
    assert(r)
    r = yield(self.con:hvals("foohash"))
    assertEquals(r, {"abc", "123"})
end

function TestTurboRedis:test_incr()
    local r
    r = yield(self.con:set("foo", "41"))
    assert(r)
    r = yield(self.con:incr("foo"))
    assertEquals(r, 42)
    r = yield(self.con:get("foo"))
    assertEquals(r, "42")
end

function TestTurboRedis:test_incrby()
    local r
    r = yield(self.con:set("foo", 40))
    assertEquals(r, true)
    r = yield(self.con:incrby("foo", 2))
    assertEquals(r,  42)
    r = yield(self.con:get("foo"))
    assertEquals(r,  "42")
end

function TestTurboRedis:test_incrbyfloat()
    local r
    r = yield(self.con:set("foo", 40.3))
    assertEquals(r, true)
    r = yield(self.con:incrbyfloat("foo", 1.7))
    assertEquals(r, "42")
    r = yield(self.con:get("foo"))
    assertEquals(r, "42")
end

function TestTurboRedis:test_info()
    local r
    r = yield(self.con:info())
    assert(type(r) == "string")
end

function TestTurboRedis:test_keys()
    local r
    r = yield(self.con:set("foo", "bar"))
    assert(r)
    r = yield(self.con:set("bar", "foo"))
    assert(r)
    r = yield(self.con:set("hello", "world"))
    assert(r)
    r = yield(self.con:keys("*o"))
    assertItemsEquals(r, {"hello", "foo"})
    assertItemsEquals(r, {"hello", "foo"})
end

if not options.fast and options.unstable then
    -- This occasionally fails due to a currently
    -- running background save operation
    function TestTurboRedis:test_lastsave()
        local r
        local time
        time = yield(self.con:lastsave())
        assert(time)
        r = yield(self.con:bgsave())
        assert(r)
        ffi.C.sleep(10) -- We assume that this is enough
        r = yield(self.con:lastsave())
        assert(time ~= r)
    end
end

function TestTurboRedis:test_lindex()
    local r
    r = yield(self.con:rpush("foolist", "foo"))
    assertEquals(r,  1)
    r = yield(self.con:rpush("foolist", "bar"))
    assertEquals(r,  2)
    r = yield(self.con:lindex("foolist", 0))
    assertEquals(r, "foo")
    r = yield(self.con:lindex("foolist", 1))
    assertEquals(r, "bar")
    r = yield(self.con:lindex("foolist", -1))
    assertEquals(r, "bar")
end

function TestTurboRedis:test_linsert()
    local r
    r = yield(self.con:rpush("foolist", "foo"))
    assertEquals(r,  1)
    r = yield(self.con:rpush("foolist", "bar"))
    assertEquals(r,  2)
    r = yield(self.con:linsert("foolist", "BEFORE", "bar", "Hello"))
    assertEquals(r,  3)
    r = yield(self.con:linsert("foolist", "AFTER", "Hello", "World"))
    assertEquals(r,  4)
    r = yield(self.con:lrange("foolist", 0, -1))
    assertEquals(r, {"foo", "Hello", "World", "bar"})
end

function TestTurboRedis:test_llen()
    local r
    r = yield(self.con:rpush("foolist", "foo"))
    assertEquals(r, 1)
    r = yield(self.con:rpush("foolist", "bar"))
    assertEquals(r, 2)
    r = yield(self.con:llen("foolist"))
    assertEquals(r, 2)
end

function TestTurboRedis:test_lpop()
    local r
    r = yield(self.con:rpush("foolist", "foo"))
    assertEquals(r, 1)
    r = yield(self.con:rpush("foolist", "bar"))
    assertEquals(r, 2)
    r = yield(self.con:lpop("foolist"))
    assertEquals(r, "foo")
    r = yield(self.con:lpop("foolist"))
    assertEquals(r, "bar")
end

function TestTurboRedis:test_lpush()
    local r
    r = yield(self.con:lpush("foolist", "foo"))
    assertEquals(r, 1)
    r = yield(self.con:lpush("foolist", "bar"))
    assertEquals(r, 2)
    r = yield(self.con:lrange("foolist", 0, -1))
    assertEquals(r, {"bar", "foo"})
end

function TestTurboRedis:test_lpushx()
    local r
    r = yield(self.con:lpush("foolist", "foo"))
    assertEquals(r, 1)
    r = yield(self.con:lpushx("foolist", "bar"))
    assertEquals(r, 2)
    r = yield(self.con:lpushx("barlist", "foo"))
    assertEquals(r, 0)
end

function TestTurboRedis:test_lrange()
    local r
    r = yield(self.con:rpush("foolist", "foo"))
    assertEquals(r, 1)
    r = yield(self.con:rpush("foolist", "bar"))
    assertEquals(r, 2)
    r = yield(self.con:rpush("foolist", "hello"))
    assertEquals(r, 3)
    r = yield(self.con:rpush("foolist", "world"))
    assertEquals(r, 4)
    r = yield(self.con:lrange("foolist", 0, 0))
    assertEquals(r, {"foo"})
    r = yield(self.con:lrange("foolist", 0, 1))
    assertEquals(r, {"foo", "bar"})
    r = yield(self.con:lrange("foolist", 1, 2))
    assertEquals(r, {"bar", "hello"})
    r = yield(self.con:lrange("foolist", 0, -1))
    assertEquals(r, {"foo", "bar", "hello", "world"})
    r = yield(self.con:lrange("foolist", 0, -2))
    assertEquals(r, {"foo", "bar", "hello"})
end

function TestTurboRedis:test_lrem()
    local r
    r = yield(self.con:rpush("foolist", "foo"))
    assertEquals(r, 1)
    r = yield(self.con:rpush("foolist", "bar"))
    assertEquals(r, 2)
    r = yield(self.con:llen("foolist"))
    assertEquals(r, 2)
    r = yield(self.con:lrem("foolist", 0, "foo"))
    assertEquals(r, 1)
    r = yield(self.con:llen("foolist"))
    assertEquals(r, 1)
    -- FIXME: More tests if needed
end

function TestTurboRedis:test_mget()
    local r
    r = yield(self.con:set("foo", "bar"))
    assert(r)
    r = yield(self.con:set("bar", "foo"))
    assert(r)
    r = yield(self.con:mget("foo", "bar"))
    assert(r[1] == "bar")
    assert(r[2] == "foo")
end

if options.include_unsupported then
    function TestTurboRedis:test_monitor()
        assert(false, "'MONITOR' not currently supported and has no test.")
    end
end

function TestTurboRedis:test_move()
    local r
    r = yield(self.con:select(0))
    assert(r)
    r = yield(self.con:set("foo", "bar"))
    assert(r)
    r = yield(self.con:move("foo", 1))
    assert(r)
    r = yield(self.con:select(1))
    assert(r)
    r = yield(self.con:get("foo"))
    assertEquals(r, "bar")
end

function TestTurboRedis:test_mset()
    local r
    r = yield(self.con:mset("foo", "bar", "hello", "world"))
    assert(r)
    r = yield(self.con:get("foo"))
    assertEquals(r, "bar")
    r = yield(self.con:get("hello"))
    assertEquals(r, "world")
end

function TestTurboRedis:test_msetnx()
    local r
    r = yield(self.con:mset("foo", "bar", "hello", "world"))
    assertEquals(r, true)
    r = yield(self.con:msetnx("foo", "bar", "Hello", "world"))
    assertEquals(r, 0)
end

function TestTurboRedis:test_multi()
    local r
    r = yield(self.con:multi())
    assert(r)
    r = yield(self.con:set("foo", "bar"))
    assert(r)
    r = yield(self.con:set("foo", "Hello World!"))
    assert(r)
    r = yield(self.con:exec())
    assert(r)
    r = yield(self.con:get("foo"))
    assertEquals(r, "Hello World!")
end

if options.include_unsupported then
    function TestTurboRedis:test_object()
        assert(false, "'OBJECT' has no test.")
    end
end

if not options.fast then
    function TestTurboRedis:test_persist()
        local r
        r = yield(self.con:set("foo", "bar"))
        assert(r)
        r = yield(self.con:expire("foo", 5))
        assert(r)
        r = yield(self.con:persist("foo"))
        ffi.C.sleep(6)
        r = yield(self.con:get("foo"))
        assertEquals(r, "bar")
    end
end

if not options.fast then
    function TestTurboRedis:test_pexpire()
        local r
        r = yield(self.con:set("foo", "bar"))
        assert(r)
        r = yield(self.con:pexpire("foo", 2000))
        assert(r)
        ffi.C.sleep(3)
        r = yield(self.con:get("foo"))
        assert(not r)
    end
end

if not options.fast then
    function TestTurboRedis:test_pexpireat()
        local r
        r = yield(self.con:set("foo", "bar"))
        assert(r)
        r = yield(self.con:pexpireat("foo", (os.time()*1000) + 2000))
        assert(r)
        ffi.C.sleep(1)
        r = yield(self.con:get("foo"))
        assertEquals(r, "bar")
        ffi.C.sleep(2)
        r = yield(self.con:get("foo"))
        assertEquals(r, nil)
    end
end

if options.unstable then
    function TestTurboRedis:test_pfadd()
        local r
        r = yield(self.con:pfadd("foohll", "foo"))
        assertEquals(r, 1)
        r = yield(self.con:pfadd("foohll", "bar"))
        assertEquals(r, 1)
        r = yield(self.con:pfadd("foohll", "foo"))
        assertEquals(r, 0)
        r = yield(self.con:pfadd("foohll", "foo", "bar", "foobar"))
        assertEquals(r, 1)
        r = yield(self.con:pfcount("foohll"))
        assertEquals(r, 3)
    end

    function TestTurboRedis:test_pfcount()
        local r
        r = yield(self.con:pfadd("foohll", "foo"))
        assertEquals(r, 1)
        r = yield(self.con:pfcount("foohll"))
        assertEquals(r, 1)
        r = yield(self.con:pfadd("foohll", "bar"))
        assertEquals(r, 1)
        r = yield(self.con:pfcount("foohll"))
        assertEquals(r, 2)
        r = yield(self.con:pfadd("foohll", "foo"))
        assertEquals(r, 0)
        r = yield(self.con:pfcount("foohll"))
        assertEquals(r, 2)
    end

    function TestTurboRedis:test_pfmerge()
        local r
        r = yield(self.con:pfadd("foohll", "foo", "bar"))
        assertEquals(r, 1)
        r = yield(self.con:pfadd("barhll", "foo", "bar", "foobar"))
        assertEquals(r, 1)
        r = yield(self.con:pfmerge("foobarhll", "foohll", "barhll"))
        assertEquals(r, true)
        r = yield(self.con:pfcount("foobarhll"))
        assertEquals(r, 3)
    end
end

function TestTurboRedis:test_ping()
    local r
    r = yield(self.con:ping())
    assert(r)
end

if not options.fast then
    function TestTurboRedis:test_psetex()
        local r
        r = yield(self.con:psetex("foo", 2000, "bar"))
        assert(r)
        r = yield(self.con:get("foo"))
        assertEquals(r, "bar")
        ffi.C.sleep(3)
        r = yield(self.con:get("foo"))
        assertEquals(r, nil)
    end
end

if not options.fast then
    function TestTurboRedis:test_pttl()
        local r
        r = yield(self.con:set("foo", "bar"))
        assert(r)
        r = yield(self.con:pexpire("foo", 2000))
        assert(r)
        ffi.C.sleep(1)
        r = yield(self.con:pttl("foo"))
        assert(r < 1001 and r > 0)
        r = yield(self.con:get("foo"))
        assert(r)
    end
end

if options.unstable then
    function TestTurboRedis:test_quit()
        local r
        local con
        local ioloop = turbo.ioloop.instance()
        con = turboredis.Connection:new(options.host, options.port)
        r = yield(con:connect())
        assert(r)
        r = yield(self.con:quit())
        assert(r)
        assert(self.con.stream:closed())
    end
end

function TestTurboRedis:test_randomkey()
    local r
    r = yield(self.con:randomkey())
    assertEquals(r, nil)
    r = yield(self.con:set("foo", "BAAAR"))
    assert(r)
    r = yield(self.con:randomkey())
    assertEquals(r, "foo")
    r = yield(self.con:set("bar", "FOOOO"))
    assert(r)
    r = yield(self.con:randomkey())
    assert(r == "foo" or r == "bar")
end

function TestTurboRedis:test_rename()
    local r
    r = yield(self.con:set("foo", "BAR"))
    assert(r)
    r = yield(self.con:rename("foo", "bar"))
    assert(r)
    r = yield(self.con:get("foo"))
    assertEquals(r, nil)
    r = yield(self.con:get("bar"))
    assertEquals(r, "BAR")
end

function TestTurboRedis:test_renamenx()
    local r
    r = yield(self.con:set("foo", "BAR"))
    assertEquals(r, true)
    r = yield(self.con:set("bar", "FOO"))
    assertEquals(r, true)
    r = yield(self.con:renamenx("foo", "bar"))
    assertEquals(r, 0)
    r = yield(self.con:renamenx("foo", "foobar"))
    assertEquals(r, 1)
    r = yield(self.con:get("foo"))
    assertEquals(r, nil)
    r = yield(self.con:get("foobar"))
    assertEquals(r, "BAR")
end

function TestTurboRedis:test_restore()
    local r
    local dumped
    r = yield(self.con:set("foo", "bar"))
    assert(r)
    r = yield(self.con:dump("foo"))
    assertEquals(r, "\x00\x03bar\x06\x00pS!\xe0\x1b3\xc1\x84")
    dumped = r
    r = yield(self.con:del("foo"))
    assert(r)
    r = yield(self.con:get("foo"))
    assertEquals(r, nil)
    r = yield(self.con:restore("foo", 0, dumped))
    assert(r)
    r = yield(self.con:get("foo"))
    assertEquals(r, "bar")
end

function TestTurboRedis:test_rpop()
    local r
    r = yield(self.con:rpush("foolist", "foo"))
    assertEquals(r, 1)
    r = yield(self.con:rpush("foolist", "bar"))
    assertEquals(r, 2)
    r = yield(self.con:rpop("foolist"))
    assertEquals(r, "bar")
    r = yield(self.con:rpop("foolist"))
    assertEquals(r, "foo")
end

function TestTurboRedis:test_rpoplpush()
    local r
    r = yield(self.con:rpush("foolist", "foo"))
    assertEquals(r, 1)
    r = yield(self.con:rpush("foolist", "bar"))
    assertEquals(r, 2)
    r = yield(self.con:rpoplpush("foolist", "barlist"))
    assertEquals(r, "bar")
    r = yield(self.con:rpop("foolist"))
    assertEquals(r, "foo")
    r = yield(self.con:rpop("barlist"))
    assertEquals(r, "bar")
end

function TestTurboRedis:test_rpush()
    local r
    r = yield(self.con:rpush("foolist", "foo"))
    assertEquals(r, 1)
    r = yield(self.con:rpush("foolist", "bar"))
    assertEquals(r, 2)
    r = yield(self.con:rpop("foolist"))
    assertEquals(r, "bar")
    r = yield(self.con:rpop("foolist"))
    assertEquals(r, "foo")
end

function TestTurboRedis:test_rpushx()
    local r
    r = yield(self.con:rpushx("foolist", "foo"))
    assertEquals(r, 0)
    r = yield(self.con:rpush("foolist", "foo"))
    assertEquals(r, 1)
    r = yield(self.con:rpushx("foolist", "bar"))
    assertEquals(r, 2)
end

function TestTurboRedis:test_sadd()
    local r
    r = yield(self.con:sadd("fooset", "foo"))
    assertEquals(r, 1)
    r = yield(self.con:sadd("fooset", "bar", "foobar"))
    assertEquals(r, 2)
    r = yield(self.con:smembers("fooset"))
    assertTableHas(r, "foo") 
    assertTableHas(r, "bar")
    assertTableHas(r, "foobar")
end

function TestTurboRedis:test_save()
    local r
    r = yield(self.con:save())
    assert(r)
end

function TestTurboRedis:test_scard()
    local r
    r = yield(self.con:sadd("fooset", "foo"))
    assertEquals(r, 1)
    r = yield(self.con:sadd("fooset", "bar", "foobar"))
    assertEquals(r, 2)
    r = yield(self.con:scard("fooset"))
    assertEquals(r, 3)
end

function TestTurboRedis:test_script_exists()
    local r
    local return1hash = "e0e1f9fabfc9d4800c877a703b823ac0578ff8db"
    local bullshithash = "d6791ddba07df4735f83e91c43814e891038559c"
    r = yield(self.con:script_load("return 1"))
    assertEquals(r, return1hash)
    r = yield(self.con:script_exists(return1hash))
    assertEquals(#r, 1)
    assertEquals(r[1], 1)
    r = yield(self.con:script_exists(bullshithash))
    assertEquals(#r, 1)
    assertEquals(r[1], 0)
end

function TestTurboRedis:test_script_flush()
    local r
    local return1hash = "e0e1f9fabfc9d4800c877a703b823ac0578ff8db"
    r = yield(self.con:script_load("return 1"))
    assertEquals(r, return1hash)
    r = yield(self.con:script_exists(return1hash))
    assertEquals(#r, 1)
    assertEquals(r[1], 1)
    r = yield(self.con:script_flush())
    assert(r)
    r = yield(self.con:script_exists(return1hash))
    assertEquals(#r, 1)
    assertEquals(r[1], 0)
end

if options.include_unsupported then
    function TestTurboRedis:test_script_kill()
        assert(false, "'SCRIPT KILL' has no test yet.")
    end
end

function TestTurboRedis:test_script_load()
    local r
    local return1hash = "e0e1f9fabfc9d4800c877a703b823ac0578ff8db"
    r = yield(self.con:script_load("return 1"))
    assertEquals(r, return1hash)
    r = yield(self.con:script_exists(return1hash))
    assertEquals(#r, 1)
    assertEquals(r[1], 1)
end

function TestTurboRedis:test_sdiff()
    local r
    r = yield(self.con:sadd("fooset", "foo"))
    assertEquals(r, 1)
    r = yield(self.con:sadd("barset", "foo"))
    assertEquals(r, 1)
    r = yield(self.con:sadd("barset", "bar"))
    assertEquals(r, 1)
    r = yield(self.con:sadd("barset", "foobar"))
    assertEquals(r, 1)
    r = yield(self.con:sdiff("barset", "fooset"))
    assertEquals(#r, 2)
    assertTableHas(r, "bar")
    assertTableHas(r, "foobar")
    r = yield(self.con:sdiff("fooset", "barset"))
    assertEquals(#r, 0)
    assertEquals(type(r), "table")
end

function TestTurboRedis:test_sdiffstore()
    local r
    r = yield(self.con:sadd("fooset", "foo"))
    assertEquals(r, 1)
    r = yield(self.con:sadd("barset", "foo"))
    assertEquals(r, 1)
    r = yield(self.con:sadd("barset", "bar"))
    assertEquals(r, 1)
    r = yield(self.con:sadd("barset", "foobar"))
    assertEquals(r, 1)
    r = yield(self.con:sdiffstore("foobarset", "barset", "fooset"))
    assertEquals(r, 2)
    r = yield(self.con:smembers("foobarset"))
    assertTableHas(r, "bar")
    assertTableHas(r, "foobar")
end

function TestTurboRedis:test_select()
    local r
    r = yield(self.con:select(1))
    assert(r)
    r = yield(self.con:get("test"))
    assert(not r)
end

function TestTurboRedis:test_set()
    local r
    r = yield(self.con:set("foo", "bar"))
    assert(r)
    r = yield(self.con:get("foo"))
    assertEquals(r, "bar")
    -- TODO: Test the 'new' SET
end

function TestTurboRedis:test_setbit()
    local r
    r = yield(self.con:setbit("foo", 7, 1))
    assert(r)
    r = yield(self.con:getbit("foo", 7))
    assertEquals(r, 1)
    r = yield(self.con:setbit("foo", 7, 0))
    assert(r)
    r = yield(self.con:getbit("foo", 7))
    assertEquals(r, 0)
end

if not options.fast then
    function TestTurboRedis:test_setex()
        local r
        r = yield(self.con:setex("foo", 2, "bar"))
        assert(r)
        r = yield(self.con:get("foo"))
        assertEquals(r, "bar")
        ffi.C.sleep(3)
        r = yield(self.con:get("foo"))
        assertEquals(r, nil)
    end
end

function TestTurboRedis:test_setnx()
    local r
    r = yield(self.con:set("foo", "bar"))
    assertEquals(r, true)
    r = yield(self.con:setnx("foo", "foobar"))
    assertEquals(r, 0)
    r = yield(self.con:get("foo"))
    assertEquals(r, "bar")
    r = yield(self.con:setnx("bar", "foobar"))
    assertEquals(r, 1)
    r = yield(self.con:get("bar"))
    assertEquals(r, "foobar")
end

function TestTurboRedis:test_setrange()
    local r
    r = yield(self.con:set("foo", "foobar"))
    assert(r)
    r = yield(self.con:setrange("foo", 3, "foo"))
    assertEquals(r, 6)
    r = yield(self.con:get("foo"))
    assertEquals(r, "foofoo")
end

if options.include_unsupported then
    function TestTurboRedis:test_shutdown()
        assert(false, "'SHUTDOWN' has no test yet.")
    end
end

function TestTurboRedis:test_sinter()
    local r
    r = yield(self.con:sadd("fooset", "aa"))
    assertItemsEquals(r, 1)
    r = yield(self.con:sadd("fooset", "bb"))
    assertItemsEquals(r, 1)
    r = yield(self.con:sadd("fooset", "cc"))
    assertItemsEquals(r, 1)
    r = yield(self.con:sadd("barset", "cc"))
    assertItemsEquals(r, 1)
    r = yield(self.con:sadd("barset", "dd"))
    assertItemsEquals(r, 1)
    r = yield(self.con:sinter("fooset", "barset"))
    assertEquals(#r, 1)
    assertEquals(r[1], "cc")
end

function TestTurboRedis:test_sinterstore()
    local r
    r = yield(self.con:sadd("fooset", "aa"))
    assertItemsEquals(r, 1)
    r = yield(self.con:sadd("fooset", "bb"))
    assertItemsEquals(r, 1)
    r = yield(self.con:sadd("fooset", "cc"))
    assertItemsEquals(r, 1)
    r = yield(self.con:sadd("barset", "cc"))
    assertItemsEquals(r, 1)
    r = yield(self.con:sadd("barset", "dd"))
    assertItemsEquals(r, 1)
    r = yield(self.con:sinterstore("foobarset", "fooset", "barset"))
    assertEquals(r, 1)
    r = yield(self.con:smembers("foobarset"))
    assertEquals(#r, 1)
    assertEquals(r[1], "cc")
end

function TestTurboRedis:test_sismember()
    local r
    r = yield(self.con:sadd("fooset", "foo"))
    assertEquals(r, 1)
    r = yield(self.con:sadd("fooset", "bar"))
    assertEquals(r, 1)
    r = yield(self.con:sismember("fooset", "foo"))
    assertEquals(r, 1)
    r = yield(self.con:sismember("fooset", "foobar"))
    assertEquals(r, 0)
end

if options.include_unsupported then
    function TestTurboRedis:test_slaveof()
        assert(false, "'SLAVEOF' has no test yet.")
    end
end

if options.include_unsupported then
    function TestTurboRedis:test_slowlog_get()
        assert(false, "'SLOWLOG GET' has no test yet.")
    end
end

function TestTurboRedis:test_slowlog_len()
    local r
    r = yield(self.con:slowlog_reset())
    assert(r)
    r = yield(self.con:slowlog_len())
    assertEquals(r, 0)
end

function TestTurboRedis:test_slowlog_reset()
    local r
    r = yield(self.con:slowlog_reset())
    assert(r)
end

function TestTurboRedis:test_smembers()
    local r
    r = yield(self.con:sadd("fooset", "foo", "bar"))
    assertEquals(r, 2)
    r = yield(self.con:smembers("fooset"))
    assertEquals(#r, 2)
    assertTableHas(r, "foo")
    assertTableHas(r, "bar")
    r = yield(self.con:sadd("fooset", "foobar"))
    assertEquals(r, 1)
    r = yield(self.con:smembers("fooset"))
    assertEquals(#r, 3)
    assertTableHas(r, "foo")
    assertTableHas(r, "bar")
    assertTableHas(r, "foobar")
end

function TestTurboRedis:test_smove()
    local r
    r = yield(self.con:sadd("fooset", "foo", "bar"))
    assertEquals(r, 2)
    r = yield(self.con:smembers("fooset"))
    assertEquals(#r, 2)
    assertTableHas(r, "foo")
    assertTableHas(r, "bar")
    r = yield(self.con:smove("fooset", "barset", "foo"))
    assert(r)
    r = yield(self.con:smembers("barset"))
    assertEquals(#r, 1)
    assertTableHas(r, "foo")
    r = yield(self.con:smove("fooset", "foobarbar"))
    assert(not r)
end

function TestTurboRedis:test_sort()
    local r
    r = yield(self.con:rpush("foolist", 4, 2, 16))
    assertEquals(r, 3)
    r = yield(self.con:sort("foolist"))
    assertEquals(#r, 3)
    assertEquals(r[1], "2")
    assertEquals(r[2], "4")
    assertEquals(r[3], "16")
    r = yield(self.con:sort("foolist", "asc"))
    assertEquals(r[3], "16")
    r = yield(self.con:sort("foolist", "desc"))
    assertEquals(#r, 3)
    assertEquals(r[1], "16")
    assertEquals(r[2], "4")
    assertEquals(r[3], "2")
    r = yield(self.con:sort("foolist", "asc", "limit", 0, 2))
    assertEquals(#r, 2)
    assertEquals(r[1], "2")
    assertEquals(r[2], "4")
    r = yield(self.con:sort("foolist", "desc", "limit", 0, 2))
    assertEquals(#r, 2)
    assertEquals(r[1], "16")
    assertEquals(r[2], "4")
    -- TODO: Test more of the sort syntax
end

function TestTurboRedis:test_spop()
    local r
    r = yield(self.con:sadd("fooset", "foo", "bar"))
    assertEquals(r, 2)
    r = yield(self.con:spop("fooset"))
    assert(r == "foo" or r == "bar")
    r = yield(self.con:smembers("fooset"))
    assertEquals(#r, 1)
    r = yield(self.con:spop("fooset"))
    assert(r == "foo" or r == "bar")
    r = yield(self.con:smembers("fooset"))
    assertEquals(#r, 0)
end

function TestTurboRedis:test_srandmember()
    local r
    r = yield(self.con:sadd("fooset", "foo", "bar"))
    assertEquals(r, 2)
    r = yield(self.con:srandmember("fooset"))
    assert(r == "foo" or r == "bar")
end

function TestTurboRedis:test_srem()
end

function TestTurboRedis:test_strlen()
    local r 
    r = yield(self.con:set("foo", "bar"))
    assert(r)
    r = yield(self.con:strlen("foo"))
    assertEquals(r, 3)
    r = yield(self.con:set("bar", "Hello World!"))
    assert(r)
    r = yield(self.con:strlen("bar"))
    assertEquals(r, 12)
end

function TestTurboRedis:test_sunion()
    local r
    r = yield(self.con:sadd("fooset", "one", "two", "three"))
    assertEquals(r, 3)
    r = yield(self.con:sadd("barset", "four", "five", "six"))
    assertEquals(r, 3)
    r = yield(self.con:sadd("foobarset", "one", "three", "five", "seven"))
    assertEquals(r, 4)
    r = yield(self.con:sunion("fooset", "barset", "foobarset"))
    assertTableHas(r, "one")
    assertTableHas(r, "two")
    assertTableHas(r, "three")
    assertTableHas(r, "four")
    assertTableHas(r, "five")
    assertTableHas(r, "six")
    assertTableHas(r, "seven")
    assertEquals(#r, 7)
end

function TestTurboRedis:test_sunionstore()
    local r
    r = yield(self.con:sadd("fooset", "one", "two", "three"))
    assertEquals(r, 3)
    r = yield(self.con:sadd("barset", "four", "five", "six"))
    assertEquals(r, 3)
    r = yield(self.con:sadd("foobarset", "one", "three", "five", "seven"))
    assertEquals(r, 4)
    r = yield(self.con:sunionstore("foounion", "fooset", "barset", "foobarset"))
    assertEquals(r, 7)
    r = yield(self.con:smembers("foounion"))
    assertTableHas(r, "one")
    assertTableHas(r, "two")
    assertTableHas(r, "three")
    assertTableHas(r, "four")
    assertTableHas(r, "five")
    assertTableHas(r, "six")
    assertTableHas(r, "seven")
    assertEquals(#r, 7)
end

if options.include_unsupported then
    function TestTurboRedis:test_sync()
        assert(false, "'SYNC' has no test since it is " ..
                      "documented as an internal command")
    end
end

function TestTurboRedis:test_time()
    local r
    local curtime = ffi.C.time(nil)
    r = yield(self.con:time())
    assert(tonumber(r[1]) >= curtime and tonumber(r[1]) <= curtime+1)
end

if not options.fast then
    function TestTurboRedis:test_ttl()
        local r
        r = yield(self.con:set("foo", "bar"))
        assert(r)
        r = yield(self.con:expire("foo", 5))
        assert(r)
        ffi.C.sleep(1)
        r = yield(self.con:ttl("foo"))
        assert(r <= 4 and r >= 2)
    end
end

function TestTurboRedis:test_type()
    local r
    local ktype
    r = yield(self.con:set("foo", "bar"))
    assert(r)
    r = yield(self.con:rpush("foolist", "bar"))
    assertEquals(r, 1)
    r, ktype = yield(self.con:type("foo"))
    assert(r)
    assertEquals(ktype, "string")
    r, ktype = yield(self.con:type("foolist"))
    assert(r)
    assertEquals(ktype, "list")
end

function TestTurboRedis:test_unwatch()
    local r
    -- Without UNWATCH
    r = yield(self.con:set("foo", "bar"))
    assert(r)
    r = yield(self.con:watch("foo"))
    assert(r)
    r = yield(self.con:multi())
    assert(r)
    r = yield(self.con:set("foo", "foobar"))
    assert(r)
    r = yield(self.con2:set("foo", "barfoo"))
    assert(r)
    r = yield(self.con:exec())
    assert(not r)
    r = yield(self.con:get("foo"))
    assertEquals(r, "barfoo")

    -- With UNWATCH
    r = yield(self.con:set("foo", "bar"))
    assert(r)
    r = yield(self.con:watch("foo"))
    assert(r)
    r = yield(self.con:unwatch())
    assert(r)
    r = yield(self.con:multi())
    assert(r)
    r = yield(self.con:set("foo", "foobar"))
    assert(r)
    r = yield(self.con2:set("foo", "barfoo"))
    assert(r)
    r = yield(self.con:exec())
    assert(r)
    r = yield(self.con:get("foo"))
    assertEquals(r, "foobar")
end

function TestTurboRedis:test_watch()
    local r
    r = yield(self.con:set("foo", "bar"))
    assert(r)
    r = yield(self.con:watch("foo"))
    assert(r)
    r = yield(self.con:multi())
    assert(r)
    r = yield(self.con:set("foo", "foobar"))
    assert(r)
    r = yield(self.con:exec())
    assert(r)
    r = yield(self.con:get("foo"))
    assertEquals(r, "foobar")

    r = yield(self.con:set("foo", "bar"))
    assert(r)
    r = yield(self.con:watch("foo"))
    assert(r)
    r = yield(self.con:multi())
    assert(r)
    r = yield(self.con:set("foo", "foobar"))
    assert(r)
    r = yield(self.con2:set("foo", "barfoo"))
    assert(r)
    r = yield(self.con:exec())
    assert(not r)
    r = yield(self.con:get("foo"))
    assertEquals(r, "barfoo")
end

function TestTurboRedis:test_zadd()
    local r
    r = yield(self.con:zadd("foozset", 1, "one"))
    assertEquals(r, 1)
    r = yield(self.con:zadd("foozset", 2, "two"))
    assertEquals(r, 1)
    r = yield(self.con:zrange("foozset", 0, -1, "withscores"))
    assertEquals(#r, 4)
    assertEquals(r[1], "one")
    assertEquals(r[2], "1")
    assertEquals(r[3], "two")
    assertEquals(r[4], "2")
end

function TestTurboRedis:test_zcard()
    local r
    r = yield(self.con:zadd("foozset", 1, "one"))
    assertEquals(r, 1)
    r = yield(self.con:zadd("foozset", 2, "two"))
    assertEquals(r, 1)
    r = yield(self.con:zcard("foozset"))
    assertEquals(r, 2)
    r = yield(self.con:zadd("foozset", 3, "three"))
    assertEquals(r, 1)
    r = yield(self.con:zcard("foozset"))
    assertEquals(r, 3)
end

function TestTurboRedis:test_zcount()
    local r
    r = yield(self.con:zadd("foozset", 1, "one"))
    assertEquals(r, 1)
    r = yield(self.con:zadd("foozset", 2, "two"))
    assertEquals(r, 1)
    r = yield(self.con:zadd("foozset", 3, "three"))
    assertEquals(r, 1)
    r = yield(self.con:zcount("foozset", "-inf", "+inf"))
    assertEquals(r, 3)
    r = yield(self.con:zcount("foozset", "(1", "3"))
    assertEquals(r, 2)
    r = yield(self.con:zcount("foozset", "1", "3"))
    assertEquals(r, 3)
    r = yield(self.con:zcount("foozset", "(1", "(3"))
    assertEquals(r, 1)
end

function TestTurboRedis:test_zincrby()
    local r
    r = yield(self.con:zadd("foozset", 1, "one"))
    assertEquals(r, 1)
    r = yield(self.con:zadd("foozset", 1, "two"))
    assertEquals(r, 1)
    r = yield(self.con:zadd("foozset", 1, "three"))
    assertEquals(r, 1)
    r = yield(self.con:zincrby("foozset", 1, "two"))
    assertEquals(r, "2")
    r = yield(self.con:zincrby("foozset", 2, "three"))
    assertEquals(r, "3")
    r = yield(self.con:zrange("foozset", 0, -1, "withscores"))
    assertEquals(#r, 6)
    assertEquals(r[1], "one")
    assertEquals(r[2], "1")
    assertEquals(r[3], "two")
    assertEquals(r[4], "2")
    assertEquals(r[5], "three")
    assertEquals(r[6], "3")
end

function TestTurboRedis:test_zinterstore()
    local r
    r = yield(self.con:zadd("foozset", 1, "one"))
    assertEquals(r, 1)
    r = yield(self.con:zadd("foozset", 2, "two"))
    assertEquals(r, 1)
    r = yield(self.con:zadd("barzset", 2, "two"))
    assertEquals(r, 1)
    r = yield(self.con:zadd("barzset", 3, "three"))
    assertEquals(r, 1)
    r = yield(self.con:zinterstore("foobarzset", 2, "foozset", "barzset"))
    assertEquals(r, 1)
    r = yield(self.con:zrange("foobarzset", 0, -1, "withscores"))
    assertEquals(#r, 2)
    assertEquals(r[1], "two")
    assertEquals(r[2], "4")
    -- TODO: Test with weights and aggregate
end

function TestTurboRedis:test_zrange()
    local r
    r = yield(self.con:zadd("foozset", 1, "one"))
    assertEquals(r, 1)
    r = yield(self.con:zadd("foozset", 2, "two"))
    assertEquals(r, 1)
    r = yield(self.con:zrange("foozset", 0, -1, "withscores"))
    assertEquals(#r, 4)
    assertEquals(r[1], "one")
    assertEquals(r[2], "1")
    assertEquals(r[3], "two")
    assertEquals(r[4], "2")
    r = yield(self.con:zadd("foozset", 3, "three"))
    assertEquals(r, 1)
    r = yield(self.con:zrange("foozset", 0, -1, "withscores"))
    assertEquals(#r, 6)
    assertEquals(r[1], "one")
    assertEquals(r[2], "1")
    assertEquals(r[3], "two")
    assertEquals(r[4], "2")
    assertEquals(r[5], "three")
    assertEquals(r[6], "3")
    r = yield(self.con:zrange("foozset", 0, -1))
    assertEquals(#r, 3)
    assertEquals(r[1], "one")
    assertEquals(r[2], "two")
    assertEquals(r[3], "three")
end

function TestTurboRedis:test_zrangebyscore()
    local r
    r = yield(self.con:zadd("foozset", 1, "one"))
    assertEquals(r, 1)
    r = yield(self.con:zadd("foozset", 2, "two"))
    assertEquals(r, 1)
    r = yield(self.con:zadd("foozset", 3, "three"))
    assertEquals(r, 1)
    r = yield(self.con:zrangebyscore("foozset", "-inf", "+inf"))
    assertEquals(#r, 3)
    assertEquals(r[1], "one")
    assertEquals(r[2], "two")
    assertEquals(r[3], "three")
    r = yield(self.con:zrangebyscore("foozset", "-inf", "+inf", "withscores"))
    assertEquals(#r, 6)
    assertEquals(r[1], "one")
    assertEquals(r[2], "1")
    assertEquals(r[3], "two")
    assertEquals(r[4], "2")
    assertEquals(r[5], "three")
    assertEquals(r[6], "3")
    r = yield(self.con:zrangebyscore("foozset", "1", "2", "withscores"))
    assertEquals(#r, 4)
    assertEquals(r[1], "one")
    assertEquals(r[2], "1")
    assertEquals(r[3], "two")
    assertEquals(r[4], "2")
    r = yield(self.con:zrangebyscore("foozset", "(2", "5", "withscores"))
    assertEquals(#r, 2)
    assertEquals(r[1], "three")
    assertEquals(r[2], "3")
    r = yield(self.con:zrangebyscore("foozset", "(2", "5"))
    assertEquals(#r, 1)
    assertEquals(r[1], "three")
end

function TestTurboRedis:test_zrank()
    local r
    r = yield(self.con:zadd("foozset", 1, "one"))
    assertEquals(r, 1)
    r = yield(self.con:zadd("foozset", 2, "two"))
    assertEquals(r, 1)
    r = yield(self.con:zadd("foozset", 3, "three"))
    assertEquals(r, 1)
    r = yield(self.con:zrank("foozset", "one"))
    assertEquals(r, 0)
    r = yield(self.con:zrank("foozset", "two"))
    assertEquals(r, 1)
    r = yield(self.con:zrank("foozset", "three"))
    assertEquals(r, 2)
end

function TestTurboRedis:test_zrem()
    local r
    r = yield(self.con:zadd("foozset", 1, "one"))
    assertEquals(r, 1)
    r = yield(self.con:zadd("foozset", 2, "two"))
    assertEquals(r, 1)
    r = yield(self.con:zadd("foozset", 3, "three"))
    assertEquals(r, 1)
    r = yield(self.con:zrange("foozset", 0, -1, "withscores"))
    assertEquals(#r, 6)
    assertEquals(r[1], "one")
    assertEquals(r[2], "1")
    assertEquals(r[3], "two")
    assertEquals(r[4], "2")
    assertEquals(r[5], "three")
    assertEquals(r[6], "3")
    r = yield(self.con:zrem("foozset", "one"))
    assertEquals(r, 1)
    r = yield(self.con:zrange("foozset", 0, -1, "withscores"))
    assertEquals(#r, 4)
    assertEquals(r[1], "two")
    assertEquals(r[2], "2")
    assertEquals(r[3], "three")
    assertEquals(r[4], "3")
    r = yield(self.con:zrem("foozset", "three", "four"))
    assertEquals(r, 1)
    r = yield(self.con:zrange("foozset", 0, -1, "withscores"))
    assertEquals(#r, 2)
    assertEquals(r[1], "two")
    assertEquals(r[2], "2")
end

function TestTurboRedis:test_zremrangebyrank()
    local r
    r = yield(self.con:zadd("foozset", 1, "one"))
    assertEquals(r, 1)
    r = yield(self.con:zadd("foozset", 2, "two"))
    assertEquals(r, 1)
    r = yield(self.con:zadd("foozset", 3, "three"))
    assertEquals(r, 1)
    r = yield(self.con:zremrangebyrank("foozset", 0, 1))
    assertEquals(r, 2)
    r = yield(self.con:zrange("foozset", 0, -1, "withscores"))
    assertEquals(#r, 2)
    assertEquals(r[1], "three")
    assertEquals(r[2], "3")
end

function TestTurboRedis:test_zremrangebyscore()
    local r
    r = yield(self.con:zadd("foozset", 1, "one"))
    assertEquals(r, 1)
    r = yield(self.con:zadd("foozset", 2, "two"))
    assertEquals(r, 1)
    r = yield(self.con:zadd("foozset", 3, "three"))
    assertEquals(r, 1)
    r = yield(self.con:zremrangebyscore("foozset", 1, 2))
    assertEquals(r, 2)
    r = yield(self.con:zrange("foozset", 0, -1, "withscores"))
    assertEquals(#r, 2)
    assertEquals(r[1], "three")
    assertEquals(r[2], "3")
end

function TestTurboRedis:test_zrevrange()
    local r
    r = yield(self.con:zadd("foozset", 1, "one"))
    assertEquals(r, 1)
    r = yield(self.con:zadd("foozset", 2, "two"))
    assertEquals(r, 1)
    r = yield(self.con:zadd("foozset", 3, "three"))
    assertEquals(r, 1)
    r = yield(self.con:zadd("foozset", 4, "four"))
    assertEquals(r, 1)
    r = yield(self.con:zrevrange("foozset", 0, -1, "withscores"))
    assertEquals(#r, 8)
    assertEquals(r[1], "four")
    assertEquals(r[2], "4")
    assertEquals(r[3], "three")
    assertEquals(r[4], "3")
    assertEquals(r[5], "two")
    assertEquals(r[6], "2")
    assertEquals(r[7], "one")
    assertEquals(r[8], "1")
    r = yield(self.con:zrevrange("foozset", 0, 2))
    assertEquals(#r, 3)
    assertEquals(r[1], "four")
    assertEquals(r[2], "three")
    assertEquals(r[3], "two")
end

function TestTurboRedis:test_zrevrangebyscore()
    local r
    r = yield(self.con:zadd("foozset", 1, "one"))
    assertEquals(r, 1)
    r = yield(self.con:zadd("foozset", 2, "two"))
    assertEquals(r, 1)
    r = yield(self.con:zadd("foozset", 3, "three"))
    assertEquals(r, 1)
    r = yield(self.con:zadd("foozset", 4, "four"))
    assertEquals(r, 1)
    r = yield(self.con:zrevrangebyscore("foozset", 4, 0, "withscores"))
    assertEquals(#r, 8)
    assertEquals(r[1], "four")
    assertEquals(r[2], "4")
    assertEquals(r[3], "three")
    assertEquals(r[4], "3")
    assertEquals(r[5], "two")
    assertEquals(r[6], "2")
    assertEquals(r[7], "one")
    assertEquals(r[8], "1")
    r = yield(self.con:zrevrangebyscore("foozset", 4, 2))
    assertEquals(#r, 3)
    assertEquals(r[1], "four")
    assertEquals(r[2], "three")
    assertEquals(r[3], "two")
end

function TestTurboRedis:test_zrevrank()
    local r
    r = yield(self.con:zadd("foozset", 1, "one"))
    assertEquals(r, 1)
    r = yield(self.con:zadd("foozset", 2, "two"))
    assertEquals(r, 1)
    r = yield(self.con:zrevrank("foozset", "one"))
    assertEquals(r, 1)
    r = yield(self.con:zrevrank("foozset", "two"))
    assertEquals(r, 0)
    r = yield(self.con:zrevrank("foozset", "three"))
    assertEquals(r, nil)
end

function TestTurboRedis:test_zscore()
    local r
    r = yield(self.con:zadd("foozset", 1, "one"))
    assertEquals(r, 1)
    r = yield(self.con:zadd("foozset", 2, "two"))
    assertEquals(r, 1)
    r = yield(self.con:zscore("foozset", "one"))
    assertEquals(r, "1")
    r = yield(self.con:zscore("foozset", "two"))
    assertEquals(r, "2")
    r = yield(self.con:zscore("foozset", "four"))
    assertEquals(r, nil)
end

function TestTurboRedis:test_zunionstore()
    local r
    r = yield(self.con:zadd("foozset", 1, "one"))
    assertEquals(r, 1)
    r = yield(self.con:zadd("foozset", 2, "two"))
    assertEquals(r, 1)
    r = yield(self.con:zadd("barzset", 1, "one"))
    assertEquals(r, 1)
    r = yield(self.con:zadd("barzset", 2, "two"))
    assertEquals(r, 1)
    r = yield(self.con:zadd("barzset", 3, "three"))
    assertEquals(r, 1)   
    r = yield(self.con:zunionstore("foobarzset", 2, "foozset", "barzset", "weights", 2, 3))
    assertEquals(r, 3)
    r = yield(self.con:zrange("foobarzset", 0, -1, "withscores"))
    assertEquals(r[1], "one")
    assertEquals(r[2], "5")
    assertEquals(r[3], "three")
    assertEquals(r[4], "9")
    assertEquals(r[5], "two")
    assertEquals(r[6], "10")
end

function TestTurboRedis:test_scan()
    local r
    r = yield(self.con:set("foo", "bar"))
    r = yield(self.con:set("bar", "foo"))
    r = yield(self.con:scan(0))
    assertEquals(#r, 2)
    assertEquals(r[1], "0")
    assert(r[2][1] == "bar" or r[2][1] == "foo")
    assert(r[2][2] == "bar" or r[2][2] == "foo")
end

--[[
function TestTurboRedis:test_sscan()
end
function TestTurboRedis:test_hscan()
end
function TestTurboRedis:test_zscan()
end
]]--

function TestTurboRedis:test_pipeline()
    local r
    local pl = self.con:pipeline()
    pl:set("foo", "bar")
    pl:set("bar", "foo")
    pl:get("foo")
    pl:get("bar")
    r = yield(pl:run())
    assertEquals(#r, 4)
    assertEquals(r[1][1], true)
    assertEquals(r[2][1], true)
    assertEquals(r[3], "bar")
    assertEquals(r[4], "foo")
    pl:clear()
    for i=1, 10 do
        pl:set("foo" .. tostring(i), "bar")
    end
    r = yield(pl:run())
    assertEquals(#r, 10)
    for i=1, 10 do
        r = yield(self.con:get("foo" .. tostring(i)))
        assertEquals(r, "bar")
    end
end

-------------------------------------------------------------------------------

TestTurboRedisPubSub = {}

function TestTurboRedisPubSub:setUp()
    _G.io_loop_instance = nil
    self.ioloop = turbo.ioloop.instance()
    self.con = turboredis.Connection:new(options.host, options.port)
    self.pcon = turboredis.PubSubConnection:new(options.host, options.port)
end

function TestTurboRedisPubSub:connect()
    local r
    r = yield(self.con:connect())
    assert(r)
    r = yield(self.pcon:connect())
    assert(r)
    r = yield(self.con:flushall())
    assert(r)
end

function TestTurboRedisPubSub:done()
    r = yield(self.pcon:unsubscribe())
    assert(r)
    r = yield(self.pcon:punsubscribe())
    assert(r)
end

function TestTurboRedisPubSub:tearDown()
    local r
    r = yield(self.con:disconnect())
    assert(r)
    r = yield(self.pcon:disconnect())
    assert(r)
end

function TestTurboRedisPubSub:test_psubscribe()
    local io = self.ioloop
    io:add_callback(function ()
        local r
        self:connect()
        r = yield(self.pcon:psubscribe("f*"))
        assert(r)
        self.pcon:start(function (msg)
            if msg.msgtype == "psubscribe" then
                assertEquals(msg.pattern, "f*")
                r = yield(self.con:publish("foo", "abc"))
                assert(r)
            elseif msg.msgtype == "pmessage" then
                assertEquals(msg.pattern, "f*")
                assertEquals(msg.channel, "foo")
                assertEquals(msg.data, "abc")
                self:done()
                io:close()
            end
        end)

    end)
    io:wait(5)
end


function TestTurboRedisPubSub:test_pubsub_channels()
    local io = self.ioloop
    io:add_callback(function ()
        local r
        self:connect()
        r = yield(self.con:pubsub_channels("*"))
        assertEquals(#r, 0)
        self.pcon:start(function ()
            r = yield(self.con:pubsub_channels())
            assertEquals(#r, 1)
            self:done()
            io:close()
        end)
        r = yield(self.pcon:subscribe("foo"))
        assert(r)
    end)
    io:wait(2)
end

function TestTurboRedisPubSub:test_pubsub_numpat()
    local io = self.ioloop
    io:add_callback(function ()
        local r
        self:connect()
        r = yield(self.con:pubsub_numpat())
        assertEquals(r, 0)
        self.pcon:start(function ()
            r = yield(self.con:pubsub_numpat())
            assertEquals(r, 1)
            self:done()
            io:close()
        end)
        r = yield(self.pcon:psubscribe("fooz*"))
        assert(r)
    end)
    io:wait(2)
end

function TestTurboRedisPubSub:test_pubsub_numsub()
    local io = self.ioloop
    io:add_callback(function ()
        local r
        self:connect()
        r = yield(self.con:pubsub_numsub("foo"))
        assertEquals(r.foo, 0)
        r = yield(self.pcon:subscribe("foo"))
        assert(r)
        self.pcon:start(function ()
            local r
            r = yield(self.con:pubsub_numsub("foo"))
            assertEquals(r.foo, 1)
            self:done()
            io:close()
        end)
    end)
    io:wait(2)
end

function TestTurboRedisPubSub:test_publish()
    local io = self.ioloop
    io:add_callback(function ()
        local r
        self:connect()
        r = yield(self.pcon:subscribe("foo"))
        assert(r)
        self.pcon:start(function (msg)
            if msg.msgtype == "subscribe" then
                assertEquals(msg.channel, "foo")
                r = yield(self.con:publish("foo", "abc"))
                assert(r)
            elseif msg.msgtype == "message" then
                assertEquals(msg.channel, "foo")
                assertEquals(msg.data, "abc")
                self:done()
                io:close()
            end
        end)
    end)
    io:wait(5)
end

function TestTurboRedisPubSub:test_punsubscribe()
    local io = self.ioloop
    io:add_callback(function ()
        local r
        self:connect()
        r = yield(self.pcon:psubscribe("f*"))
        assert(r)
        r = yield(self.pcon:psubscribe("*oo"))
        assert(r)
        self.pcon:start(function (msg)
            if msg.msgtype == "psubscribe" then
                assert(msg.pattern == "f*" or msg.pattern == "*oo")
            elseif msg.msgtype == "punsubscribe" then
                assert(msg.pattern == "f*" or msg.pattern == "*oo")
                assertEquals(msg.channel, nil)
                if msg.pattern == "f*" then
                    assertEquals(msg.data, 1)
                else
                    assertEquals(msg.data, 0)
                    self:done()
                    io:close()
                end
            end
        end)
        r = yield(self.pcon:punsubscribe("f*"))
        assert(r)
        r = yield(self.pcon:punsubscribe("*oo"))
        assert(r)
    end)
    io:wait(5)
end

TestTurboRedisPubSub.test_subscribe = TestTurboRedisPubSub.test_publish

function runtests()
    LuaUnit.LuaUnit.run("TestTurboRedis")
    turbo.ioloop.instance():close()
    LuaUnit.LuaUnit.run("TestTurboRedisPubSub")
end

turbo.ioloop.instance():add_callback(runtests)
turbo.ioloop.instance():wait(60)