package.path = package.path .. ";./?.lua;./?;./libs/?.lua;./libs/?;./oem/?.lua;./oem/?;./redfish/?.lua;./redfish/?"
-- ![](./images/redfish.png)

-- [See "utils.lua"](./utils.html)
local utils = require("utils")

utils.daemon("/var/run/redfish-server.pid")
-- [See "config.lua"](./config.html)
local CONFIG = require("config")
local turboredis = require("turboredis")
-- Import required libraries
-- [See "turbo library"](http://turbolua.org)
local turbo = require("turbo")
-- [See "luaposix"](https://github.com/luaposix/luaposix)
local posix_present, posix = pcall(require, "posix")

-- [See "redfish-handler.lua"](./redfish-handler.html)
local RedfishHandler = require("redfish-handler")


turbo.log.categories.success = CONFIG.PRINT_SUCCESS
turbo.log.categories.notice = CONFIG.PRINT_NOTICE
turbo.log.categories.warning = CONFIG.PRINT_WARNING
turbo.log.categories.error = CONFIG.PRINT_ERROR
turbo.log.categories.debug = CONFIG.PRINT_DEBUG
turbo.log.categories.development = CONFIG.PRINT_DEVELOPMENT


-- Import error codes globally

-- [See "error-codes.lua"](./error-codes.html)
require("error-codes")

-- Here you import all OEM router table. Based on specification OEM should implement its own resource end-points,
-- if the data provided under each Oem section is relatively large. 
-- Smaller data can be provided under Oem section of each resource end-points itself

local route_table = {}
local oem_route_table = {}

-- Redfish spec allows multiple OEM information to co-exist.
-- Make a protected call to oem route so that it won't fail if the oem directory does not exists.
-- Note that oem directory will be in a separate SPX package and will be imported only if chosen as one of the PRJ feature.
-- It is designed to work with or without the oem folder and hence we use a protected call to load

local oem_dirs = utils.get_oem_dirs()

for oi, on in ipairs(oem_dirs) do

	local oem_exists, oem_route_table =  pcall(require, on .. ".route")

	if oem_exists then
	    utils.array_merge(route_table, oem_route_table)
	end

end

-- Loading in other route extensions
local files, errstr, errno = posix.dir("./extensions/routes")
if files then
    for fi, fn in ipairs(files) do
    	if fn ~= "." and fn ~= ".." then
    		local route_exists, routes =  pcall(dofile, "extensions/routes/" .. fn)
    		if route_exists and routes ~= nil then
        		utils.array_merge(route_table, routes)
        	end
        end
    end
else
    print("Empty routes directory")
end

-- Loading all the default routes
-- [See "default_route.lua"](./default_route.html)
utils.array_merge(route_table, require("default_route"))

local app = turbo.web.Application:new(route_table)

-- Set default server name, ports and send a notice that the service has started
turbo.log.notice("Redfish server listening http://" .. CONFIG.SERVICE_HOST .. ":" .. CONFIG.SERVICE_PORT)
app:set_server_name(CONFIG.SERVER_NAME)
app:listen(CONFIG.SERVICE_PORT, CONFIG.SERVICE_HOST)

-- You can enable logging in config.lua. This is useful to find memory leaks
local LogGlobalTable 
if CONFIG.LOG_GLOBAL_TABLE then
	local logcount = 0;
	LogGlobalTable = function ()
			logcount = logcount + 1;
			local logname = "../logs/global_table"..logcount..".log"
			local logfile = io.open(logname, "w")
			logfile:write(turbo.log.stringify(_G, "GLOBAL"))
			logfile:close()
			turbo.log.debug("Global table logged to: '"..logname.."'")
		end
else
	LogGlobalTable = function () return end
end

-- Signal handler callback for exiting Redfish gracefully
local GracefulExit = function ()
	turbo.log.warning("Graceful exit triggered, Redfish service will close...")
	-- Remove event-service process
	local es_pid = utils.read_from_pid_file("/var/run/event-service.pid")
	if es_pid then
		-- TODO: luaposix signal handler is unreliable, so for now we force the shutdown with SIGKILL
		-- local ret = posix.kill(es_pid, posix.SIGTERM)

		local ret = posix.kill(es_pid, posix.SIGKILL)
		os.remove("/var/run/event-service.pid")
    end
	-- Remove task-service process
	local ts_pid = utils.read_from_pid_file("/var/run/task-service.pid")
    if ts_pid then
    	-- TODO: luaposix signal handler is unreliable, so for now we force the shutdown with SIGKILL
		-- local ret = posix.kill(ts_pid, posix.SIGTERM)

		local ret = posix.kill(ts_pid, posix.SIGKILL)
		os.remove("/var/run/task-service.pid")
    end
	os.remove("/var/run/redfish-server.pid")
	turbo.ioloop.instance():close()
	turbo.log.warning("Goodbye!")
end

-- Register a signal handler for graceful exit on demand
turbo.ioloop.instance():add_signal_handler(turbo.signal.SIGUSR2, GracefulExit)
turbo.ioloop.instance():add_signal_handler(turbo.signal.SIGTERM, GracefulExit)

-- Register a signal handler for provoking log operation on demand
turbo.ioloop.instance():add_signal_handler(turbo.signal.SIGUSR1, LogGlobalTable)

-- [See "event-service/event-service.lua"](./event-service/event-service.html)
utils.sub_process("./event-service/event-service.lua")
-- [See "task-service/task-service.lua"](./task-service/task-service.html)
utils.sub_process("./task-service/task-service.lua")


turbo.ioloop.instance():add_callback(function()
	local db = turboredis.Connection:new(CONFIG.redis_sock, 0, {family=turbo.socket.AF_UNIX});
	if not coroutine.yield(db:connect()) then
		error(turbo.web.HTTPError:new(500, "DB is busy"))
	end
	if((coroutine.yield(db:get("Redfish:LastModified"))) ~= nil) then
		local LastModified = tonumber(coroutine.yield(db:get("Redfish:LastModified")))
		if LastModified == 0 then
			LastModified = os.date('%s')
			coroutine.yield(db:set("Redfish:LastModified", LastModified))
			print("Setting initial boot timestamp : " .. LastModified .. " to redis db")
		end
	else
		coroutine.yield(db:set("Redfish:LastModified"),os.date('%s'))
	end
end):start()
