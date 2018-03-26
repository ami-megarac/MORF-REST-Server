package.path = package.path .. ";../?;../?.lua;"

local _ = require('underscore')
local redis = require('redis')
local CONFIG = require('config')

local params = {
    -- host = CONFIG.redis_host,
    -- port = CONFIG.redis_port,
    path = CONFIG.redis_sock,
    scheme = 'unix',
    timeout = 0
}

local client = redis.connect(params)
local db = redis.connect(params)

local redis_db_index = 0
-- choose db if needed
client:select(redis_db_index)

local settings = {}

settings.apply = function(event_data)
    print("Calling On" .. event_data)
    local keys = db:keys("On" .. event_data .. ":*")
    _.each(keys, function(k)
        local _start, _end, stripped_key = k:find("On" .. event_data .. ":(.*)")
        local key_type = db:type(k)

        if key_type == "string" then
            local data = db:get(k)
            db:set(stripped_key, data)
        elseif key_type == "hash" then
            local data = db:hgetall(k)
            for hash_key, hash_val in pairs(data) do
                db:hset(stripped_key, hash_key, hash_val)
            end
        elseif key_type == "list" then
            local data = db:lrange(k, 0, -1)
            db:del(stripped_key)
            for list_key, list_val in pairs(data) do
                db:rpush(stripped_key, list_val)
            end
        elseif key_type == "set" then
            local data = db:smembers(k)
            db:del(stripped_key)
            for set_key, set_val in pairs(data) do
                db:sadd(stripped_key, set_val)
            end
        end

        db:del(k)
    end)
end

return settings