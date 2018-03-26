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
local SystemHandler = class("SystemHandler", RedfishHandler)
local yield = coroutine.yield
-- The 'property_access' table specifies read/write permission for all properties.
local property_access = require("property-access.ComputerSystem")["ComputerSystem"]
local boot_source = {"None", "Pxe", "Floppy", "Cd", "Usb", "Hdd", "BiosSetup", "Utilities", "Diags", "UefiShell", "UefiTarget","SDCard","UefiHttp","RemoteDrive"}
local led = {"Lit", "Blinking", "Off"}
local boot_source_enabled = {"Disabled", "Once", "Continuous"}
local boot_source_override_mode = {"Legacy", "UEFI"}

-- Set the path names for system OEM extensions
local collection_oem_path = "system.system-collection"
local instance_oem_path = "system.system-instance"
local action_oem_path = "system.system-instance-actions"
local link_oem_path = "system.system-instance-links"
SystemHandler:set_all_oem_paths(collection_oem_path, instance_oem_path, nil, action_oem_path, link_oem_path)

--Handles GET requests for System collection and instance
function SystemHandler:get(instance)
	local response = {}
	if instance == "/redfish/v1/Systems" then
		--GET collection
		self:get_collection(response)
	else
		--GET instance
		self:get_instance(response)
	end
	self:set_response(response)
	self:output()
end
-- Handles GET System collection
function SystemHandler:get_collection(response)
	-- Before proceeding with the handler, we'll make sure the collection request is valid
	local collection_exists = self:parent_exists()
	self:assertTrue_404(collection_exists)
	local redis = self:get_db()
	local url_segments = self:get_url_segments()
	local collection = url_segments[1]
	
	local prefix = "Redfish:" .. collection
	self:set_scope("Redfish:" .. table.concat(url_segments, ":"))
	-- Creating response
	response["Name"] = "Systems Collection"
	local odataIDs = utils.getODataIDArray(yield(redis:keys(prefix .. ":*:SystemType")), 1)
	response["Members@odata.count"] = #odataIDs
	response["Members"] = odataIDs

	response = self:oem_extend(response, "query." .. self:get_oem_collection_path())

	self:set_context(CONSTANTS.SYSTEMS_COLLECTION_CONTEXT)
	self:set_type(CONSTANTS.SYSTEM_COLLECTION_TYPE)
	-- GET requests must respond with the 'Allow' header specifying what methods are available for the given URL
	self:set_allow_header("GET")
