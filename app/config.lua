local posix = require("posix")

local config = {}
local redfish = {
	MAJOR = '1', -- something in the class changed in a backward incompatible way
	MINOR = '1', -- a minor update. New functionality may have been added but nothing removed. Compatibility will be preserved with previous minorversions
	ERRATA = '0' -- something in the prior version was broken and needed to be fixed
}

--App Settings
local stat = posix.stat or posix.sys.stat.stat
if stat("/info") ~= nil then
    config.USE_SPX_PAM = true
    config.SERVICE_HOST = "127.0.0.1"
else
    config.USE_SPX_PAM = false
    config.SERVICE_HOST = "0.0.0.0"
end
config.SERVICE_PORT = 9080
config.UUID = "92384634-2938-2342-8820-489239905423"
config.TRANSACTIONS_ENFORCED = true

--redis Settings
config.redis_host = "127.0.0.1"
config.redis_port = 6379
config.redis_sock = "/run/redis/redis.sock"

--CONSTANTS
config.SERVICE_PREFIX = "/redfish/v" .. redfish.MAJOR
config.REDFISH_VERSION = redfish.MAJOR .. '.' .. redfish.MINOR .. '.' .. redfish.ERRATA
config.SERVER_NAME = "AMI MegaRAC Redfish Service"
config.MAX_SESSIONS = 10
config.SESSION_TIMEOUT = 30 * 60 * 1000  -- 30 minutes
config.SESSION_TIMEOUT_POLL_INTERVAL = 5 * 1000  
config.DEFAULT_COLLECTION_LIMIT = 50
config.PATCH_TIMEOUT = 15 * 1000 -- 15 seconds
config.MAX_TASKS = 5

config.APP_PATH = "/usr/local/redfish-lua/"

--SECURE
config.SALT = "spx"

config.SESSION_PATH = "/tmp/"

--debugging prints
config.PRINT_SUCCESS = true
config.PRINT_NOTICE = true
config.PRINT_WARNING = true
config.PRINT_ERROR =  true
config.PRINT_DEBUG = true
config.PRINT_DEVELOPMENT = false

config.BIOS_CONF_PATH = "/conf/redfish/bios/"
config.BIOS_CURRENT_PATH = config.BIOS_CONF_PATH .. "bios_current_settings.json"
config.BIOS_FUTURE_PATH = config.BIOS_CONF_PATH .. "bios_future_settings.json"
config.BIOS_PASS_PATH = config.BIOS_CONF_PATH .. "bios_pass.json"
config.BIOS_RESET_PATH = config.BIOS_CONF_PATH .. "bios_reset"

config.CA_CERT_PATH = "/conf/ca.pem"


--Profiling/Logging
	-- LOG_GLOBAL_TABLE: sets a signal handler that prints the entire lua global table to a log file, 
	-- 		use command "kill -s SIGUSR1 <pid>" to trigger the handler, log files are found in redfish-lua/logs/global_table(*).log
	--		log files are named by the number of times SIGUSR1 has been sent to the server, in the form 'global_table<num>.log'
	-- 		logging the global table will overwrite global table logs from previous runs of 'luajit server.lua', so backup any logs you want to keep!
	config.LOG_GLOBAL_TABLE = false
	-- DBG_HANDLER_MEMORY: prints the memory in use by lua immediately after each request is handled and immediately before it finishes, 
	-- 		as well as the difference, to the server debug output
	config.DBG_HANDLER_MEMORY = false


return config
