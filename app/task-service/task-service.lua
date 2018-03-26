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

package.path = package.path .. ";./task-service/libs/?.lua;./task-service/libs/?;;./libs/?;./libs/?.lua;"
-- [See "utils.lua"](/utils.html)
local utils = require('utils')

utils.daemon("/var/run/task-service.pid")
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

-- Following diagram depicts the architecture of Task Service
-- ![Task Service Block Diagram](/images/task-service.png)
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
local map = {'Redfish:TaskService:ServiceEnabled', 'Redfish:TaskService:TaskList'}

local channels = {}

local ch_prefix = '__keyspace@'.. redis_db_index ..'__:'

_.each(map, function(item) 
	table.insert(channels, ch_prefix .. item)
end)

local changes = client:pubsub({psubscribe = channels})

local service_enabled = false

-- Primary coroutine that listens on the channel and performs the function triggers for registered keys change events
local task_service = coroutine.wrap(function()

	service_enabled = db:get('Redfish:TaskService:ServiceEnabled') == 'false' and false or true

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
			    elseif event == 'rpush' then
			    	value = db:lpop(redis_key)
			    end

			    if redis_key == 'Redfish:TaskService:ServiceEnabled' then

			    	if value == 'false' then
			    		-- mark as service stopped
			    		service_enabled = false
			    	elseif value == 'true' then
			    		-- mark as service started
			    		service_enabled = true
			    	end

			    elseif service_enabled and value ~= nil then

			    	local task_prefix = "Redfish:TaskService:Tasks:"

			    	local this_task = task_prefix .. value

			    	local task = db:mget({
			    			this_task .. ":TaskType",
			    			this_task .. ":TaskIPCData",
			    			this_task .. ":TaskWebRequestData"
			    		})

			    	local result = nil

		    		-- switch based on incoming task type

		    		if task[1] == "IPC_PROCESS" then
		    			-- expect IPCData to be of structure
		    			-- {IPC_TYPE = "", IPC_ADDRESS = { IPC_IP = "127.0.0.1", IPC_PORT = 8080 | IPC_PIPE = "" | IPC_SOCKET = ""}, IPC_DATA = ""}

		    		elseif task[1] == "LUA_SCRIPT" then

		    			-- expect IPCData to be of string - lua program name with full path
		    			-- the lua program should have absolute package path
		    			-- The first argument will be the key of the task that is getting starting
		    			-- The second argument is the web request json data as a string
		    			-- lua program must decode this string json data to a Lua Table (program can use turbo.escape.json_decode)
		    			local program, prg_args = task[2], task[3]

		    			-- The tasks can be run sequentially in the order they are sent using the following command. This will be better for lower resource systems.
		    			-- result = utils.sub_process(program, this_task, prg_args)

		    			-- The tasks can be run in parallel as they come using the following command
		    			result = utils.sub_process_nonblocking(program, this_task, prg_args)

		    		elseif task[1] == "SYSTEM_CALL" then

		    			-- expect IPCData to be of structure
		    			-- { ProgramName = "", Args = {}}
		    			local program, prg_args = unpack(turbo.escape.json_decode(task[2]))

		    			result = posix.execp(program, unpack(prg_args))

		    		elseif task[1] == "CLIB_CALL" then

		    			-- expect IPCData to be of structure
		    			-- { LibraryFile = "", cdefinitions = "", FunctionToCall = "", FunctionArgs = {}}

		    			local LibraryFile, cdefinitions, FunctionToCall, FunctionArgs  = unpack(turbo.escape.json_decode(task[2]))

		    			local ffi = require("ffi")

		    			ffi.cdef(cdefinitions)

		    			local lib = ffi.load(LibraryFile)

		    			-- TODO Binary data !! not string

		    			lib[FunctionToCall](unpack(FunctionArgs))

		    		end

		    		-- Every task is done as forked process

		    		---- Another Service start

		    		---- library calling task also done in forked manner to avoid blocking operation

		    		---- OEM extensions

	    		end
	    	
		    end

	    end
	    coroutine.yield()
	end
end)

print("Launching Task-Service...")
-- Handle SIGTERM
ret = posix.signal(posix.SIGTERM, function() os.remove("/var/run/task-service.pid"); posix._exit(0) end)
-- Run task service
while true do
 	task_service()
end