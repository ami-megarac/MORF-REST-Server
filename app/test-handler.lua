-- Import required libraries
-- [See "redfish-handler.lua"](/redfish-handler.html)
local RedfishHandler = require("redfish-handler")
-- [See "constants.lua"](/constants.html)
local CONSTANTS = require("constants")
-- [See "config.lua"](/config.html)
local CONFIG = require("config")
-- [See "utils.lua"](/utils.html)
local utils = require("utils")
-- [See "turbo library"](http://turbolua.org)
local turbo = require("turbo")
-- [See "underscore.lua"](https://mirven.github.io/underscore.lua/)
local _ = require("underscore")

local posix = require("posix")

local TestHandler = class("TestHandler", RedfishHandler)

local yield = coroutine.yield

local singleton_oem_path = "test-handler"
TestHandler:set_oem_singleton_path(singleton_oem_path)

function TestHandler:get()

	self:set_scope("Redfish")

	-- Retrieve service root data from the database
	-- Note: ServiceRoot links are stored in redis db as a hash that should be configured at build time.
	-- db_init should be updated on a project-by-project basis with the correct services.
    local redis = self:get_db()
    local pl = redis:pipeline()
	
	pl:get("Redfish:UUID")
	local db_result = yield(pl:run())

	local UUID = unpack(db_result)
	local response = {}

	response["Id"] = "RootService"
	response["Name"] = "Root Service"
	response["Description"] = "The service root for all Redfish requests on this host"
	response["RedfishVersion"] = CONFIG.REDFISH_VERSION
	response["UUID"] = UUID

	response = self:oem_extend(response, "query." .. self:get_oem_singleton_path())
	
	self:set_type(CONSTANTS.SERVICE_ROOT_TYPE)
	self:set_context("ServiceRoot")

	utils.remove_nils(response)

	self:set_response(response)

	-- GET requests must respond with the 'Allow' header specifying what methods are available for the given URL
	self:set_allow_header("GET")

	self:output()
end

function TestHandler:patch(instance)

	local response = { }
	local extended = { }

	local pl = self:get_db():pipeline()

	pl:hset("FAKEPATCH:dummy1", "dummy3", 1)

	local errors, keys, replies = self:doPATCH({"dummy3"}, pl, 1000)

    for _i, err in pairs(errors) do
    	table.insert(extended, self:create_message(err.Registry, err.MessageId, err.RelatedProperties, err.MessageArgs))
    end
    for _i, to_key in pairs(keys) do
        local property_key = to_key
        local key_segments = property_key:split(":")
        local property_name = "#/" .. table.concat(key_segments, "/")
        table.insert(extended, self:create_message("SyncAgent", "PatchTimeout", property_name, {CONFIG.PATCH_TIMEOUT/1000, property_name}))
    end

print(turbo.log.stringify(extended))
	if #extended ~= 0 then
		response["@Message.ExtendedInfo"] = extended
	else
		response = {errors=errors, keys=keys, replies=replies}
	end
print(turbo.log.stringify(response, "response"))
	response = self:oem_extend(response, "patch.test.test-patch-instance")

	self:set_response(response)
	self:output()
end

return TestHandler