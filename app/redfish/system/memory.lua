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
local CONFIG = require("config")
-- [See "utils.lua"](/utils.html)
local utils = require("utils")
-- [See "turbo library"](http://turbolua.org)
local turbo = require("turbo")
-- [See "underscore.lua"](https://mirven.github.io/underscore.lua/)
local _ = require("underscore")
local SystemMemoryHandler = class("SystemMemoryHandler", RedfishHandler)
local yield = coroutine.yield
-- Set the path names for system OEM extensions
local collection_oem_path = "system.system-memory-collection"
local action_oem_path = "system.system-memory-instance-actions"
local instance_oem_path = "system.system-memory-instance"
SystemMemoryHandler:set_all_oem_paths(collection_oem_path, instance_oem_path, nil, action_oem_path)
--Handles GET requests for System Memory collection and instance
function SystemMemoryHandler:get(id1, id2)
	local response = {}
	
	if id2 == nil then
		--GET collection
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
-- Handles GET System Memory collection
function SystemMemoryHandler:get_collection(response)
	-- Before proceeding with the handler, we'll make sure the collection request is valid
	local collection_exists = self:parent_exists()
	self:assertTrue_404(collection_exists)
	local redis = self:get_db()
	local url_segments = self:get_url_segments();
	local collection, instance, secondary_collection = 
		url_segments[1], url_segments[2], url_segments[3]
	local prefix = "Redfish:" .. collection .. ":" .. instance .. ":" .. secondary_collection
	self:set_scope("Redfish:" .. table.concat(url_segments, ":"))
	-- Creating response
	response["Name"] = "Memory Collection"
	response["Description"] = "Collection of Memories for this system"
	local odataIDs = utils.getODataIDArray(yield(redis:keys(prefix .. ":*:CapacityMiB")), 1)
	response["Members@odata.count"] = #odataIDs
	response["Members"] = odataIDs
	response = self:oem_extend(response, "query." .. self:get_oem_collection_path())
	self:set_context(CONSTANTS.MEMORY_COLLECTION_CONTEXT)
	self:set_type(CONSTANTS.MEMORY_COLLECTION_TYPE)
end
--Populate SMBIOS Memory Keys
function SystemMemoryHandler:get_smbios_memory(redis,id)
	local i=1
	local physical_id,mapped_addr_id = 0,0
	--Physical Memory ID
	while(1) do
		local temp_pl = redis:pipeline()
		temp_pl:hget(smbios_prefix .. ":MemoryDevice", "PhysicalMemoryArrayHandle:" .. id)
		temp_pl:hget(smbios_prefix .. ":PhysicalMemoryArray", "Handle:" .. i)
			
		local db_result = yield(temp_pl:run())
		self:assert_resource(db_result)
		local memory_device_physical_handle, physical_memory_handle = unpack(db_result)
			
		if (memory_device_physical_handle == physical_memory_handle) then
			physical_id = i
			break
		elseif(physical_memory_handle == nil) then
			break
		else 
			i=i+1
			temp_pl=nil
		end
			
	end
	i=1
	--Memory Device Mapped Addr
	while(1) do 
		local temp_pl = redis:pipeline()
		temp_pl:hget(smbios_prefix .. ":MemoryDevice", "Handle:" .. id)
		temp_pl:hget(smbios_prefix .. ":MemoryDeviceMappedAadr","MemoryDeviceHandle:" .. i)
			
		local db_result = yield(temp_pl:run())
		self:assert_resource(db_result)
		
		local memory_device_handle, memory_device_map_addr_handle = unpack(db_result)
			
		if (memory_device_handle == memory_device_map_addr_handle) then
			mapped_addr_id = i
			break		
		elseif(memory_device_map_addr_handle == nil) then
			break
		else 
			i=i+1
			temp_pl=nil
		end
			
	end
		
	return physical_id,mapped_addr_id
		
end
-- Handles GET System Memory instance
function SystemMemoryHandler:get_instance(response)
	local redis = self:get_db()
	local url_segments = self:get_url_segments()
	local prefix = "Redfish:" .. table.concat(url_segments, ":")
	self:set_scope("Redfish:" .. table.concat(url_segments, ":"))
	local pl = redis:pipeline()
	pl:mget({
		prefix .. ":Name",
		prefix .. ":Description",
		prefix .. ":MemoryType",
		prefix .. ":MemoryDeviceType",
		prefix .. ":BaseModuleType",
		prefix .. ":CapacityMiB",
		prefix .. ":DataWidthBits",
		prefix .. ":BusWidthBits",
		prefix .. ":Manufacturer",
		prefix .. ":SerialNumber",
		prefix .. ":PartNumber",
		prefix .. ":FirmwareRevision",
		prefix .. ":FirmwareApiVersion",
		prefix .. ":VendorID",
		prefix .. ":DeviceID",
		prefix .. ":SubsystemVendorID",
		prefix .. ":SubsystemDeviceID",
		prefix .. ":SecurityCapabilities:PassphraseCapable",
		prefix .. ":SecurityCapabilities:MaxPassphraseCount",
		prefix .. ":SpareDeviceCount",
		prefix .. ":RankCount",
		prefix .. ":DeviceLocator",
		prefix .. ":MemoryLocation:Socket",
		prefix .. ":MemoryLocation:MemoryController",
		prefix .. ":MemoryLocation:Channel",
		prefix .. ":MemoryLocation:Slot",
		prefix .. ":ErrorCorrection",
		prefix .. ":OperatingSpeedMhz",
		prefix .. ":VolatileRegionSizeLimitMiB",
		prefix .. ":PersistentRegionSizeLimitMiB",
		prefix .. ":PowerManagementPolicy:PolicyEnabled",
		prefix .. ":PowerManagementPolicy:MaxTDPMilliWatts",
		prefix .. ":PowerManagementPolicy:PeakPowerBudgetMilliWatts",
		prefix .. ":PowerManagementPolicy:AveragePowerBudgetMilliWatts",
		prefix .. ":IsSpareDeviceEnabled",
		prefix .. ":IsRankSpareEnabled",
		prefix .. ":Status:State", 
       		prefix .. ":Status:HealthRollup", 
		prefix .. ":Status:Health" 
	})
	pl:smembers(prefix .. ":MemoryMedia")
	pl:smembers(prefix .. ":AllowedSpeedsMHz")
	pl:smembers(prefix .. ":FunctionClasses")
	pl:smembers(prefix .. ":MaxTDPMilliWatts")
	pl:smembers(prefix .. ":SecurityCapabilities:SecurityStates")
	pl:smembers(prefix .. ":OperatingMemoryModes")
	local zcard_response = yield(redis:zcard(prefix .. ":Regions:SortedIds"))
	pl:zrange(prefix .. ":Regions:SortedIds", 0, zcard_response - 1)
	local db_result = yield(pl:run())
	self:assert_resource(db_result)
	local general, MemoryMedia, AllowedSpeedsMHz, FunctionClasses, MaxTDPMilliWatts, SecurityCapabilities_SecurityStates, OperatingMemoryModes, Regions = unpack(db_result)
	if(general[6] == nil) then  -- if memory is not present
		self:assert_resource(nil)
	end
	response["Id"] = url_segments[#url_segments]
	response["Name"] = general[1]
	response["Description"] = general[2]
	response["MemoryType"] = general[3]
	response["MemoryDeviceType"] = general[4]
	response["BaseModuleType"] = general[5]
	response["CapacityMiB"] = math.floor(tonumber(general[6]))
	response["DataWidthBits"] = tonumber(general[7])
	response["BusWidthBits"] = tonumber(general[8])
	response["Manufacturer"] = general[9]
	response["SerialNumber"] = general[10]
	response["PartNumber"] = general[11]
	response["FirmwareRevision"] = general[12]
	response["FirmwareApiVersion"] = general[13]
	response["VendorID"] = general[14]
	response["DeviceID"] = general[15]
	response["SubsystemVendorID"] = general[16]
	response["SubsystemDeviceID"] = general[17]
	response["SecurityCapabilities"] = {}
	response["SecurityCapabilities"]["PassphraseCapable"] = utils.bool(general[18])
	response["SecurityCapabilities"]["MaxPassphraseCount"] = tonumber(general[19])
	response["SecurityCapabilities"]["SecurityStates"] = SecurityCapabilities_SecurityStates
	response["SpareDeviceCount"] = tonumber(general[20])
	response["RankCount"] = tonumber(general[21])
	response["DeviceLocator"] = general[22]
	response["MemoryLocation"] = {}
	response["MemoryLocation"]["Socket"] = tonumber(general[23])
	response["MemoryLocation"]["MemoryController"] = tonumber(general[24])
	response["MemoryLocation"]["Channel"] = tonumber(general[25])
	response["MemoryLocation"]["Slot"] = tonumber(general[26])
	response["ErrorCorrection"] = general[27]
	response["OperatingSpeedMhz"] = tonumber(general[28], 16)
	response["VolatileRegionSizeLimitMiB"] = tonumber(general[29])
	response["PersistentRegionSizeLimitMiB"] = tonumber(general[30])
	response["PowerManagementPolicy"] = {}
	response["PowerManagementPolicy"]["PolicyEnabled"] = utils.bool(general[31])
	response["PowerManagementPolicy"]["MaxTDPMilliWatts"] = tonumber(general[32])
	response["PowerManagementPolicy"]["PeakPowerBudgetMilliWatts"] = tonumber(general[33])
	response["PowerManagementPolicy"]["AveragePowerBudgetMilliWatts"] = tonumber(general[34])
	response["IsSpareDeviceEnabled"] = utils.bool(general[35])
	response["IsRankSpareEnabled"] = utils.bool(general[36])
	response["Status"] = {} 
	response["Status"]["State"] = general[37] 
	response["Status"]["HealthRollup"] = general[38] 
	response["Status"]["Health"] = general[39] 
	response["Metrics"] = {["@odata.id"] = CONFIG.SERVICE_PREFIX .. table.concat(url_segments, "/") .. "/Metrics"}
	response["MemoryMedia"] = MemoryMedia
	response["AllowedSpeedsMHz"] = _.map(AllowedSpeedsMHz, function(num) return tonumber(num) end)
	response["FunctionClasses"] = FunctionClasses
	response["MaxTDPMilliWatts"] = MaxTDPMilliWatts
	response["OperatingMemoryModes"] = OperatingMemoryModes
	response["Regions"] = {}
	for _index, entry in pairs(Regions) do
		local array_entry = {}
		array_entry["RegionId"] = yield(redis:get(entry .. ":RegionId"))
		array_entry["MemoryClassification"] = yield(redis:get(entry .. ":MemoryClassification"))
		array_entry["OffsetMiB"] = math.floor(tonumber(yield(redis:get(entry .. ":OffsetMiB"))))
		array_entry["SizeMiB"] = math.floor(tonumber(yield(redis:get(entry .. ":SizeMiB"))))
		array_entry["PassphraseState"] = yield(redis:get(entry .. ":PassphraseState")) == "true"
		table.insert(response["Regions"], array_entry)
	end
	response["Actions"] = self:oem_extend(response["Actions"], "query." .. self:get_oem_instance_action_path())
	response = self:oem_extend(response, "query." .. self:get_oem_instance_path())
	utils.remove_nils(response)
	
	-- Set the OData context and type for the response
	local keys = _.keys(response)
	if #keys < 40 then
		local select_list = turbo.util.join(",", keys)
		self:set_context(CONSTANTS.MEMORY_INSTANCE_CONTEXT .. "(" .. select_list .. ")")
	else
		self:set_context(CONSTANTS.MEMORY_INSTANCE_CONTEXT .. "(*)")
	end
	self:set_type(CONSTANTS.MEMORY_TYPE)
	self:set_allow_header("GET")
end
return SystemMemoryHandler
