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
local NetworkAdapterInstanceHandler = class("NetworkAdapterInstanceHandler", RedfishHandler)

-- ATTENTION: These allowable values need to be filled in with the appropriate values
local ResetSettingsToDefault_allowable_vals = {}
function NetworkAdapterInstanceHandler:get(url_capture0, url_capture1)
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
		prefix .. ":Status:Health",
		prefix .. ":Manufacturer",
		prefix .. ":Model",
		prefix .. ":SKU",
		prefix .. ":SerialNumber",
		prefix .. ":PartNumber"
	})
	local zcard_response = yield(redis:zcard(prefix .. ":Controllers:SortedIDs"))
	pl:zrange(prefix .. ":Controllers:SortedIDs", 0, zcard_response - 1)
	local db_result = yield(pl:run())
	self:assert_resource(db_result)
	local general, Controllers = unpack(db_result)
	response["Id"] = general[1]
	response["Name"] = general[2]
	response["Description"] = general[3]
	response["Status"] = {}
	response["Status"]["State"] = general[4]
	response["Status"]["HealthRollup"] = general[5]
	response["Status"]["Health"] = general[6]
	response["Status"]["Oem"] = {}
	response["Manufacturer"] = general[7]
	response["Model"] = general[8]
	response["SKU"] = general[9]
	response["SerialNumber"] = general[10]
	response["PartNumber"] = general[11]
	response["Controllers"] = {}
	for _index, entry in pairs(Controllers) do
		local array_entry = {}
		array_entry["ControllerCapabilities"] = {}
		array_entry["ControllerCapabilities"]["DataCenterBridging"] = {}
		array_entry["ControllerCapabilities"]["VirtualizationOffload"] = {}
		array_entry["ControllerCapabilities"]["VirtualizationOffload"]["VirtualFunction"] = {}
		array_entry["ControllerCapabilities"]["VirtualizationOffload"]["SRIOV"] = {}
		array_entry["ControllerCapabilities"]["NPIV"] = {}

		array_entry["FirmwarePackageVersion"] = yield(redis:get(entry .. ":FirmwarePackageVersion"))
		array_entry["ControllerCapabilities"]["NetworkPortCount"] = yield(redis:get(entry .. ":ControllerCapabilities:NetworkPortCount"))
		array_entry["ControllerCapabilities"]["NetworkDeviceFunctionCount"] = yield(redis:get(entry .. ":ControllerCapabilities:NetworkDeviceFunctionCount"))
		array_entry["ControllerCapabilities"]["DataCenterBridging"]["Capable"] = yield(redis:get(entry .. ":ControllerCapabilities:DataCenterBridging:Capable"))
		array_entry["ControllerCapabilities"]["VirtualizationOffload"]["VirtualFunction"]["DeviceMaxCount"] = yield(redis:get(entry .. ":ControllerCapabilities:VirtualizationOffload:VirtualFunction:DeviceMaxCount"))
		array_entry["ControllerCapabilities"]["VirtualizationOffload"]["VirtualFunction"]["NetworkPortMaxCount"] = yield(redis:get(entry .. ":ControllerCapabilities:VirtualizationOffload:VirtualFunction:NetworkPortMaxCount"))
		array_entry["ControllerCapabilities"]["VirtualizationOffload"]["VirtualFunction"]["MinAssignmentGroupSize"] = yield(redis:get(entry .. ":ControllerCapabilities:VirtualizationOffload:VirtualFunction:MinAssignmentGroupSize"))
		array_entry["ControllerCapabilities"]["VirtualizationOffload"]["SRIOV"]["SRIOVVEPACapable"] = yield(redis:get(entry .. ":ControllerCapabilities:VirtualizationOffload:SRIOV:SRIOVVEPACapable"))
		array_entry["ControllerCapabilities"]["NPIV"]["MaxDeviceLogins"] = yield(redis:get(entry .. ":ControllerCapabilities:NPIV:MaxDeviceLogins"))
		array_entry["ControllerCapabilities"]["NPIV"]["MaxPortLogins"] = yield(redis:get(entry .. ":ControllerCapabilities:NPIV:MaxPortLogins"))
		table.insert(response["Controllers"], array_entry)
	end
	-- ATTENTION: The target and action parameter for this action may not be correct. Please double check them and make the appropraite changes.
	self:add_action({
		["#NetworkAdapter.ResetSettingsToDefault"] = {
			target = CONFIG.SERVICE_PREFIX .. table.concat(url_segments, "/") .. "/Actions/NetworkAdapter.ResetSettingsToDefault",
			["ResetSettingsToDefaultType@Redfish.AllowableValues"] = ResetSettingsToDefault_allowable_vals
		},
	})
	response["PCIeDevices"] = {["@odata.id"] = CONFIG.SERVICE_PREFIX .. "/" .. table.concat(url_segments, "/") .. "/PCIeDevices"}
	response["NetworkPorts"] = {["@odata.id"] = CONFIG.SERVICE_PREFIX .. "/" .. table.concat(url_segments, "/") .. "/NetworkPorts"}
	response["NetworkDeviceFunctions"] = {["@odata.id"] = CONFIG.SERVICE_PREFIX .. "/" .. table.concat(url_segments, "/") .. "/NetworkDeviceFunctions"}
	response = self:oem_extend(response, "query.networkadapter-instance")
	utils.remove_nils(response)
	-- Set the OData context and type for the response
	local keys = _.keys(response)
	if #keys < 13 then
		local select_list = turbo.util.join(",", keys)
		self:set_context(CONSTANTS.NETWORKADAPTER_CONTEXT .. "(" .. select_list .. ")")
	else
		self:set_context(CONSTANTS.NETWORKADAPTER_CONTEXT .. "(*)")
	end
	self:set_type(CONSTANTS.NETWORKADAPTER_TYPE)
	self:set_allow_header("GET,PATCH")
	self:set_response(response)
	self:output()