end
local allowed_reset = {"On", "ForceOff", "ForceRestart", "GracefulShutdown"}
-- Handles GET System instance
function SystemHandler:get_instance(response)
	local redis = self:get_db()
	local url_segments = self:get_url_segments()
	local prefix = "Redfish:" .. table.concat(url_segments, ":")
	self:set_scope("Redfish:" .. table.concat(url_segments, ":"))
	local pl = redis:pipeline()
	pl:mget({
			prefix .. ":Id",
			prefix .. ":Name",
			prefix .. ":Description",
			prefix .. ":SystemType",
			prefix .. ":AssetTag",
			prefix .. ":Manufacturer",
			prefix .. ":Model",
			prefix .. ":SKU",
			prefix .. ":SerialNumber",
			prefix .. ":PartNumber",
			prefix .. ":UUID",
			prefix .. ":HostName",
			prefix .. ":IndicatorLED",
			prefix .. ":PowerState",
			prefix .. ":Boot:BootSourceOverrideTarget",
			prefix .. ":Boot:BootSourceOverrideEnabled",
			prefix .. ":Boot:UefiTargetBootSourceOverride",
			prefix .. ":Boot:BootSourceOverrideMode",
			prefix .. ":BiosVersion",
			prefix .. ":ProcessorSummary:Count",
			prefix .. ":ProcessorSummary:Model",
			prefix .. ":ProcessorSummary:Status:State",
			prefix .. ":ProcessorSummary:Status:HealthRollup",
			prefix .. ":ProcessorSummary:Status:Health",
			prefix .. ":MemorySummary:TotalSystemMemoryGiB",
			prefix .. ":MemorySummary:Status:State",
			prefix .. ":MemorySummary:Status:HealthRollup",
			prefix .. ":MemorySummary:Status:Health",
			prefix .. ":MemorySummary:MemoryMirroring",
			prefix .. ":Status:State",
			prefix .. ":Status:HealthRollup",
			prefix .. ":Status:Health"
	})
	pl:smembers(prefix .. ":Links:Chassis")
	pl:smembers(prefix .. ":Links:ManagedBy")
	pl:smembers(prefix .. ":Links:PoweredBy")
	pl:smembers(prefix .. ":Links:CooledBy")
	pl:smembers(prefix .. ":Links:Endpoints")
	pl:smembers(prefix .. ":PCIeDevices")
	pl:smembers(prefix .. ":PCIeFunctions")
	local zcard_response = yield(redis:zcard(prefix .. ":TrustedModules:SortedIds"))
	pl:zrange(prefix .. ":TrustedModules:SortedIds", 0, zcard_response - 1)
	local zcard_response = yield(redis:zcard(prefix .. ":HostingRoles:SortedIds"))
	pl:zrange(prefix .. ":HostingRoles:SortedIds", 0, zcard_response - 1)
	local db_result = yield(pl:run())
	self:assert_resource(db_result)
	local general, Links_Chassis, Links_ManagedBy, Links_PoweredBy, Links_CooledBy, Links_Endpoints, PCIeDevices, PCIeFunctions, TrustedModules, HostingRoles = unpack(db_result)
	response["Id"] = url_segments[#url_segments]
	response["Name"] = general[2]
	response["Description"] = general[3]
	response["SystemType"] = general[4]
	response["AssetTag"] = general[5]
	response["Manufacturer"] = general[6]
	response["Model"] = general[7]
	response["SKU"] = general[8]
	response["SerialNumber"] = general[9]
	response["PartNumber"] = general[10]
	response["UUID"] = general[11]
	response["HostName"] = general[12]
	response["IndicatorLED"] = general[13]
	response["PowerState"] = general[14]
	response["Boot"] = {}
	response["Boot"]["BootSourceOverrideTarget"] = general[15]
	response["Boot"]["BootSourceOverrideEnabled"] = general[16]
	response["Boot"]["UefiTargetBootSourceOverride"] = general[17]
	response["Boot"]["BootSourceOverrideMode"] = general[18]
	response["BiosVersion"] = general[19]
	response["ProcessorSummary"] = {}
	response["ProcessorSummary"]["Count"] = tonumber(general[20])
	response["ProcessorSummary"]["Model"] = general[21]
	response["ProcessorSummary"]["Status"] = {}
	response["ProcessorSummary"]["Status"]["State"] = general[22]
	response["ProcessorSummary"]["Status"]["HealthRollup"] = general[23]
	response["ProcessorSummary"]["Status"]["Health"] = general[24]
	response["ProcessorSummary"]["Status"]["Oem"] = {}
	response["MemorySummary"] = {}
	response["MemorySummary"]["TotalSystemMemoryGiB"] = tonumber(general[25])
	response["MemorySummary"]["Status"] = {}
	response["MemorySummary"]["Status"]["State"] = general[26]
	response["MemorySummary"]["Status"]["HealthRollup"] = general[27]
	response["MemorySummary"]["Status"]["Health"] = general[28]
	response["MemorySummary"]["Status"]["Oem"] = {}
	response["MemorySummary"]["MemoryMirroring"] = general[29]
	response["Status"] = {}
	response["Status"]["State"] = general[30]
	response["Status"]["HealthRollup"] = general[31]
	response["Status"]["Health"] = general[32]
	response["Status"]["Oem"] = {}
	response["Links"] = {}
	response["Links"]["Oem"] = {}
	response["Links"]["Chassis"] = utils.getODataIDArray(Links_Chassis)
	response["Links"]["ManagedBy"] = utils.getODataIDArray(Links_ManagedBy)
	response["Links"]["PoweredBy"] = utils.getODataIDArray(Links_PoweredBy)
	response["Links"]["CooledBy"] = utils.getODataIDArray(Links_CooledBy)
	response["Links"]["Endpoints"] = utils.getODataIDArray(Links_Endpoints)
	response["PCIeDevices"] = utils.getODataIDArray(PCIeDevices, 1)
	response["PCIeFunctions"] = utils.getODataIDArray(PCIeFunctions, 1)
	response["Processors"] = {["@odata.id"] = CONFIG.SERVICE_PREFIX .. "/" .. table.concat(url_segments, "/") .. "/Processors"}
	response["EthernetInterfaces"] = {["@odata.id"] = CONFIG.SERVICE_PREFIX ..  "/" ..  table.concat(url_segments, "/") .. "/EthernetInterfaces"}
	response["SimpleStorage"] = {["@odata.id"] = CONFIG.SERVICE_PREFIX ..  "/" .. table.concat(url_segments, "/") .. "/SimpleStorage"}
	response["LogServices"] = {["@odata.id"] = CONFIG.SERVICE_PREFIX ..  "/" .. table.concat(url_segments, "/") .. "/LogServices"}
	response["SecureBoot"] = {["@odata.id"] = CONFIG.SERVICE_PREFIX ..  "/" .. table.concat(url_segments, "/") .. "/SecureBoot"}
	if posix.stat(CONFIG.BIOS_CURRENT_PATH) then
		response["Bios"] = {["@odata.id"] = CONFIG.SERVICE_PREFIX ..  "/" .. table.concat(url_segments, "/") .. "/Bios"}
	end
	response["Memory"] = {["@odata.id"] = CONFIG.SERVICE_PREFIX ..  "/" .. table.concat(url_segments, "/") .. "/Memory"}
	response["Storage"] = {["@odata.id"] = CONFIG.SERVICE_PREFIX ..  "/" .. table.concat(url_segments, "/") .. "/Storage"}
	response["NetworkInterfaces"] = {["@odata.id"] = CONFIG.SERVICE_PREFIX ..  "/" .. table.concat(url_segments, "/") .. "/NetworkInterfaces"}
	response["HostedServices"] = {}
	response["HostedServices"]["Oem"] = {}
	--StorageServices should be displayed only on special condition. So removed listing StorgeServices under System/Self.
	--response["HostedServices"]["StorageServices"] = {["@odata.id"] = CONFIG.SERVICE_PREFIX ..  "/" .. table.concat(url_segments, "/") .. "/StorageServices"}
	response["TrustedModules"] = {}
	for _index, entry in pairs(TrustedModules) do
		local array_entry = {}
		array_entry["Status"] = {}
		array_entry["FirmwareVersion"] = yield(redis:get(entry .. ":FirmwareVersion"))
		array_entry["InterfaceType"] = yield(redis:get(entry .. ":InterfaceType"))
		array_entry["Status"]["State"] = yield(redis:get(entry .. ":Status:State"))
		array_entry["Status"]["HealthRollup"] = yield(redis:get(entry .. ":Status:HealthRollup"))
		array_entry["Status"]["Health"] = yield(redis:get(entry .. ":Status:Health"))
		array_entry["FirmwareVersion2"] = yield(redis:get(entry .. ":FirmwareVersion2"))
		array_entry["InterfaceTypeSelection"] = yield(redis:get(entry .. ":InterfaceTypeSelection"))
		table.insert(response["TrustedModules"], array_entry)
	end
	response["HostingRoles"] = {}
	for _index, entry in pairs(HostingRoles) do
		local array_entry = {}
		table.insert(response["HostingRoles"], yield(redis:get(entry)))
	end
    
    if response["Boot"]["BootSourceOverrideTarget"] ~= nil then
		response["Boot"]["BootSourceOverrideTarget@Redfish.AllowableValues"] = boot_source
	end
	if response["Boot"]["BootSourceOverrideEnabled"] ~= nil then
		response["Boot"]["BootSourceOverrideEnabled@Redfish.AllowableValues"] = boot_source_enabled
	end
	if response["Boot"]["BootSourceOverrideMode"] ~= nil then
		response["Boot"]["BootSourceOverrideMode@Redfish.AllowableValues"] = boot_source_override_mode
	end

	
	-- Adding System Reset action
	self:add_action({
			["#ComputerSystem.Reset"] = {
				target = CONFIG.SERVICE_PREFIX ..  "/" .. table.concat(url_segments, "/") .. "/Actions/ComputerSystem.Reset",
				["ResetType@Redfish.AllowableValues"] = allowed_reset
			}
		})



	response["Links"] = self:oem_extend(response["Links"], "query." .. self:get_oem_instance_link_path())
	response = self:oem_extend(response, "query." .. self:get_oem_instance_path())

	utils.remove_nils(response)
	--Set the OData context and type for the response
	local keys = _.keys(response)
	if #keys < 14 then
		local select_list = turbo.util.join(",", keys)
		self:set_context(CONSTANTS.SYSTEMS_INSTANCE_CONTEXT .. "(" .. select_list .. ")")
	else
		self:set_context(CONSTANTS.SYSTEMS_INSTANCE_CONTEXT .. "(*)")
	end
	self:set_type(CONSTANTS.SYSTEM_TYPE)
	self:set_allow_header("GET,PATCH")
end
--Handles PATCH request for System
function SystemHandler:patch()
	local url_segments = self:get_url_segments()
	local collection, instance = url_segments[1], url_segments[2]
	local response = {}
	local extended = {}
	
	--Throwing error if request is to collection
	if instance == nil then
		-- Allow an OEM patch handler for system collections, if none exists, return with the normal 405 response
		self:set_header("Allow", "GET")
		self:set_status(405)

		response = self:oem_extend(response, "patch." .. self:get_oem_collection_path())

		if self:get_status() == 405 then
			self:error_method_not_allowed()
		end
	else
		-- Allow the OEM patch handlers for system instances to have the first chance to handle the request body
		response = self:oem_extend(response, "patch." .. self:get_oem_instance_path())
	end
	--Making sure current user has permission to modify system settings
	if self:can_user_do("ConfigureComponents") == true then
		local redis = self:get_db()
		-- Checking if system exists before PATCHing
		local sys_exists = yield(redis:exists("Redfish:" .. collection .. ":" .. instance .. ":SystemType"))
		if sys_exists ~= 1  then
			self:error_resource_missing_at_uri()
		else
			local request_data = turbo.escape.json_decode(self:get_request().body)
		 
			--Call function to capture the null property from the request body and to frame corresponding error message
      extended = RedfishHandler:validatePatchRequest(self:get_request().body, property_access, extended)
      
			local keys_to_watch = {}
			self:set_scope("Redfish:" .. table.concat(url_segments, ":"))
			local pl = redis:pipeline()
			local prefix = "Redfish:" .. collection .. ":" .. instance
			
			local successful_sets = {}
			--Validating AssetTag property and adding error if property is incorrect
			if request_data.AssetTag ~= nil then
				if type(request_data.AssetTag) ~= "string" then
					table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/AssetTag"}, {tostring(request_data.AssetTag).."("..type(request_data.AssetTag)..")", "AssetTag"}))
				else
					pl:set(prefix .. ":AssetTag", request_data.AssetTag)
					table.insert(successful_sets, "AssetTag")
				end
				request_data.AssetTag = nil
			end
			--end
			--Validating HostName property and adding error if property is incorrect
			if request_data.HostName ~= nil then
				if type(request_data.HostName) ~= "string" then
					table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/HostName"}, {tostring(request_data.HostName).."("..type(request_data.HostName)..")", "HostName"}))
				else
					pl:set(prefix .. ":HostName", request_data.HostName)
					table.insert(successful_sets, "HostName")
				end
				request_data.HostName = nil
			end
			--Validating IndicatorLED property and adding error if property is incorrect
			if request_data.IndicatorLED ~= nil then
				if turbo.util.is_in(request_data.IndicatorLED, led) == nil then
					table.insert(extended, self:create_message("Base", "PropertyValueNotInList", {"#/IndicatorLED"}, {request_data.IndicatorLED, "IndicatorLED"}))
				else
					--IndicatorLED is valid and will be added to database
					pl:set("PATCH:" .. prefix .. ":IndicatorLED", request_data.IndicatorLED)
					table.insert(successful_sets, "IndicatorLED")
					table.insert(keys_to_watch, prefix..":IndicatorLED")
				end
				request_data.IndicatorLED = nil
			end
			--Validating BootSourceOverrideTarget property and adding error if property is incorrect
			if request_data.Boot and request_data.Boot.BootSourceOverrideTarget ~= nil then
				if turbo.util.is_in(request_data.Boot.BootSourceOverrideTarget, boot_source) == nil then
					table.insert(extended, self:create_message("Base", "PropertyValueNotInList", {"#/Boot/BootSourceOverrideTarget"}, {request_data.Boot.BootSourceOverrideTarget, "BootSourceOverrideTarget"}))
				else
					--BootSourceOverrideTarget is valid and will be added to database
					pl:set("PATCH:"..prefix .. ":Boot:BootSourceOverrideTarget", request_data.Boot.BootSourceOverrideTarget)
					table.insert(keys_to_watch, prefix .. ":Boot:BootSourceOverrideTarget")
					table.insert(successful_sets, "Boot:BootSourceOverrideTarget")
				end
				request_data.Boot.BootSourceOverrideTarget = nil 
			end
			--Validating BootSourceOverrideEnabled property and adding error if property is incorrect
			if request_data.Boot and request_data.Boot.BootSourceOverrideEnabled ~= nil then
				if turbo.util.is_in(request_data.Boot.BootSourceOverrideEnabled, boot_source_enabled) == nil then
					table.insert(extended, self:create_message("Base", "PropertyValueNotInList", {"#/Boot/BootSourceOverrideEnabled"}, {request_data.Boot.BootSourceOverrideEnabled, "BootSourceOverrideEnabled"}))
				else
					--BootSourceOverrideEnabled is valid and will be added to database
					pl:set(prefix .. ":Boot:BootSourceOverrideEnabled", request_data.Boot.BootSourceOverrideEnabled)
					table.insert(successful_sets, "Boot:BootSourceOverrideEnabled")
				end
				request_data.Boot.BootSourceOverrideEnabled = nil
			end
			--Validating UefiTargetBootSourceOverride property and adding error if property is incorrect
			if request_data.Boot and request_data.Boot.UefiTargetBootSourceOverride ~= nil then
				if type(request_data.Boot.UefiTargetBootSourceOverride) ~= "string" then
					table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/UefiTargetBootSourceOverride"}, {tostring(request_data.Boot.UefiTargetBootSourceOverride).."("..type(request_data.Boot.UefiTargetBootSourceOverride)..")", "UefiTargetBootSourceOverride"}))
				else
					pl:set(prefix .. ":Boot:UefiTargetBootSourceOverride", request_data.Boot.UefiTargetBootSourceOverride)
					table.insert(successful_sets, "Boot:UefiTargetBootSourceOverride")
					request_data.Boot.UefiTargetBootSourceOverride = nil
				end
			end

			--Validating BootSourceOverrideMode property and adding error if property is incorrect
			if request_data.Boot and request_data.Boot.BootSourceOverrideMode ~= nil then
				if turbo.util.is_in(request_data.Boot.BootSourceOverrideMode, boot_source_override_mode) == nil then
					table.insert(extended, self:create_message("Base", "PropertyValueNotInList", {"#/Boot/BootSourceOverrideMode"}, {request_data.Boot.BootSourceOverrideMode, "BootSourceOverrideMode"}))
				else
					--BootSourceOverrideMode is valid and will be added to database
					pl:set(prefix .. ":Boot:BootSourceOverrideMode", request_data.Boot.BootSourceOverrideMode)
					table.insert(successful_sets, "Boot:BootSourceOverrideMode")
				end
				request_data.Boot.BootSourceOverrideMode = nil
			end
			
			-- Once all the properties inside boot attribute are nullified, boot attribute needs to be nullified too.
			-- Otherwise it remains in the request body and is treated as a read only property.
			if request_data.Boot and utils.table_len(request_data.Boot) == 0 then
				request_data.Boot = nil
			end
			
			--Validating BiosVersion property and adding error if property is incorrect
			if request_data.BiosVersion ~= nil then
				if type(request_data.BiosVersion) ~= "string" then
					table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/BiosVersion"}, {tostring(request_data.BiosVersion).."("..type(request_data.BiosVersion)..")", "BiosVersion"}))
				else
					pl:set(prefix .. ":BiosVersion", request_data.BiosVersion)
					table.insert(successful_sets, "BiosVersion")
				end
				request_data.BiosVersion = nil
			end
			if #pl.pending_commands > 0 then
				
				-- doPATCH will block until it sees that the keys we are PATCHing have been changed, or receives an error response about why the PATCH failed, or until it times out
				-- doPATCH returns a table of any error messages received, and, if a timeout occurs, any keys that had yet to be modified when the timeout happened
				local patch_errors, timedout_keys, result = self:doPATCH(keys_to_watch, pl, CONFIG.PATCH_TIMEOUT)
				for _i, err in pairs(patch_errors) do
					table.insert(extended, self:create_message(err.Registry, err.MessageId, err.RelatedProperties, err.MessageArgs))
				end
				for _i, to_key in pairs(timedout_keys) do
					local property_key = to_key:split("Systems:[^:]*:", nil, true)[2]
					local key_segments = property_key:split(":")
					local property_name = "#/" .. table.concat(key_segments, "/")
					table.insert(extended, self:create_message("SyncAgent", "PatchTimeout", property_name, {CONFIG.PATCH_TIMEOUT/1000, property_name}))
				end
				self:add_audit_log_entry(self:create_message("Security", "ResourceModified", nil, {turbo.util.join(", ", successful_sets), self:get_request().path}))
			 end
			local readonly_body
			local writable_body
			local read_only = {}
			readonly_body, writable_body = utils.readonlyCheck(request_data, property_access)
			
			-- If the user attempts to PATCH read-only properties, adding it to table with the proper error messages.
			if readonly_body then
				for property, value in pairs(readonly_body) do
					if type(value) == "table" then
						for prop2, val2 in pairs(value) do
							--table.insert(extended, self:create_message("Base", "PropertyNotWritable", "#/"..property.."/"..prop2, tostring(property.."/"..prop2)))
							table.insert(read_only, property .. "." .. prop2)
						end
					else
						--table.insert(extended, self:create_message("Base", "PropertyNotWritable", "#/"..property, tostring(property)))
						table.insert(read_only, property)
					end
				end
			end
			
			--Adding read-only properties to extended table
			if #read_only ~= 0 then
				local values = _.values(read_only)
				for k, v in pairs(values) do
					table.insert(extended, self:create_message("Base", "PropertyNotWritable", "#/" .. v, v))
				end
			end
			
			--Removing the read-only properties from request_data
			for k, v in pairs(read_only) do
				request_data[v] = nil
			end
			
			--Checking for unknown properties if any
			local leftover_fields = utils.table_len(request_data)
			if leftover_fields ~= 0 then
				local keys = _.keys(request_data)
				for k, v in pairs(keys) do
					table.insert(extended, self:create_message("Base", "PropertyUnknown", "#/" .. v, v))
				end
			end
			
			--Checking if there were errors and adding them to the response if there are
			if #extended ~= 0 then
				self:add_error_body(response,400,unpack(extended))
			else
				self:update_lastmodified(prefix, os.time())
				self:set_status(204)
			end
			--self:get_instance(response)
		end
	else
		self:error_insufficient_privilege()
	end
	
	self:set_response(response)
	self:output()
end
return SystemHandler
