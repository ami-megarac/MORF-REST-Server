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
-- [See "./extensions/constants/storage_constants.lua"](/extensions/constants/storage_constants.html)
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
local PCIeDeviceFunctionHandler = class("PCIeDeviceFunctionHandler", RedfishHandler)
local yield = coroutine.yield
function PCIeDeviceFunctionHandler:get(FabricId,DeviceId,FunctionId)
	local response = {}
	--[[
	if FabricId then
		print("Fabric Instance : " .. FabricId)
	end
	
	if DeviceId then
		print("Device Instance : " .. DeviceId)
	end
	
	if FunctionId then
		print("Function Instance : " .. FunctionId)
	end
		
	if FabricId and DeviceId and not FunctionId then
		--GET collection
		print("GET collection");
		self:get_collection(response)
	else
		--GET instance
		print("GET instance");
		self:get_instance(response)
	end
	--]]
	self:get_instance(response)
	self:set_response(response)
	self:output()
end
--Handles GET requests for Fabrics PCIe Device Functions collection
function PCIeDeviceFunctionHandler:get_collection(response)
	
	local redis = self:get_db()
	local pl = redis:pipeline()
	local url_segments = self:get_url_segments()
	
	print("url_segments");
	print(inspect(url_segments));
	
	local prefix = "Redfish:" .. table.concat(url_segments, ":")
	
	self:set_scope(prefix)
	
	pl:mget({
		prefix .. ":DName",
		prefix .. ":Description"
	})
	local db_result = yield(pl:run())
	local general = unpack(db_result)
	
	-- Creating response
	if general[1] ~= nil then 
		response["Name"] = general[1]
	else
		response["Name"] = "PCIe Function Collection"
	end
	
	if general[2] ~= nil then 
		response["Description"] = general[2]
	else
		response["Description"] = "PCIe Function Collection"
	end
	
	local odataIDs = utils.getODataIDArray(yield(redis:keys(prefix .. ":*:DFName")), 1)
	response["Members@odata.count"] = #odataIDs
	response["Members"] = odataIDs
	self:set_context(CONSTANTS.PCIe_DEVICEFUNCTION_COLLECTION_CONTEXT)
	self:set_type(CONSTANTS.PCIe_DEVICEFUNCTION_COLLECTION_TYPE)
	-- GET requests must respond with the 'Allow' header specifying what methods are available for the given URL
	self:set_allow_header("GET, PATCH")
end
-- Handles GET Fabrics PCIe Device Functions instance
function PCIeDeviceFunctionHandler:get_instance(response)
	
	local redis = self:get_db()
	local pl = redis:pipeline()
	local url_segments = self:get_url_segments()
	local prefix = "Redfish:" .. table.concat(url_segments, ":")
	
	self:set_scope(prefix)
	pl:mget({
		prefix .. ":Name",
		prefix .. ":Description",
		prefix .. ":FunctionId",
		prefix .. ":FunctionType",
		prefix .. ":DeviceClass",
		prefix .. ":DeviceId",
		prefix .. ":VendorId",
		prefix .. ":ClassCode",
		prefix .. ":RevisionId",
		prefix .. ":SubsystemId",
		prefix .. ":SubsystemVendorId",
		prefix .. ":Status:State", 
        prefix .. ":Status:HealthRollup", 
		prefix .. ":Status:Health" 
	})
	
	
	local db_result = yield(pl:run())
	-- Check that data was found in Redis, if not we throw a 404 NOT FOUND
	self:assert_resource(db_result)
	local general = unpack(db_result)
	
	-- Creating response
	--response["@Redfish.Copyright"] = "Copyright 2014-2016 Distributed Management Task Force, Inc. (DMTF). All rights reserved."
	
	response["Id"] = url_segments[#url_segments]
	response["Name"] = general[1]
	response["Description"] = general[2]
	response["FunctionId"] = general[3]
	response["FunctionType"] = general[4]
	response["DeviceClass"] = general[5]
	response["DeviceId"] = general[6]
	response["VendorId"] = general[7]
	response["ClassCode"] = general[8]
	response["RevisionId"] = general[9]
	response["SubsystemId"] = general[10]
	response["SubsystemVendorId"] = general[11]	
	response["Status"] = {} 
	response["Status"]["State"] = general[12] 
	response["Status"]["HealthRollup"] = general[13] 
	response["Status"]["Health"] = general[14] 
	
	local device_prefix = "Redfish:" .. table.concat(url_segments, ":",1,4)
	
	local Devices = utils.getODataIDArray(yield(redis:keys(device_prefix .. ":DeviceType")), 1)
	
	response["Links"] = {}
	if #Devices > 0 then
		response["Links"]["PCIeDevice"] = Devices
	end
    --local Drives = utils.getODataIDArray(yield(redis:keys("Redfish:" .. table.concat(url_segments, ":", 1,2) .. ":Drives:*:CapacityBytes")), 1)
	local Drives = utils.getODataIDArray(yield(redis:smembers(prefix .. ":Drives")))
    if #Drives > 0 then
        response ["Links"]["Drives"] = Drives
    end
	
	response = self:oem_extend(response, "query.chassis.chassis-PCIeFunction")
	self:set_context(CONSTANTS.PCIe_DEVICEFUNCTION_INSTANCE_CONTEXT)
	self:set_type(CONSTANTS.PCIe_DEVICEFUNCTION_INSTANCE_TYPE)
	utils.remove_nils(response)
	-- GET requests must respond with the 'Allow' header specifying what methods are available for the given URL
	self:set_allow_header("GET, PATCH")
end
return PCIeDeviceFunctionHandler