end

function NetworkAdapterInstanceHandler:patch(url_capture0, url_capture1)
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
		if type(request_data.Controllers) ~= "nil" then
			if type(request_data.Controllers) ~= "table" then
				local zcard_response = yield(redis:zcard(prefix .. ":Controllers:SortedIDs"))
				local Controllers = yield(redis:zrange(prefix .. ":Controllers:SortedIDs", 0, zcard_response - 1))
				for _index, entry in pairs(Controllers) do
					pl:del(entry .. ":FirmwarePackageVersion")
					pl:del(entry .. ":ControllerCapabilities:NetworkPortCount")
					pl:del(entry .. ":ControllerCapabilities:NetworkDeviceFunctionCount")
					pl:del(entry .. ":ControllerCapabilities:DataCenterBridging:Capable")
					pl:del(entry .. ":ControllerCapabilities:VirtualizationOffload:VirtualFunction:DeviceMaxCount")
					pl:del(entry .. ":ControllerCapabilities:VirtualizationOffload:VirtualFunction:NetworkPortMaxCount")
					pl:del(entry .. ":ControllerCapabilities:VirtualizationOffload:VirtualFunction:MinAssignmentGroupSize")
					pl:del(entry .. ":ControllerCapabilities:VirtualizationOffload:SRIOV:SRIOVVEPACapable")
					pl:del(entry .. ":ControllerCapabilities:NPIV:MaxDeviceLogins")
					pl:del(entry .. ":ControllerCapabilities:NPIV:MaxPortLogins")
				end
				for _index, entry in pairs(request_data.Controllers) do
					pl:set(prefix .. ":Controllers" .. tostring(_index) .. ":FirmwarePackageVersion", entry["FirmwarePackageVersion"])
					pl:zadd(prefix .. ":Controllers:SortedIDs", _index, prefix .. ":Controllers" .. tostring(_index))
					pl:set(prefix .. ":Controllers" .. tostring(_index) .. ":ControllerCapabilities:NetworkPortCount", entry["ControllerCapabilities"]["NetworkPortCount"])
					pl:zadd(prefix .. ":Controllers:SortedIDs", _index, prefix .. ":Controllers" .. tostring(_index))
					pl:set(prefix .. ":Controllers" .. tostring(_index) .. ":ControllerCapabilities:NetworkDeviceFunctionCount", entry["ControllerCapabilities"]["NetworkDeviceFunctionCount"])
					pl:zadd(prefix .. ":Controllers:SortedIDs", _index, prefix .. ":Controllers" .. tostring(_index))
					pl:set(prefix .. ":Controllers" .. tostring(_index) .. ":ControllerCapabilities:DataCenterBridging:Capable", entry["ControllerCapabilities"]["DataCenterBridging"]["Capable"])
					pl:zadd(prefix .. ":Controllers:SortedIDs", _index, prefix .. ":Controllers" .. tostring(_index))
					pl:set(prefix .. ":Controllers" .. tostring(_index) .. ":ControllerCapabilities:VirtualizationOffload:VirtualFunction:DeviceMaxCount", entry["ControllerCapabilities"]["VirtualizationOffload"]["VirtualFunction"]["DeviceMaxCount"])
					pl:zadd(prefix .. ":Controllers:SortedIDs", _index, prefix .. ":Controllers" .. tostring(_index))
					pl:set(prefix .. ":Controllers" .. tostring(_index) .. ":ControllerCapabilities:VirtualizationOffload:VirtualFunction:NetworkPortMaxCount", entry["ControllerCapabilities"]["VirtualizationOffload"]["VirtualFunction"]["NetworkPortMaxCount"])
					pl:zadd(prefix .. ":Controllers:SortedIDs", _index, prefix .. ":Controllers" .. tostring(_index))
					pl:set(prefix .. ":Controllers" .. tostring(_index) .. ":ControllerCapabilities:VirtualizationOffload:VirtualFunction:MinAssignmentGroupSize", entry["ControllerCapabilities"]["VirtualizationOffload"]["VirtualFunction"]["MinAssignmentGroupSize"])
					pl:zadd(prefix .. ":Controllers:SortedIDs", _index, prefix .. ":Controllers" .. tostring(_index))
					pl:set(prefix .. ":Controllers" .. tostring(_index) .. ":ControllerCapabilities:VirtualizationOffload:SRIOV:SRIOVVEPACapable", entry["ControllerCapabilities"]["VirtualizationOffload"]["SRIOV"]["SRIOVVEPACapable"])
					pl:zadd(prefix .. ":Controllers:SortedIDs", _index, prefix .. ":Controllers" .. tostring(_index))
					pl:set(prefix .. ":Controllers" .. tostring(_index) .. ":ControllerCapabilities:NPIV:MaxDeviceLogins", entry["ControllerCapabilities"]["NPIV"]["MaxDeviceLogins"])
					pl:zadd(prefix .. ":Controllers:SortedIDs", _index, prefix .. ":Controllers" .. tostring(_index))
					pl:set(prefix .. ":Controllers" .. tostring(_index) .. ":ControllerCapabilities:NPIV:MaxPortLogins", entry["ControllerCapabilities"]["NPIV"]["MaxPortLogins"])
					pl:zadd(prefix .. ":Controllers:SortedIDs", _index, prefix .. ":Controllers" .. tostring(_index))
				end
			end
			request_data.Controllers = nil
		end
		response = self:oem_extend(response, "patch.networkadapter-instance")
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
return NetworkAdapterInstanceHandler
