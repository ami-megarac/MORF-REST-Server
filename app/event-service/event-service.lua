--[[
   Copyright 2018 American Megatrends Inc.

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
--]]

package.path = package.path .. ";./event-service/libs/?.lua;./event-service/libs/?;;./libs/?;./libs/?.lua;"
-- [See "utils.lua"](/utils.html)
local utils = require('utils')

utils.daemon("/var/run/event-service.pid")
-- [See "redis.lua"](https://github.com/nrk/redis-lua)
local redis = require('redis')
-- [See "posix.lua"](https://github.com/luaposix/luaposix/tree/v5.1.19)
local posix = require('posix')
-- [See "config.lua"](/config.html)
local CONFIG = require("config")
-- [See "turbo.lua"](http://turbolua.org)
local turbo = require('turbo')
-- [See "underscore.lua"](https://mirven.github.io/underscore.lua/)
local _ = require('underscore')
-- [See "httpclient.lua"](https://github.com/lusis/lua-httpclient)
local HTTPClient = require('httpclient')

-- Following diagram depicts the architecture of Event Service
-- ![Event Service Block Diagram](/images/event-service.png)
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

-- Set the keyspace notification as redis conf
client:config('set', 'notify-keyspace-events','KEA')


-- TODO: change this to configurable option. Where they can choose keyspace or keyevent notification
-- From this channel we will know any operation performed on any key
-- We will be most interested in SET, SADD, HSET, HMSET, MSET kind of operations
-- Identify all possible set commands required and subscribe individually, to avoid subscription overload
local map = {'Redfish:EventService:ServiceEnabled', 'Redfish:*:*:LogServices:*:Entries:*'}

local channels = {}

local ch_prefix = '__keyspace@'.. redis_db_index ..'__:'

_.each(map, function(item) 
	table.insert(channels, ch_prefix .. item)
end)

local changes = client:pubsub({psubscribe = channels})

local service_enabled = true

local event_service = coroutine.wrap(function() 

	service_enabled = db:get('Redfish:EventService:ServiceEnabled') == 'false' and false or true
	local max_retries = tonumber(db:get("Redfish:EventService:DeliveryRetryAttempts"))
	local retry_interval = tonumber(db:get("Redfish:EventService:DeliveryRetryIntervalSeconds"))

	while true do
		-- The changes is a coroutine wrap which when called, resumes automatically
		local msg, abort = changes()

		-- ignore the psubscribe notification that you get as soon as you subscribe
		if msg and msg.kind ~= "psubscribe" then 
			-- can be a string or table
		    local value = nil

		    local redis_key = string.sub(msg.channel, string.len(ch_prefix)+1)

		    -- Skip unwanted key patterns
		    -- If the changed redis_key is valid
		    if redis_key then
				
		    	-- retrieve the event type
				local event = msg.payload

		    	-- mset and other multi operations just trigger corresponding set operation multiple times
			    if event == 'set' then
			    	value = db:get(redis_key)
			    elseif event == 'sadd' then
			    	value = db:smembers(redis_key)
			    elseif event == 'hset' then
			    	value = db:hgetall(redis_key) -- One for each eventrecord because setting MUST be done with HMSET
			    end

			    -- check if service should stop
			    if redis_key == 'Redfish:EventService:ServiceEnabled' then
			    	if value == 'false' then
			    		-- mark as service stopped
			    		service_enabled = false
			    	elseif value == 'true' then
			    		-- mark as service started
			    		service_enabled = true
			    	end

			    elseif service_enabled and type(value) == "table" and event == 'hset' then
		    		-- Incoming hgetall for events
		    		local event_record = utils.convertHashListToArray(value)
		    		if utils.table_len(event_record) == 0 then
			    		event_record = {value}
			    	end

		    		-- Get event type from key
		    		local event_type = event_record[1]["EventType"]

		    		-- Add the event type to all the event records under this
		    		for k,v in pairs(event_record) do
		    			event_record[k]["EventType"] = event_type
		    			event_record[k]["MemberId"] = k
						if event_record[k]["OriginOfCondition"] and type(event_record[k]["OriginOfCondition"]) == "string" then
		    				temp = event_record[k]["OriginOfCondition"]
		    				event_record[k]["OriginOfCondition"] = {}
		    				event_record[k]["OriginOfCondition"]["@odata.id"] = utils.getODataID(temp, 1)
			    		end

						if event_record[k]["MessageArgs"] then
		    				temp = {}
		    				for key, val in pairs(event_record[k]["MessageArgs"]) do
		    					table.insert(temp, val)
		    				end
							event_record[k]["MessageArgs"] = temp
						elseif event_record[k]["MessageArgs:1"] then
							temp = {}
							for event_key, event_data in pairs(event_record[k]) do
								if event_key:find("MessageArgs:") then
									local arg_index = utils.split(event_key, ":")[2]
									temp[tonumber(arg_index)] = event_data
									event_record[k][event_key] = nil
								end
							end

							event_record[k]["MessageArgs"] = temp
		    			end
		    		end

		    		-- This is not subscription Id. This is event ID (Not event record ID either). 
		    		-- So need to check how to auto increment this
		    		local id = "1"

		    		local post_data = {
		    			["@odata.context"] = "/redfish/v1/$metadata#EventService.EventService",
		    			["@odata.id"] = "/redfish/v1/EventService/Events/" .. id,
		    			["@odata.type"] = "#EventService.1.0.0.Event",
		    			["Id"] = id,
		    			["Name"] = "Event Array",
		    			["Events"] = event_record
		    		}

		    		---- OEM extensions
		    		-- TODO get Oem data for Events
		    		-- TODO get Oem data for Event Records

		    		-- Get the subscriber list.
		    		-- We do it everytime because at any point a subscription might change.
		    		local subscribers = db:keys("Redfish:EventService:Subscriptions:*:Destination")

		    		for sk,sv in pairs(subscribers) do
					local sub_ary = utils.split(sv, ':')
		    			local sid = table.remove(sub_ary, #sub_ary-1)

		    			local sub_full = db:mget(
		    					"Redfish:EventService:Subscriptions:"..sid..":Destination",
		    					"Redfish:EventService:Subscriptions:"..sid..":Context",
		    					"Redfish:EventService:Subscriptions:"..sid..":Protocol",
		    					"Redfish:EventService:Subscriptions:"..sid..":HttpHeaders"
		    				)
		    			sub_full[5] = db:smembers(
		    					"Redfish:EventService:Subscriptions:"..sid..":EventTypes"
		    				)


		    			-- If protocol is Redfish
		    			if sub_full[3] == "Redfish" then

		    				-- If current event type is of the interest for this subscriber
		    				if sub_full[5] and utils.array_has(sub_full[5], event_type) then

		    					-- Add context to all event records
		    					-- TODO: Follow up on DMTF proposal https://github.com/DMTF/spmf/issues/898
		    					for ek, ev in ipairs(post_data["Events"]) do
		    						post_data["Events"][ek]["Context"] = sub_full[2]
		    					end

		    					-- POST the events to destination
								local hc = HTTPClient.new()
								local hdrs = {}

								if sub_full[4] then
									hdrs = turbo.escape.json_decode(sub_full[4])
								end

								local repeated = 0
								local res = nil

								repeat
									-- PROBLEM This will block all further subscriptions
									-- TODO Change it such that if response fail, it must be a queued for retries via TaskService 
									-- and notification to other subscriptions must be posted
									if repeated > 0 then posix.sleep(retry_interval) end

									repeated = repeated + 1
									res = hc:post(sub_full[1],turbo.escape.json_encode(post_data),hdrs)

								until res.err == nil or repeated >= max_retries

		    					if res then
			    					if res.err ~= nil then
			    						-- The service may delete a subscription if the number of delivery errors exceeds pre-configured thresholds.
			    						db:del(
					    					"Redfish:EventService:Subscriptions:"..sid..":Destination",
					    					"Redfish:EventService:Subscriptions:"..sid..":Context",
					    					"Redfish:EventService:Subscriptions:"..sid..":Protocol",
					    					"Redfish:EventService:Subscriptions:"..sid..":HttpHeaders",
					    					"Redfish:EventService:Subscriptions:"..sid..":Name",
					    					"Redfish:EventService:Subscriptions:"..sid..":Description",
					    					"Redfish:EventService:Subscriptions:"..sid..":Id",
					    					"Redfish:EventService:Subscriptions:"..sid..":EventTypes"
					    				)
			    					end
		    					end
	    					
		    				end

		    			end

		    		end

		    		-- Delete the event to make room for incoming
		    		--db:del(redis_key)
		    		

	    		end

	    		-- TODO: Services may terminate a subscription by sending a special "subscription terminated" event as the last message. 
	    		-- Future requests to the associated subscription resource will respond with HTTP status 404.
	    	
		    end

	    end
	    coroutine.yield()
	end

end)

-- turbo.ioloop.instance():set_interval(1, function()
-- 	event_service()
-- end)


-- turbo.ioloop.instance():start()

print("Launching Event-Service...")
-- Handle SIGTERM
ret = posix.signal(posix.SIGTERM, function() os.remove("/var/run/event-service.pid"); posix._exit(0) end)
-- Run event service
while true do
 	event_service()
end