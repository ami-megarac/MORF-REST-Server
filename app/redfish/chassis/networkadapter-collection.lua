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
local yield = coroutine.yield
local NetworkAdapterCollectionHandler = class("NetworkAdapterCollectionHandler", RedfishHandler)

function NetworkAdapterCollectionHandler:get()
	local response = {}
	local collection_exists = self:parent_exists()
	self:assertTrue_404(collection_exists)
	local redis = self:get_db()
	local url_segments = self:get_url_segments()
	local prefix = "Redfish:" .. table.concat(url_segments, ":")
	response["Name"] = "NetworkAdapter Collection"
	local all_instance_keys = yield(redis:keys(prefix .. ":*:Id"))
	local instance_keys = {}

	for _index, key in pairs(all_instance_keys) do
		if key:match(prefix .. ":[^:]*:Id") then
			table.insert(instance_keys, key)
		end
	end
	local odataIDs = utils.getODataIDArray(instance_keys, 1)
	response["Members@odata.count"] = #odataIDs
	response["Members"] = odataIDs
	response = self:oem_extend(response, "query.networkadapter-collection")
	self:set_context("NetworkAdapterCollection.NetworkAdapterCollection")
	self:set_type(CONSTANTS.NETWORKADAPTER_COLLECTION_TYPE)
	self:set_allow_header("GET")
	self:set_response(response)
	self:output()
end

return NetworkAdapterCollectionHandler
