-- [See "redfish-handler.lua"](/redfish-handler.html)
local RedfishHandler = require("redfish-handler")
-- [See "config.lua"](/config.html)
local CONFIG = require("config")
-- [See "constants.lua"](/constants.html)
local CONSTANTS = require("constants")
-- [See "turboredis.lua"](https://github.com/enotodden/turboredis)
local db_utils = require("turboredis.util")
-- [See "utils.lua"](/utils.html)
local utils = require("utils")

local ServiceRootHandler = class("ServiceRootHandler", RedfishHandler)

local yield = coroutine.yield

local singleton_oem_path = "service-root"
ServiceRootHandler:set_oem_singleton_path(singleton_oem_path)

local turbo = require("turbo")
function ServiceRootHandler:get()

	self:set_scope("Redfish")

	-- Retrieve service root data from the database
	-- Note: ServiceRoot links are stored in redis db as a hash that should be configured at build time.
	-- db_init should be updated on a project-by-project basis with the correct services.
    local redis = self:get_db()
    local pl = redis:pipeline()
	
	pl:get("Redfish:UUID")
	pl:hgetall("Redfish:Services")
	pl:hgetall("Redfish:Services:Links")

	local db_result = yield(pl:run())

	local UUID, services_hash, links_hash = unpack(db_result)

	local services = db_utils.from_kvlist(services_hash)
	local links = db_utils.from_kvlist(links_hash)

	-- Add properties to the response body
	local response = {}

	response["Id"] = "RootService"
	response["Name"] = "Root Service"
	response["Description"] = "The service root for all Redfish requests on this host"
	response["RedfishVersion"] = CONFIG.REDFISH_VERSION
	response["UUID"] = UUID

	if type(services) == "table" then
		for service, odata_id in pairs(services) do

			response[service] = {}
			if odata_id ~= "" then
				response[service]["@odata.id"] = odata_id
			end

		end
	end

	if type(links) == "table" then

		response["Links"] = {}
		for resource, link in pairs(links) do
			if link ~= "" then
				response["Links"][resource] = {["@odata.id"] = link}
			end
		end

	end

	response = self:oem_extend(response, "query." .. self:get_oem_singleton_path())
	
	self:set_type(CONSTANTS.SERVICE_ROOT_TYPE)
	self:set_context(CONSTANTS.SERVICE_ROOT_CONTEXT)

	utils.remove_nils(response)

	self:set_response(response)

	-- GET requests must respond with the 'Allow' header specifying what methods are available for the given URL
	self:set_allow_header("GET")

	self:output()
end

return ServiceRootHandler