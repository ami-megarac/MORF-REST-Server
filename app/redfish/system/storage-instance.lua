-- Import required libraries
-- [See "redfish-handler.lua"](/redfish-handler.html)
local RedfishHandler = require("redfish-handler")
-- [See "constants.lua"](/constants.html)
local CONSTANTS = require("constants")
-- [See "config.lua"](/config.html)
local CONFIG = require("config")
-- [See "utils.lua"](/utils.html)
local utils = require("utils")
-- [See "turboredis.lua"](https://github.com/enotodden/turboredis)
local db_utils = require("turboredis.util")
-- [See "turbo library"](http://turbolua.org)
local turbo = require("turbo")
-- [See "underscore.lua"](https://mirven.github.io/underscore.lua/)
local _ = require("underscore")
local yield = coroutine.yield
local StorageInstanceHandler = class("StorageInstanceHandler", RedfishHandler)

-- ATTENTION: These allowable values need to be filled in with the appropriate values
local SetEncryptionKey_allowable_vals = {}
function StorageInstanceHandler:get(url_capture0, url_capture1)
	local response = {}
	local redis = self:get_db()
	local url_segments = self:get_url_segments()
	local prefix = "Redfish:" .. table.concat(url_segments, ":")
	self:set_scope(prefix)
	local pl = redis:pipeline()
	pl:mget({
		prefix .. ":Id",
		prefix .. ":Name",
		prefix .. ":Description",
		prefix .. ":Status:State",
		prefix .. ":Status:HealthRollup",
		prefix .. ":Status:Health"
	})
	pl:smembers(prefix .. ":Links:Enclosures")
	local zcard_response = yield(redis:zcard(prefix .. ":StorageControllers:SortedIDs"))
	pl:zrange(prefix .. ":StorageControllers:SortedIDs", 0, zcard_response - 1)
	pl:smembers(prefix .. ":Drives")

	local zcard_redundancy_response = yield(redis:zcard(prefix .. ":Redundancy:SortedIDs"))
	pl:zrange(prefix .. ":Redundancy:SortedIDs", 0, zcard_redundancy_response - 1)

	local db_result = yield(pl:run())
	self:assert_resource(db_result)
	local general, Links_Enclosures, StorageControllers, Drives, Redundancy = unpack(db_result)
	response["Id"] = general[1]
	response["Name"] = general[2]
	response["Description"] = general[3]
	response["Links"] = {}
	response["Links"]["Oem"] = {}
	response["Links"]["Enclosures"] = utils.getODataIDArray(Links_Enclosures)
	-- ATTENTION: The target and action parameter for this action may not be correct. Please double check them and make the appropraite changes.
	self:add_action({
		["#Storage.SetEncryptionKey"] = {
			target = CONFIG.SERVICE_PREFIX .. "/" .. table.concat(url_segments, "/") .. "/Actions/Storage.SetEncryptionKey",
			["SetEncryptionKeyType@Redfish.AllowableValues"] = SetEncryptionKey_allowable_vals
		},
	})
	response["Status"] = {}
	response["Status"]["State"] = general[4]
	response["Status"]["HealthRollup"] = general[5]
	response["Status"]["Health"] = general[6]
	response["Status"]["Oem"] = {}
	response["StorageControllers"] = {}
	response["Redundancy"] = {}
	
	for _index, entry in pairs(StorageControllers) do
		local array_entry = {}
		local storage_controllers_identifiers = {}
		array_entry["Status"] = {}
		array_entry["SupportedControllerProtocols"] = {}
		array_entry["Identifiers"] = {}
		array_entry["Links"] = {}
		array_entry["@odata.id"] = utils.getODataID(yield(redis:get(entry .. ":ref")))
		array_entry["MemberId"] = yield(redis:get(entry .. ":MemberId"))
		array_entry["Name"] = yield(redis:get(entry .. ":Name"))
		array_entry["Status"]["State"] = yield(redis:get(entry .. ":Status:State"))
		array_entry["Status"]["HealthRollup"] = yield(redis:get(entry .. ":Status:HealthRollup"))
		array_entry["Status"]["Health"] = yield(redis:get(entry .. ":Status:Health"))
		array_entry["SpeedGbps"] = yield(redis:get(entry .. ":SpeedGbps"))
		array_entry["FirmwareVersion"] = yield(redis:get(entry .. ":FirmwareVersion"))
		array_entry["Manufacturer"] = yield(redis:get(entry .. ":Manufacturer"))
		array_entry["Model"] = yield(redis:get(entry .. ":Model"))
		array_entry["SKU"] = yield(redis:get(entry .. ":SKU"))
		array_entry["SerialNumber"] = yield(redis:get(entry .. ":SerialNumber"))
		array_entry["PartNumber"] = yield(redis:get(entry .. ":PartNumber"))
		array_entry["AssetTag"] = yield(redis:get(entry .. ":AssetTag"))
		array_entry["UEFIDevicePath"] = yield(redis:get(entry .. ":UEFIDevicePath"))

		local identifiers = yield(redis:hgetall(entry .. ":Identifiers:"))
		if identifiers[1] then
			array_entry["Identifiers"] = utils.convertHashListToArray(db_utils.from_kvlist(identifiers))
		end
		local odataIDs = utils.getODataIDArray(yield(redis:keys(entry .. ":Links:Endpoints:*:ref")), 1)
		array_entry["Links"]["@odata.count"] = #odataIDs
		array_entry["Links"]["@odata.navifationLink"] = odataIDs
		--[[ Require Endpoint information for Redis DB Key
		array_entry["Links"]["Enpoints"] = 
		]]--
		array_entry["SupportedControllerProtocols"] = yield(redis:smembers(entry .. ":SupportedControllerProtocols"))
		array_entry["SupportedDeviceProtocols"] = yield(redis:smembers(entry .. ":SupportedDeviceProtocols"))
		table.insert(response["StorageControllers"], array_entry)
	end
	
	for _index, entry in pairs(Redundancy) do
		local array_entry = {}
		array_entry["Status"] = {}
		array_entry["RedundancySet"] = {}

		array_entry["@odata.id"] = utils.getODataID(yield(redis:get(entry .. ":ref")))
		array_entry["MemberId"] = yield(redis:get(entry .. ":MemberId"))
		array_entry["Name"] = yield(redis:get(entry .. ":Name"))
		array_entry["Mode"] = yield(redis:get(entry .. ":Mode"))
		array_entry["MaxNumSupported"] = yield(redis:get(entry .. ":MaxNumSupported"))
		array_entry["MinNumNeeded"] = yield(redis:get(entry .. ":MinNumNeeded"))		
		array_entry["Status"]["State"] = yield(redis:get(entry .. ":Status:State"))
		array_entry["Status"]["HealthRollup"] = yield(redis:get(entry .. ":Status:HealthRollup"))
		array_entry["Status"]["Health"] = yield(redis:get(entry .. ":Status:Health"))
		array_entry["RedundancySet"] = utils.getODataIDArray(yield(redis:smembers(prefix .. ":Redundancy")))
		array_entry["RedundancyEnabled"] = yield(redis:get(entry .. ":RedundancyEnabled"))
		table.insert(response["Redundancy"], array_entry)
	end

	response["Drives"] = utils.getODataIDArray(Drives)
	response["Volumes"] = {["@odata.id"] = CONFIG.SERVICE_PREFIX .. "/" .. table.concat(url_segments, "/") .. "/Volumes"}

	response = self:oem_extend(response, "query.storage-instance")
	utils.remove_nils(response)
	-- Set the OData context and type for the response
	local keys = _.keys(response)
	if #keys < 10 then
		local select_list = turbo.util.join(",", keys)
		self:set_context(CONSTANTS.STORAGE_INSTANCE_CONTEXT .. "(" .. select_list .. ")")
	else
		self:set_context(CONSTANTS.STORAGE_INSTANCE_CONTEXT .. "(*)")
	end

	self:set_type(CONSTANTS.STORAGE_TYPE)
	self:set_allow_header("GET")
	self:set_response(response)
	self:output()
end

function StorageInstanceHandler:patch(url_capture0, url_capture1)
	local response = {}
	local url_segments = self:get_url_segments()
	if self:can_user_do("ConfigureComponents") == true then
		local redis = self:get_db()
		local successful_sets = {}
		local request_data = turbo.escape.json_decode(self:get_request().body)
		local prefix = "Redfish:" .. table.concat(url_segments, ":")
		self:set_scope(prefix)
		local pl = redis:pipeline()
		local extended = {}
		if request_data.Redundancy ~= nil then
			if type(request_data.Redundancy) == "table" then
				local zcard_response = yield(redis:zcard(prefix .. ":Redundancy:SortedIDs"))
				local Redundancy = yield(redis:zrange(prefix .. ":Redundancy:SortedIDs", 0, zcard_response - 1))
				local redundancy_allowed = {"MemberId", "Mode", "MaxNumSupported", "MinNumNeeded", "RedundancyEnabled"}

				for redundancy_index, redundancy in pairs(request_data.Redundancy) do
					-- Traverse array elements
					for _index, entry in pairs(redundancy) do
						-- Set key and value for Redundancy
						local redundancy_redis_key = prefix .. ":Redundancy:" .. tostring(redundancy_index-1) .. ":" .. tostring(_index)

							if type(entry) == "table" then
								print("Inside Status")
								print(redundancy_redis_key)
								for status_index, status_entry in pairs(entry) do
									if status_index == "State" or  status_index == "Health" 
										or status_index == "HealthRollup" then
										pl:del(redundancy_redis_key .. ":" .. status_index)
										pl:set(redundancy_redis_key .. ":" .. status_index, tostring(status_entry))
										pl:zadd(prefix .. ":Redundancy:SortedIDs", _index, redundancy_redis_key .. status_index)
									end
								end
--								pl:set(prefix .. ":Redundancy" .. tostring(_index) .. ":Status:State", entry["Status"]["State"])
							else
								if _.any(redundancy_allowed, function(i) return i == _index end) then
									print("Patch")
									pl:del(redundancy_redis_key)
									pl:set(redundancy_redis_key, tostring(entry))
									pl:zadd(prefix .. ":Redundancy:SortedIDs", _index, redundancy_redis_key)
								end
							end
					end
				end

			end
			request_data.Redundancy = nil
		end
		response = self:oem_extend(response, "patch.storage-instance")
		if #pl.pending_commands > 0 then
			self:update_lastmodified(prefix, os.time(), pl)
			local result = yield(pl:run())
		end
		local leftover_fields = utils.table_len(request_data)
		if leftover_fields ~= 0 then
			local keys = _.keys(request_data)
			table.insert(extended, self:create_message("Base", "PropertyNotWritable", keys, turbo.util.join(",", keys)))
		end
		if #extended ~= 0 then
			self:add_error_body(response,400,extended)
		else
			self:set_status(204)
		end
		self:set_response(response)
		self:output()
	else
		self:error_insufficient_privilege()
	end
end
return StorageInstanceHandler
