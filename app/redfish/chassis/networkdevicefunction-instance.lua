-- Import required libraries
-- [See "redfish-handler.lua"](/redfish-handler.html)
local RedfishHandler = require("redfish-handler")
-- [See "constants.lua"](/constants.html)
local CONSTANTS = require("constants")
-- [See "turboredis.lua"](https://github.com/enotodden/turboredis)
local db_utils = require("turboredis.util")
-- [See "config.lua"](/config.html)
local CONFIG = require("config")
-- [See "utils.lua"](/utils.html)
local utils = require("utils")
-- [See "turbo library"](http://turbolua.org)
local turbo = require("turbo")
-- [See "underscore.lua"](https://mirven.github.io/underscore.lua/)
local _ = require("underscore")
local yield = coroutine.yield
local NetworkDeviceFunctionInstanceHandler = class("NetworkDeviceFunctionInstanceHandler", RedfishHandler)

local NetDevFuncType_allowable_vals = {'Disabled', 'Ethernet', 'FibreChannel', 'iSCSI', 'FibreChannelOverEthernet'}
local iSCSIBoot_IPAddressType_allowable_vals = {'IPv4', 'IPv6'}
local iSCSIBoot_AuthenticationMethod_allowable_vals = {'None', 'CHAP', 'MutualCHAP'}
local FibreChannel_WWNSource_allowable_vals = {'ConfiguredLocally', 'ProvidedByFabric'}
local BootMode_allowable_vals = {'Disabled', 'PXE', 'iSCSI', 'FibreChannel', 'FibreChannelOverEthernet'}
function NetworkDeviceFunctionInstanceHandler:get(url_capture0, url_capture1, url_capture2)
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
		prefix .. ":NetDevFuncType",
		prefix .. ":DeviceEnabled",
		prefix .. ":Ethernet:PermanentMACAddress",
		prefix .. ":Ethernet:MACAddress",
		prefix .. ":Ethernet:MTUSize",
		prefix .. ":iSCSIBoot:IPAddressType",
		prefix .. ":iSCSIBoot:InitiatorIPAddress",
		prefix .. ":iSCSIBoot:InitiatorName",
		prefix .. ":iSCSIBoot:InitiatorDefaultGateway",
		prefix .. ":iSCSIBoot:InitiatorNetmask",
		prefix .. ":iSCSIBoot:TargetInfoViaDHCP",
		prefix .. ":iSCSIBoot:PrimaryTargetName",
		prefix .. ":iSCSIBoot:PrimaryTargetIPAddress",
		prefix .. ":iSCSIBoot:PrimaryTargetTCPPort",
		prefix .. ":iSCSIBoot:PrimaryLUN",
		prefix .. ":iSCSIBoot:PrimaryVLANEnable",
		prefix .. ":iSCSIBoot:PrimaryVLANId",
		prefix .. ":iSCSIBoot:PrimaryDNS",
		prefix .. ":iSCSIBoot:SecondaryTargetName",
		prefix .. ":iSCSIBoot:SecondaryTargetIPAddress",
		prefix .. ":iSCSIBoot:SecondaryTargetTCPPort",
		prefix .. ":iSCSIBoot:SecondaryLUN",
		prefix .. ":iSCSIBoot:SecondaryVLANEnable",
		prefix .. ":iSCSIBoot:SecondaryVLANId",
		prefix .. ":iSCSIBoot:SecondaryDNS",
		prefix .. ":iSCSIBoot:IPMaskDNSViaDHCP",
		prefix .. ":iSCSIBoot:RouterAdvertisementEnabled",
		prefix .. ":iSCSIBoot:AuthenticationMethod",
		prefix .. ":iSCSIBoot:CHAPUsername",
		prefix .. ":iSCSIBoot:CHAPSecret",
		prefix .. ":iSCSIBoot:MutualCHAPUsername",
		prefix .. ":iSCSIBoot:MutualCHAPSecret",
		prefix .. ":FibreChannel:PermanentWWPN",
		prefix .. ":FibreChannel:PermanentWWNN",
		prefix .. ":FibreChannel:WWPN",
		prefix .. ":FibreChannel:WWNN",
		prefix .. ":FibreChannel:WWNSource",
		prefix .. ":FibreChannel:FCoELocalVLANId",
		prefix .. ":FibreChannel:AllowFIPVLANDiscovery",
		prefix .. ":FibreChannel:FCoEActiveVLANId",
		prefix .. ":BootMode",
		prefix .. ":VirtualFunctionsEnabled",
		prefix .. ":MaxVirtualFunctions",
		prefix .. ":Links:PCIeFunction"
	})

	pl:smembers(prefix .. ":NetDevFuncCapabilities")
	local zcard_response = yield(redis:zcard(prefix .. ":FibreChannel:BootTargets:SortedIDs"))

	pl:zrange(prefix .. ":FibreChannel:BootTargets:SortedIDs", 0, zcard_response - 1)
	pl:smembers(prefix .. ":AssignablePhysicalPorts")
	local db_result = yield(pl:run())
	self:assert_resource(db_result)
	local general, NetDevFuncCapabilities, FibreChannel_BootTargets, AssignablePhysicalPorts = unpack(db_result)
	response["Id"] = general[1]
	response["Name"] = general[2]
	response["Description"] = general[3]
	response["Status"] = {}
	response["Status"]["State"] = general[4]
	response["Status"]["HealthRollup"] = general[5]
	response["Status"]["Health"] = general[6]
	response["Status"]["Oem"] = {}
	response["NetDevFuncType"] = general[7]
	response["NetDevFuncType@Redfish.AllowableValues"] = NetDevFuncType_allowable_vals
	response["DeviceEnabled"] = utils.bool(general[8])
	response["NetDevFuncCapabilities"] = {}
	response["NetDevFuncCapabilities"] = NetDevFuncCapabilities
	response["Ethernet"] = {}
	response["Ethernet"]["PermanentMACAddress"] = general[9]
	response["Ethernet"]["MACAddress"] = general[10]
	response["Ethernet"]["MTUSize"] = tonumber(general[11])
	response["iSCSIBoot"] = {}
	response["iSCSIBoot"]["IPAddressType"] = general[12]
	response["iSCSIBoot"]["IPAddressType@Redfish.AllowableValues"] = iSCSIBoot_IPAddressType_allowable_vals
	response["iSCSIBoot"]["InitiatorIPAddress"] = general[13]
	response["iSCSIBoot"]["InitiatorName"] = general[14]
	response["iSCSIBoot"]["InitiatorDefaultGateway"] = general[15]
	response["iSCSIBoot"]["InitiatorNetmask"] = general[16]
	response["iSCSIBoot"]["TargetInfoViaDHCP"] = utils.bool(general[17])
	response["iSCSIBoot"]["PrimaryTargetName"] = general[18]
	response["iSCSIBoot"]["PrimaryTargetIPAddress"] = general[19]
	response["iSCSIBoot"]["PrimaryTargetTCPPort"] = tonumber(general[20])
	response["iSCSIBoot"]["PrimaryLUN"] = tonumber(general[21])
	response["iSCSIBoot"]["PrimaryVLANEnable"] = utils.bool(general[22])
	response["iSCSIBoot"]["PrimaryVLANId"] = tonumber(general[23])
	response["iSCSIBoot"]["PrimaryDNS"] = general[24]
	response["iSCSIBoot"]["SecondaryTargetName"] = general[25]
	response["iSCSIBoot"]["SecondaryTargetIPAddress"] = general[26]
	response["iSCSIBoot"]["SecondaryTargetTCPPort"] = tonumber(general[27])
	response["iSCSIBoot"]["SecondaryLUN"] = tonumber(general[28])
	response["iSCSIBoot"]["SecondaryVLANEnable"] = utils.bool(general[29])
	response["iSCSIBoot"]["SecondaryVLANId"] = tonumber(general[30])
	response["iSCSIBoot"]["SecondaryDNS"] = general[31]
	response["iSCSIBoot"]["IPMaskDNSViaDHCP"] = utils.bool(general[32])
	response["iSCSIBoot"]["RouterAdvertisementEnabled"] = utils.bool(general[33])
	response["iSCSIBoot"]["AuthenticationMethod"] = general[34]
	response["iSCSIBoot"]["AuthenticationMethod@Redfish.AllowableValues"] = iSCSIBoot_AuthenticationMethod_allowable_vals
	response["iSCSIBoot"]["CHAPUsername"] = general[35]
	response["iSCSIBoot"]["CHAPSecret"] = general[36]
	response["iSCSIBoot"]["MutualCHAPUsername"] = general[37]
	response["iSCSIBoot"]["MutualCHAPSecret"] = general[38]
	response["FibreChannel"] = {}
	response["FibreChannel"]["PermanentWWPN"] = general[39]
	response["FibreChannel"]["PermanentWWNN"] = general[40]
	response["FibreChannel"]["WWPN"] = general[41]
	response["FibreChannel"]["WWNN"] = general[42]
	response["FibreChannel"]["WWNSource"] = general[43]
	response["FibreChannel"]["WWNSource@Redfish.AllowableValues"] = FibreChannel_WWNSource_allowable_vals
	response["FibreChannel"]["FCoELocalVLANId"] = tonumber(general[44])
	response["FibreChannel"]["AllowFIPVLANDiscovery"] = utils.bool(general[45])
	response["FibreChannel"]["FCoEActiveVLANId"] = tonumber(general[46])
	response["FibreChannel"]["BootTargets"] = {}
	for _index, entry in pairs(FibreChannel_BootTargets) do
		local array_entry = {}
		print("WWPN : ", yield(redis:get(entry .. ":" .. tostring(_index) .. ":WWPN")))

		array_entry["WWPN"] = yield(redis:get(entry .. ":WWPN"))
		array_entry["LUNID"] = yield(redis:get(entry .. ":LUNID"))
		array_entry["BootPriority"] = yield(redis:get(entry .. ":BootPriority"))

		table.insert(response["FibreChannel"]["BootTargets"], array_entry)		
	end

	response["BootMode"] = general[47]
	response["BootMode@Redfish.AllowableValues"] = BootMode_allowable_vals
	response["VirtualFunctionsEnabled"] = utils.bool(general[48])
	response["MaxVirtualFunctions"] = tonumber(general[49])
	response["Links"] = {}
	response["Links"]["PCIeFunction"] = {["@odata.id"] = utils.getODataID(general[50])}
	response["AssignablePhysicalPorts"] = utils.getODataIDArray(AssignablePhysicalPorts)
	response["PhysicalPortAssignment"] = {["@odata.id"] = CONFIG.SERVICE_PREFIX .. "/" .. table.concat(url_segments, "/") .. "/PhysicalPortAssignment"}
	response["Links"] ={}
	response["Links"]["PCIeFunction"] ={}
	response["Links"]["PCIeFunction"] = {["@odata.id"] = CONFIG.SERVICE_PREFIX .. "/" .. table.concat(url_segments, "/") .. "/PCIeFunction"}
	response = self:oem_extend(response, "query.networkdevicefunction-instance")
	utils.remove_nils(response)
	self:set_context("NetworkDeviceFunction.NetworkDeviceFunction")
	self:set_type(CONSTANTS.NETWORKDEVICEFUNCTION_TYPE)
	self:set_allow_header("GET,PATCH")
	self:set_response(response)
	self:output()
end

function NetworkDeviceFunctionInstanceHandler:patch(url_capture0, url_capture1, url_capture2)
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
		if type(request_data.NetDevFuncType) ~= "nil" then
			local NetDevFuncType = NetDevFuncType_allowable_vals
			if type(request_data.NetDevFuncType) ~= "string" then
				table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/NetDevFuncType"}, {tostring(request_data.NetDevFuncType) .. "(" .. type(request_data.NetDevFuncType) .. ")", "NetDevFuncType"}))
			elseif turbo.util.is_in(request_data.NetDevFuncType, NetDevFuncType) == nil then
				table.insert(extended, self:create_message("Base", "PropertyValueNotInList", {"#/NetDevFuncType"}, {request_data.NetDevFuncType, "NetDevFuncType"}))
			else
				pl:set(prefix .. ":NetDevFuncType", tostring(request_data.NetDevFuncType))
				table.insert(successful_sets, "NetDevFuncType")
			end
			request_data.NetDevFuncType = nil
		end
		if type(request_data.DeviceEnabled) ~= "nil" then
			if type(request_data.DeviceEnabled) ~= "boolean" then
				table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/DeviceEnabled"}, {tostring(request_data.DeviceEnabled) .. "(" .. type(request_data.DeviceEnabled) .. ")", "DeviceEnabled"}))
			else
				pl:set(prefix .. ":DeviceEnabled", tostring(request_data.DeviceEnabled))
				table.insert(successful_sets, "DeviceEnabled")
			end
			request_data.DeviceEnabled = nil
		end
		if type(request_data.Ethernet) ~= "nil" then
			if type(request_data.Ethernet.MACAddress) ~= "nil" then
				if type(request_data.Ethernet.MACAddress) ~= "string" then
					table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/Ethernet/MACAddress"}, {tostring(request_data.Ethernet.MACAddress) .. "(" .. type(request_data.Ethernet.MACAddress) .. ")", "MACAddress"}))
				else
					pl:set(prefix .. ":Ethernet:MACAddress", tostring(request_data.Ethernet.MACAddress))
					table.insert(successful_sets, "MACAddress")
				end
				request_data.Ethernet.MACAddress = nil
			end
			if type(request_data.Ethernet.MTUSize) ~= "nil" then
				if type(request_data.Ethernet.MTUSize) ~= "number" then
					table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/Ethernet/MTUSize"}, {tostring(request_data.Ethernet.MTUSize) .. "(" .. type(request_data.Ethernet.MTUSize) .. ")", "MTUSize"}))
				else
					pl:set(prefix .. ":Ethernet:MTUSize", tostring(request_data.Ethernet.MTUSize))
					table.insert(successful_sets, "MTUSize")
				end
				request_data.Ethernet.MTUSize = nil
			end
		end
		if type(request_data.iSCSIBoot) ~= "nil" then
			if type(request_data.iSCSIBoot.IPAddressType) ~= "nil" then
				local iSCSIBoot_IPAddressType = iSCSIBoot_IPAddressType_allowable_vals
				if type(request_data.iSCSIBoot.IPAddressType) ~= "string" then
					table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/iSCSIBoot/IPAddressType"}, {tostring(request_data.iSCSIBoot.IPAddressType) .. "(" .. type(request_data.iSCSIBoot.IPAddressType) .. ")", "IPAddressType"}))
				elseif turbo.util.is_in(request_data.iSCSIBoot.IPAddressType, iSCSIBoot_IPAddressType) == nil then
					table.insert(extended, self:create_message("Base", "PropertyValueNotInList", {"#/iSCSIBoot/IPAddressType"}, {request_data.iSCSIBoot.IPAddressType, "IPAddressType"}))
				else
					pl:set(prefix .. ":iSCSIBoot:IPAddressType", tostring(request_data.iSCSIBoot.IPAddressType))
					table.insert(successful_sets, "IPAddressType")
				end
				request_data.iSCSIBoot.IPAddressType = nil
			end
			if type(request_data.iSCSIBoot.InitiatorIPAddress) ~= "nil" then
				if type(request_data.iSCSIBoot.InitiatorIPAddress) ~= "string" then
					table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/iSCSIBoot/InitiatorIPAddress"}, {tostring(request_data.iSCSIBoot.InitiatorIPAddress) .. "(" .. type(request_data.iSCSIBoot.InitiatorIPAddress) .. ")", "InitiatorIPAddress"}))
				else
					pl:set(prefix .. ":iSCSIBoot:InitiatorIPAddress", tostring(request_data.iSCSIBoot.InitiatorIPAddress))
					table.insert(successful_sets, "InitiatorIPAddress")
				end
				request_data.iSCSIBoot.InitiatorIPAddress = nil
			end
			if type(request_data.iSCSIBoot.InitiatorName) ~= "nil" then
				if type(request_data.iSCSIBoot.InitiatorName) ~= "string" then
					table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/iSCSIBoot/InitiatorName"}, {tostring(request_data.iSCSIBoot.InitiatorName) .. "(" .. type(request_data.iSCSIBoot.InitiatorName) .. ")", "InitiatorName"}))
				else
					pl:set(prefix .. ":iSCSIBoot:InitiatorName", tostring(request_data.iSCSIBoot.InitiatorName))
					table.insert(successful_sets, "InitiatorName")
				end
				request_data.iSCSIBoot.InitiatorName = nil
			end
			if type(request_data.iSCSIBoot.InitiatorDefaultGateway) ~= "nil" then
				if type(request_data.iSCSIBoot.InitiatorDefaultGateway) ~= "string" then
					table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/iSCSIBoot/InitiatorDefaultGateway"}, {tostring(request_data.iSCSIBoot.InitiatorDefaultGateway) .. "(" .. type(request_data.iSCSIBoot.InitiatorDefaultGateway) .. ")", "InitiatorDefaultGateway"}))
				else
					pl:set(prefix .. ":iSCSIBoot:InitiatorDefaultGateway", tostring(request_data.iSCSIBoot.InitiatorDefaultGateway))
					table.insert(successful_sets, "InitiatorDefaultGateway")
				end
				request_data.iSCSIBoot.InitiatorDefaultGateway = nil
			end
			if type(request_data.iSCSIBoot.InitiatorNetmask) ~= "nil" then
				if type(request_data.iSCSIBoot.InitiatorNetmask) ~= "string" then
					table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/iSCSIBoot/InitiatorNetmask"}, {tostring(request_data.iSCSIBoot.InitiatorNetmask) .. "(" .. type(request_data.iSCSIBoot.InitiatorNetmask) .. ")", "InitiatorNetmask"}))
				else
					pl:set(prefix .. ":iSCSIBoot:InitiatorNetmask", tostring(request_data.iSCSIBoot.InitiatorNetmask))
					table.insert(successful_sets, "InitiatorNetmask")
				end
				request_data.iSCSIBoot.InitiatorNetmask = nil
			end
			if type(request_data.iSCSIBoot.TargetInfoViaDHCP) ~= "nil" then
				if type(request_data.iSCSIBoot.TargetInfoViaDHCP) ~= "boolean" then
					table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/iSCSIBoot/TargetInfoViaDHCP"}, {tostring(request_data.iSCSIBoot.TargetInfoViaDHCP) .. "(" .. type(request_data.iSCSIBoot.TargetInfoViaDHCP) .. ")", "TargetInfoViaDHCP"}))
				else
					pl:set(prefix .. ":iSCSIBoot:TargetInfoViaDHCP", tostring(request_data.iSCSIBoot.TargetInfoViaDHCP))
					table.insert(successful_sets, "TargetInfoViaDHCP")
				end
				request_data.iSCSIBoot.TargetInfoViaDHCP = nil
			end
			if type(request_data.iSCSIBoot.PrimaryTargetName) ~= "nil" then
				if type(request_data.iSCSIBoot.PrimaryTargetName) ~= "string" then
					table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/iSCSIBoot/PrimaryTargetName"}, {tostring(request_data.iSCSIBoot.PrimaryTargetName) .. "(" .. type(request_data.iSCSIBoot.PrimaryTargetName) .. ")", "PrimaryTargetName"}))
				else
					pl:set(prefix .. ":iSCSIBoot:PrimaryTargetName", tostring(request_data.iSCSIBoot.PrimaryTargetName))
					table.insert(successful_sets, "PrimaryTargetName")
				end
				request_data.iSCSIBoot.PrimaryTargetName = nil
			end
			if type(request_data.iSCSIBoot.PrimaryTargetIPAddress) ~= "nil" then
				if type(request_data.iSCSIBoot.PrimaryTargetIPAddress) ~= "string" then
					table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/iSCSIBoot/PrimaryTargetIPAddress"}, {tostring(request_data.iSCSIBoot.PrimaryTargetIPAddress) .. "(" .. type(request_data.iSCSIBoot.PrimaryTargetIPAddress) .. ")", "PrimaryTargetIPAddress"}))
				else
					pl:set(prefix .. ":iSCSIBoot:PrimaryTargetIPAddress", tostring(request_data.iSCSIBoot.PrimaryTargetIPAddress))
					table.insert(successful_sets, "PrimaryTargetIPAddress")
				end
				request_data.iSCSIBoot.PrimaryTargetIPAddress = nil
			end
			if type(request_data.iSCSIBoot.PrimaryTargetTCPPort) ~= "nil" then
				if type(request_data.iSCSIBoot.PrimaryTargetTCPPort) ~= "number" then
					table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/iSCSIBoot/PrimaryTargetTCPPort"}, {tostring(request_data.iSCSIBoot.PrimaryTargetTCPPort) .. "(" .. type(request_data.iSCSIBoot.PrimaryTargetTCPPort) .. ")", "PrimaryTargetTCPPort"}))
				else
					pl:set(prefix .. ":iSCSIBoot:PrimaryTargetTCPPort", tostring(request_data.iSCSIBoot.PrimaryTargetTCPPort))
					table.insert(successful_sets, "PrimaryTargetTCPPort")
				end
				request_data.iSCSIBoot.PrimaryTargetTCPPort = nil
			end
			if type(request_data.iSCSIBoot.PrimaryLUN) ~= "nil" then
				if type(request_data.iSCSIBoot.PrimaryLUN) ~= "number" then
					table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/iSCSIBoot/PrimaryLUN"}, {tostring(request_data.iSCSIBoot.PrimaryLUN) .. "(" .. type(request_data.iSCSIBoot.PrimaryLUN) .. ")", "PrimaryLUN"}))
				else
					pl:set(prefix .. ":iSCSIBoot:PrimaryLUN", tostring(request_data.iSCSIBoot.PrimaryLUN))
					table.insert(successful_sets, "PrimaryLUN")
				end
				request_data.iSCSIBoot.PrimaryLUN = nil
			end
			if type(request_data.iSCSIBoot.PrimaryVLANEnable) ~= "nil" then
				if type(request_data.iSCSIBoot.PrimaryVLANEnable) ~= "boolean" then
					table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/iSCSIBoot/PrimaryVLANEnable"}, {tostring(request_data.iSCSIBoot.PrimaryVLANEnable) .. "(" .. type(request_data.iSCSIBoot.PrimaryVLANEnable) .. ")", "PrimaryVLANEnable"}))
				else
					pl:set(prefix .. ":iSCSIBoot:PrimaryVLANEnable", tostring(request_data.iSCSIBoot.PrimaryVLANEnable))
					table.insert(successful_sets, "PrimaryVLANEnable")
				end
				request_data.iSCSIBoot.PrimaryVLANEnable = nil
			end
			if type(request_data.iSCSIBoot.PrimaryVLANId) ~= "nil" then
				if type(request_data.iSCSIBoot.PrimaryVLANId) ~= "number" then
					table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/iSCSIBoot/PrimaryVLANId"}, {tostring(request_data.iSCSIBoot.PrimaryVLANId) .. "(" .. type(request_data.iSCSIBoot.PrimaryVLANId) .. ")", "PrimaryVLANId"}))
				else
					pl:set(prefix .. ":iSCSIBoot:PrimaryVLANId", tostring(request_data.iSCSIBoot.PrimaryVLANId))
					table.insert(successful_sets, "PrimaryVLANId")
				end
				request_data.iSCSIBoot.PrimaryVLANId = nil
			end
			if type(request_data.iSCSIBoot.PrimaryDNS) ~= "nil" then
				if type(request_data.iSCSIBoot.PrimaryDNS) ~= "string" then
					table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/iSCSIBoot/PrimaryDNS"}, {tostring(request_data.iSCSIBoot.PrimaryDNS) .. "(" .. type(request_data.iSCSIBoot.PrimaryDNS) .. ")", "PrimaryDNS"}))
				else
					pl:set(prefix .. ":iSCSIBoot:PrimaryDNS", tostring(request_data.iSCSIBoot.PrimaryDNS))
					table.insert(successful_sets, "PrimaryDNS")
				end
				request_data.iSCSIBoot.PrimaryDNS = nil
			end
			if type(request_data.iSCSIBoot.SecondaryTargetName) ~= "nil" then
				if type(request_data.iSCSIBoot.SecondaryTargetName) ~= "string" then
					table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/iSCSIBoot/SecondaryTargetName"}, {tostring(request_data.iSCSIBoot.SecondaryTargetName) .. "(" .. type(request_data.iSCSIBoot.SecondaryTargetName) .. ")", "SecondaryTargetName"}))
				else
					pl:set(prefix .. ":iSCSIBoot:SecondaryTargetName", tostring(request_data.iSCSIBoot.SecondaryTargetName))
					table.insert(successful_sets, "SecondaryTargetName")
				end
				request_data.iSCSIBoot.SecondaryTargetName = nil
			end
			if type(request_data.iSCSIBoot.SecondaryTargetIPAddress) ~= "nil" then
				if type(request_data.iSCSIBoot.SecondaryTargetIPAddress) ~= "string" then
					table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/iSCSIBoot/SecondaryTargetIPAddress"}, {tostring(request_data.iSCSIBoot.SecondaryTargetIPAddress) .. "(" .. type(request_data.iSCSIBoot.SecondaryTargetIPAddress) .. ")", "SecondaryTargetIPAddress"}))
				else
					pl:set(prefix .. ":iSCSIBoot:SecondaryTargetIPAddress", tostring(request_data.iSCSIBoot.SecondaryTargetIPAddress))
					table.insert(successful_sets, "SecondaryTargetIPAddress")
				end
				request_data.iSCSIBoot.SecondaryTargetIPAddress = nil
			end
			if type(request_data.iSCSIBoot.SecondaryTargetTCPPort) ~= "nil" then
				if type(request_data.iSCSIBoot.SecondaryTargetTCPPort) ~= "number" then
					table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/iSCSIBoot/SecondaryTargetTCPPort"}, {tostring(request_data.iSCSIBoot.SecondaryTargetTCPPort) .. "(" .. type(request_data.iSCSIBoot.SecondaryTargetTCPPort) .. ")", "SecondaryTargetTCPPort"}))
				else
					pl:set(prefix .. ":iSCSIBoot:SecondaryTargetTCPPort", tostring(request_data.iSCSIBoot.SecondaryTargetTCPPort))
					table.insert(successful_sets, "SecondaryTargetTCPPort")
				end
				request_data.iSCSIBoot.SecondaryTargetTCPPort = nil
			end
			if type(request_data.iSCSIBoot.SecondaryLUN) ~= "nil" then
				if type(request_data.iSCSIBoot.SecondaryLUN) ~= "number" then
					table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/iSCSIBoot/SecondaryLUN"}, {tostring(request_data.iSCSIBoot.SecondaryLUN) .. "(" .. type(request_data.iSCSIBoot.SecondaryLUN) .. ")", "SecondaryLUN"}))
				else
					pl:set(prefix .. ":iSCSIBoot:SecondaryLUN", tostring(request_data.iSCSIBoot.SecondaryLUN))
					table.insert(successful_sets, "SecondaryLUN")
				end
				request_data.iSCSIBoot.SecondaryLUN = nil
			end
			if type(request_data.iSCSIBoot.SecondaryVLANEnable) ~= "nil" then
				if type(request_data.iSCSIBoot.SecondaryVLANEnable) ~= "boolean" then
					table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/iSCSIBoot/SecondaryVLANEnable"}, {tostring(request_data.iSCSIBoot.SecondaryVLANEnable) .. "(" .. type(request_data.iSCSIBoot.SecondaryVLANEnable) .. ")", "SecondaryVLANEnable"}))
				else
					pl:set(prefix .. ":iSCSIBoot:SecondaryVLANEnable", tostring(request_data.iSCSIBoot.SecondaryVLANEnable))
					table.insert(successful_sets, "SecondaryVLANEnable")
				end
				request_data.iSCSIBoot.SecondaryVLANEnable = nil
			end
			if type(request_data.iSCSIBoot.SecondaryVLANId) ~= "nil" then
				if type(request_data.iSCSIBoot.SecondaryVLANId) ~= "number" then
					table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/iSCSIBoot/SecondaryVLANId"}, {tostring(request_data.iSCSIBoot.SecondaryVLANId) .. "(" .. type(request_data.iSCSIBoot.SecondaryVLANId) .. ")", "SecondaryVLANId"}))
				else
					pl:set(prefix .. ":iSCSIBoot:SecondaryVLANId", tostring(request_data.iSCSIBoot.SecondaryVLANId))
					table.insert(successful_sets, "SecondaryVLANId")
				end
				request_data.iSCSIBoot.SecondaryVLANId = nil
			end
			if type(request_data.iSCSIBoot.SecondaryDNS) ~= "nil" then
				if type(request_data.iSCSIBoot.SecondaryDNS) ~= "string" then
					table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/iSCSIBoot/SecondaryDNS"}, {tostring(request_data.iSCSIBoot.SecondaryDNS) .. "(" .. type(request_data.iSCSIBoot.SecondaryDNS) .. ")", "SecondaryDNS"}))
				else
					pl:set(prefix .. ":iSCSIBoot:SecondaryDNS", tostring(request_data.iSCSIBoot.SecondaryDNS))
					table.insert(successful_sets, "SecondaryDNS")
				end
				request_data.iSCSIBoot.SecondaryDNS = nil
			end
			if type(request_data.iSCSIBoot.IPMaskDNSViaDHCP) ~= "nil" then
				if type(request_data.iSCSIBoot.IPMaskDNSViaDHCP) ~= "boolean" then
					table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/iSCSIBoot/IPMaskDNSViaDHCP"}, {tostring(request_data.iSCSIBoot.IPMaskDNSViaDHCP) .. "(" .. type(request_data.iSCSIBoot.IPMaskDNSViaDHCP) .. ")", "IPMaskDNSViaDHCP"}))
				else
					pl:set(prefix .. ":iSCSIBoot:IPMaskDNSViaDHCP", tostring(request_data.iSCSIBoot.IPMaskDNSViaDHCP))
					table.insert(successful_sets, "IPMaskDNSViaDHCP")
				end
				request_data.iSCSIBoot.IPMaskDNSViaDHCP = nil
			end
			if type(request_data.iSCSIBoot.RouterAdvertisementEnabled) ~= "nil" then
				if type(request_data.iSCSIBoot.RouterAdvertisementEnabled) ~= "boolean" then
					table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/iSCSIBoot/RouterAdvertisementEnabled"}, {tostring(request_data.iSCSIBoot.RouterAdvertisementEnabled) .. "(" .. type(request_data.iSCSIBoot.RouterAdvertisementEnabled) .. ")", "RouterAdvertisementEnabled"}))
				else
					pl:set(prefix .. ":iSCSIBoot:RouterAdvertisementEnabled", tostring(request_data.iSCSIBoot.RouterAdvertisementEnabled))
					table.insert(successful_sets, "RouterAdvertisementEnabled")
				end
				request_data.iSCSIBoot.RouterAdvertisementEnabled = nil
			end
			if type(request_data.iSCSIBoot.AuthenticationMethod) ~= "nil" then
				local iSCSIBoot_AuthenticationMethod = iSCSIBoot_AuthenticationMethod_allowable_vals
				if type(request_data.iSCSIBoot.AuthenticationMethod) ~= "string" then
					table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/iSCSIBoot/AuthenticationMethod"}, {tostring(request_data.iSCSIBoot.AuthenticationMethod) .. "(" .. type(request_data.iSCSIBoot.AuthenticationMethod) .. ")", "AuthenticationMethod"}))
				elseif turbo.util.is_in(request_data.iSCSIBoot.AuthenticationMethod, iSCSIBoot_AuthenticationMethod) == nil then
					table.insert(extended, self:create_message("Base", "PropertyValueNotInList", {"#/iSCSIBoot/AuthenticationMethod"}, {request_data.iSCSIBoot.AuthenticationMethod, "AuthenticationMethod"}))
				else
					pl:set(prefix .. ":iSCSIBoot:AuthenticationMethod", tostring(request_data.iSCSIBoot.AuthenticationMethod))
					table.insert(successful_sets, "AuthenticationMethod")
				end
				request_data.iSCSIBoot.AuthenticationMethod = nil
			end
			if type(request_data.iSCSIBoot.CHAPUsername) ~= "nil" then
				if type(request_data.iSCSIBoot.CHAPUsername) ~= "string" then
					table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/iSCSIBoot/CHAPUsername"}, {tostring(request_data.iSCSIBoot.CHAPUsername) .. "(" .. type(request_data.iSCSIBoot.CHAPUsername) .. ")", "CHAPUsername"}))
				else
					pl:set(prefix .. ":iSCSIBoot:CHAPUsername", tostring(request_data.iSCSIBoot.CHAPUsername))
					table.insert(successful_sets, "CHAPUsername")
				end
				request_data.iSCSIBoot.CHAPUsername = nil
			end
			if type(request_data.iSCSIBoot.CHAPSecret) ~= "nil" then
				if type(request_data.iSCSIBoot.CHAPSecret) ~= "string" then
					table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/iSCSIBoot/CHAPSecret"}, {tostring(request_data.iSCSIBoot.CHAPSecret) .. "(" .. type(request_data.iSCSIBoot.CHAPSecret) .. ")", "CHAPSecret"}))
				else
					pl:set(prefix .. ":iSCSIBoot:CHAPSecret", tostring(request_data.iSCSIBoot.CHAPSecret))
					table.insert(successful_sets, "CHAPSecret")
				end
				request_data.iSCSIBoot.CHAPSecret = nil
			end
			if type(request_data.iSCSIBoot.MutualCHAPUsername) ~= "nil" then
				if type(request_data.iSCSIBoot.MutualCHAPUsername) ~= "string" then
					table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/iSCSIBoot/MutualCHAPUsername"}, {tostring(request_data.iSCSIBoot.MutualCHAPUsername) .. "(" .. type(request_data.iSCSIBoot.MutualCHAPUsername) .. ")", "MutualCHAPUsername"}))
				else
					pl:set(prefix .. ":iSCSIBoot:MutualCHAPUsername", tostring(request_data.iSCSIBoot.MutualCHAPUsername))
					table.insert(successful_sets, "MutualCHAPUsername")
				end
				request_data.iSCSIBoot.MutualCHAPUsername = nil
			end
			if type(request_data.iSCSIBoot.MutualCHAPSecret) ~= "nil" then
				if type(request_data.iSCSIBoot.MutualCHAPSecret) ~= "string" then
					table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/iSCSIBoot/MutualCHAPSecret"}, {tostring(request_data.iSCSIBoot.MutualCHAPSecret) .. "(" .. type(request_data.iSCSIBoot.MutualCHAPSecret) .. ")", "MutualCHAPSecret"}))
				else
					pl:set(prefix .. ":iSCSIBoot:MutualCHAPSecret", tostring(request_data.iSCSIBoot.MutualCHAPSecret))
					table.insert(successful_sets, "MutualCHAPSecret")
				end
				request_data.iSCSIBoot.MutualCHAPSecret = nil
			end
			request_data.iSCSIBoot = nil
		end
		if type(request_data.FibreChannel) ~= "nil" then
			if type(request_data.FibreChannel.WWPN) ~= "nil" then
				if type(request_data.FibreChannel.WWPN) ~= "string" then
					table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/FibreChannel/WWPN"}, {tostring(request_data.FibreChannel.WWPN) .. "(" .. type(request_data.FibreChannel.WWPN) .. ")", "WWPN"}))
				else
					pl:set(prefix .. ":FibreChannel:WWPN", tostring(request_data.FibreChannel.WWPN))
					table.insert(successful_sets, "WWPN")
				end
				request_data.FibreChannel.WWPN = nil
			end
			if type(request_data.FibreChannel.WWNN) ~= "nil" then
				if type(request_data.FibreChannel.WWNN) ~= "string" then
					table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/FibreChannel/WWNN"}, {tostring(request_data.FibreChannel.WWNN) .. "(" .. type(request_data.FibreChannel.WWNN) .. ")", "WWNN"}))
				else
					pl:set(prefix .. ":FibreChannel:WWNN", tostring(request_data.FibreChannel.WWNN))
					table.insert(successful_sets, "WWNN")
				end
				request_data.FibreChannel.WWNN = nil
			end
			if type(request_data.FibreChannel.WWNSource) ~= "nil" then
				local FibreChannel_WWNSource = FibreChannel_WWNSource_allowable_vals
				if type(request_data.FibreChannel.WWNSource) ~= "string" then
					table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/FibreChannel/WWNSource"}, {tostring(request_data.FibreChannel.WWNSource) .. "(" .. type(request_data.FibreChannel.WWNSource) .. ")", "WWNSource"}))
				elseif turbo.util.is_in(request_data.FibreChannel.WWNSource, FibreChannel_WWNSource) == nil then
					table.insert(extended, self:create_message("Base", "PropertyValueNotInList", {"#/FibreChannel/WWNSource"}, {request_data.FibreChannel.WWNSource, "WWNSource"}))
				else
					pl:set(prefix .. ":FibreChannel:WWNSource", tostring(request_data.FibreChannel.WWNSource))
					table.insert(successful_sets, "WWNSource")
				end
				request_data.FibreChannel.WWNSource = nil
			end
			if type(request_data.FibreChannel.FCoELocalVLANId) ~= "nil" then
				if type(request_data.FibreChannel.FCoELocalVLANId) ~= "number" then
					table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/FibreChannel/FCoELocalVLANId"}, {tostring(request_data.FibreChannel.FCoELocalVLANId) .. "(" .. type(request_data.FibreChannel.FCoELocalVLANId) .. ")", "FCoELocalVLANId"}))
				else
					pl:set(prefix .. ":FibreChannel:FCoELocalVLANId", tostring(request_data.FibreChannel.FCoELocalVLANId))
					table.insert(successful_sets, "FCoELocalVLANId")
				end
				request_data.FibreChannel.FCoELocalVLANId = nil
			end
			if type(request_data.FibreChannel.AllowFIPVLANDiscovery) ~= "nil" then
				if type(request_data.FibreChannel.AllowFIPVLANDiscovery) ~= "boolean" then
					table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/FibreChannel/AllowFIPVLANDiscovery"}, {tostring(request_data.FibreChannel.AllowFIPVLANDiscovery) .. "(" .. type(request_data.FibreChannel.AllowFIPVLANDiscovery) .. ")", "AllowFIPVLANDiscovery"}))
				else
					pl:set(prefix .. ":FibreChannel:AllowFIPVLANDiscovery", tostring(request_data.FibreChannel.AllowFIPVLANDiscovery))
					table.insert(successful_sets, "AllowFIPVLANDiscovery")
				end
				request_data.FibreChannel.AllowFIPVLANDiscovery = nil
			end
			if type(request_data.FibreChannel.BootTargets) ~= "nil" then
				if type(request_data.FibreChannel.BootTargets) == "table" then
					local zcard_response = yield(redis:zcard(prefix .. ":BootTargets:SortedIDs"))
					local FibreChannel_BootTargets = yield(redis:zrange(prefix .. ":FibreChannel:BootTargets:SortedIDs", 0, zcard_response - 1))

					for boot_targets_index, boot_targets in pairs(request_data.FibreChannel.BootTargets) do
						-- Traverse array elements
						for _index, entry in pairs(boot_targets) do
							-- Set key and value for BootTargets
							local boot_target_redis_key = prefix .. ":FibreChannel:BootTargets:" .. tostring(boot_targets_index) .. ":" .. tostring(_index)
								pl:del(boot_target_redis_key)
								pl:set(boot_target_redis_key, tostring(entry))
								pl:zadd(prefix .. ":BootTargets:SortedIDs", _index, boot_target_redis_key)
						end
					end
				end
				request_data.FibreChannel.BootTargets = nil
			end
			request_data.FibreChannel = nil
		end
		if type(request_data.BootMode) ~= "nil" then
			local BootMode = BootMode_allowable_vals
			if type(request_data.BootMode) ~= "string" then
				table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/BootMode"}, {tostring(request_data.BootMode) .. "(" .. type(request_data.BootMode) .. ")", "BootMode"}))
			elseif turbo.util.is_in(request_data.BootMode, BootMode) == nil then
				table.insert(extended, self:create_message("Base", "PropertyValueNotInList", {"#/BootMode"}, {request_data.BootMode, "BootMode"}))
			else
				pl:set(prefix .. ":BootMode", tostring(request_data.BootMode))
				table.insert(successful_sets, "BootMode")
			end
			request_data.BootMode = nil
		end
		response = self:oem_extend(response, "patch.networkdevicefunction-instance")
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
return NetworkDeviceFunctionInstanceHandler
