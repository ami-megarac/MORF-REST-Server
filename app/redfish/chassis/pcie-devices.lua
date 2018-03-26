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
local PCIeDeviceHandler = class("PCIeDeviceHandler", RedfishHandler)
local yield = coroutine.yield
function PCIeDeviceHandler:get(FabricId,DeviceId)
	local response = {}
	--[[
	if FabricId then
		print("Fabric Instance : " .. FabricId)
	end
	
	if DeviceId then
		print("Device Instance : " .. DeviceId)
	end
	
	if FabricId and not DeviceId then
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
--Handles GET requests for Fabrics PCIe Devices collection
function PCIeDeviceHandler:get_collection(response)
	
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
		response["Name"] = "PCIe Device Collection"
	end
	
	if general[2] ~= nil then 
		response["Description"] = general[2]
	else
		response["Description"] = "PCIe Device Collection"
	end
	
	local odataIDs = utils.getODataIDArray(yield(redis:keys(prefix .. ":*:DName")), 1)
	response["Members@odata.count"] = #odataIDs
	response["Members"] = odataIDs
	self:set_context(CONSTANTS.PCIe_DEVICE_COLLECTION_CONTEXT)
	self:set_type(CONSTANTS.PCIe_DEVICE_COLLECTION_TYPE)
	-- GET requests must respond with the 'Allow' header specifying what methods are available for the given URL
	self:set_allow_header("GET, PATCH")
end
-- Handles GET Fabrics PCIe Devices instance
function PCIeDeviceHandler:get_instance(response)
	
	local redis = self:get_db()
	local pl = redis:pipeline()
	local url_segments = self:get_url_segments()
	local prefix = "Redfish:" .. table.concat(url_segments, ":")
	
	self:set_scope(prefix)
	pl:mget({
		prefix .. ":Name",
		prefix .. ":Description",
		prefix .. ":Manufacturer",
		prefix .. ":Model",
       		prefix .. ":SKU",
        	prefix .. ":SerialNumber",
        	prefix .. ":PartNumber",
		prefix .. ":AssetTag",
        	prefix .. ":DeviceType",
        	prefix .. ":FirmwareVersion",
		prefix .. ":Status:State", 
       		prefix .. ":Status:HealthRollup", 
		prefix .. ":Status:Health" 
	})
	
	pl:smembers(prefix .. ":Links:Chassis")
	
	local db_result = yield(pl:run())
	-- Check that data was found in Redis, if not we throw a 404 NOT FOUND
	self:assert_resource(db_result)
	local general, ChassisLinks = unpack(db_result)
	
	-- Creating response
	--response["@Redfish.Copyright"] = "Copyright 2014-2016 Distributed Management Task Force, Inc. (DMTF). All rights reserved."
	
	response["Id"] = url_segments[#url_segments]
	response["Name"] = general[1]
	response["Description"] = general[2]
	response["Manufacturer"] = general[3]
	response["Model"] = general[4]
	response["SKU"] = general[5]
	response["SerialNumber"] = general[6]
	response["PartNumber"] = general[7]
	response["AssetTag"] = general[8]
	response["DeviceType"] = general[9]
	response["FirmwareVersion"] = general[10]
	response["Status"] = {} 
	response["Status"]["State"] = general[11] 
	response["Status"]["HealthRollup"] = general[12] 
	response["Status"]["Health"] = general[13] 
	
	local pcie_function = "Redfish:" .. url_segments[1] .. ":" .. url_segments[2] .. ":PCIeDevices:" .. url_segments[4] .. ":Functions:*:Name"	
	local Devicefunctions = utils.getODataIDArray(yield(redis:keys(pcie_function)), 1)
	response["Links"] = {}
	if #ChassisLinks > 0 then
		response["Links"]["Chassis"] = ChassisLinks
	else
		response["Links"]["Chassis"] = {{["@odata.id"] = CONFIG.SERVICE_PREFIX .. "/" .. url_segments[1] .. "/" .. url_segments[2]}}
	end
	if #Devicefunctions > 0 then
		response["Links"]["PCIeFunctions"] = Devicefunctions
	end
	
	response = self:oem_extend(response, "query.chassis.chassis-PCIeDevice")
	response["Actions"] = self:oem_extend(response["Actions"],  "query.chassis.chassis-PCIeDevice-actions")
	self:set_context(CONSTANTS.PCIe_DEVICE_INSTANCE_CONTEXT)
	self:set_type(CONSTANTS.PCIe_DEVICE_INSTANCE_TYPE)
	utils.remove_nils(response)
	-- GET requests must respond with the 'Allow' header specifying what methods are available for the given URL
	self:set_allow_header("GET, PATCH")
end
return PCIeDeviceHandler
