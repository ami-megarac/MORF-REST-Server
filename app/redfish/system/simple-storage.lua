-- Import required libraries
-- [See "redfish-handler.lua"](/redfish-handler.html)
local RedfishHandler = require("redfish-handler")
-- [See "constants.lua"](/constants.html)
local CONSTANTS = require("constants")
-- [See "utils.lua"](/utils.html)
local utils = require("utils")
-- [See "turbo library"](http://turbolua.org)
local turbo = require("turbo")
-- [See "underscore.lua"](https://mirven.github.io/underscore.lua/)
local _ = require("underscore")

local SystemSimpleStorageHandler = class("SystemSimpleStorageHandler", RedfishHandler)

local yield = coroutine.yield

-- Set the path names for system simple storage OEM extensions
local collection_oem_path = "system.system-simplestorage-collection"
local instance_oem_path = "system.system-simplestorage-instance"
SystemSimpleStorageHandler:set_all_oem_paths(collection_oem_path, instance_oem_path)

--Handles GET requests for System Simple Storage collection and instance
function SystemSimpleStorageHandler:get(id1, id2)

	local response = {}
	
	if id2 == nil then
		--GET Collection
		self:get_collection(response)
	else
		--GET instance
		self:get_instance(response)
	end

	self:set_response(response)

	-- GET requests must respond with the 'Allow' header specifying what methods are available for the given URL
	self:set_allow_header("GET")

	self:output()
end

-- Handles GET System Simple Storage collection
function SystemSimpleStorageHandler:get_collection(response)
	-- Before proceeding with the handler, we'll make sure the collection request is valid
	local collection_exists = self:parent_exists()
	self:assertTrue_404(collection_exists)

	local redis = self:get_db()
	local url_segments = self:get_url_segments();

	local collection, instance, secondary_collection = 
		url_segments[1], url_segments[2], url_segments[3];

	local prefix = "Redfish:" .. collection .. ":" .. instance .. ":SimpleStorage"

	self:set_scope("Redfish:" .. table.concat(url_segments, ":"))

	-- Creating response
	response["Name"] = "Simple Storage Collection"
	response["Description"] = "Collection of simple storage for this system"

	local odataIDs = utils.getODataIDArray(yield(redis:keys(prefix .. ":*:UefiDevicePath")), 1)

	response["Members@odata.count"] = #odataIDs
	response["Members"] = odataIDs

	response = self:oem_extend(response, "query." .. self:get_oem_collection_path())

	self:set_context(CONSTANTS.SIMPLE_STORAGE_COLLECTION_CONTEXT)
	self:set_type(CONSTANTS.SIMPLE_STORAGE_COLLECTION_TYPE)
end

-- Handles GET System Simple Storage instance
function SystemSimpleStorageHandler:get_instance(response)
	local redis = self:get_db()
	local url_segments = self:get_url_segments();

	local collection, instance, secondary_collection, id = 
		url_segments[1], url_segments[2], url_segments[3], url_segments[4];

	local prefix = "Redfish:" .. collection .. ":" .. instance .. ":SimpleStorage:" .. id

	self:set_scope("Redfish:"..table.concat(url_segments,':'))

	--Retrieving data from database
	local pl = redis:pipeline()
	pl:mget({
			prefix .. ":Name",
			prefix .. ":Description",
			prefix .. ":UefiDevicePath"
		})
	pl:hmget(prefix .. ":Status", "State", "Health", "HealthRollup")
	pl:keys(prefix .. ":*:Name")

    local db_result = yield(pl:run())

    -- Check that data was found in Redis, if not we throw a 404 NOT FOUND
    self:assert_resource(db_result)

	local general, status, devices = unpack(db_result)

	--Creating response using data from database
	response["Id"] = id
	response["Name"] = general[1]
	response["Description"] = general[2]
	response["UefiDevicePath"] = general[3]
	response["Status"] = {
		State = status[1],
		Health = status[2],
		HealthRollup = status[3]
	}

	local devices_response = {}
	local entry = {}
	for i=0, #devices-1 do
		entry = {}
		pl = redis:pipeline()
		pl:mget({
				prefix .. ":Devices:" .. i .. ":Name",
				prefix .. ":Devices:" .. i .. ":Manufacturer",
				prefix .. ":Devices:" .. i .. ":Model"
			})
		pl:hmget(prefix .. ":Devices:" .. i .. ":Status", "State", "Health")

		general, status = unpack(yield(pl:run()))
		entry["Name"] = general[1]
		entry["Manufacturer"] = general[2]
		entry["Model"] = general[3]
		entry["Status"] = {
			State = status[1],
			Health = status[2]
		}

		table.insert(devices_response, entry)
	end

	response["Devices"] = devices_response

	response = self:oem_extend(response, "query." .. self:get_oem_instance_path())

	utils.remove_nils(response)

	local keys = _.keys(response)
	if #keys < 6 then
		local select_list = turbo.util.join(",", keys)
		self:set_context(CONSTANTS.SIMPLE_STORAGE_INSTANCE_CONTEXT .. "(" .. select_list .. ")")
	else
		self:set_context(CONSTANTS.SIMPLE_STORAGE_INSTANCE_CONTEXT)
	end

	self:set_type(CONSTANTS.SIMPLE_STORAGE_TYPE)
end

return SystemSimpleStorageHandler