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
-- [See "turboredis.lua"](https://github.com/enotodden/turboredis)
local db_utils = require("turboredis.util")

local EthernetInterfaceHandler = class("EthernetInterfaceHandler", RedfishHandler)

local yield = coroutine.yield

-- Set the path names for ethernet interface OEM extensions
local collection_oem_path = "manager.manager-ethernetinterface-collection"
local instance_oem_path = "manager.manager-ethernetinterface-instance"
local link_oem_path = "manager.manager-ethernetinterface-instance-links"
EthernetInterfaceHandler:set_all_oem_paths(collection_oem_path, instance_oem_path, nil, nil, link_oem_path)

-- ### Commonly used data:
-- The 'property_access' table specifies read/write permission for all properties.
local property_access = require("property-access.EthernetInterface")["EthernetInterface"]

-- ### GET request handler for Manager/EthernetInterface
function EthernetInterfaceHandler:get(_manager_id, id, sd)

	local response = {}
	
	-- Create the GET response for Ethernet Interface collection or instance, based on what 'id' was given.
	if id == nil then
		self:get_collection(response)
	elseif sd ~= nil then
		-- TODO: DEPRECATED: PATCH, PUT, DELETE not currently accepted for Ethernet Settings
		self:set_allow_header("POST")
		self:error_method_not_allowed()
	else
		self:get_instance(response)
	end

	-- After the response is created, we register it with the handler and then output it to the client.
	self:set_response(response)

	self:output()
end
-- TODO: REMOVE EthernetInterfaceHandler:applySettingsObject()!!!!!!!!!!!
-- ### PATCH request handler for Manager/EthernetInterface
function EthernetInterfaceHandler:patch(_manager_id, id, sd)

	local response = {}

	-- Check Redis for the presence of the Manager resource in question. If it isn't found, throw a 404
	local redis = self:get_db()

	-- Create the PATCH response for Ethernet Interface collection, instance, or settings object, based on what 'id' was given.
	if id == nil then
		-- Allow an OEM patch handler for manager eth ifc collections, if none exists, return with the normal 405 response
		self:set_header("Allow", "GET")
		self:set_status(405)

		response = self:oem_extend(response, "patch." .. self:get_oem_collection_path())

		if self:get_status() == 405 then
			self:error_method_not_allowed()
		end
	else
		-- Check Redis for the presence of the EthIfc object in question. If it isn't found, throw a 404
		if self:resourceExists() then
			-- Check if user is authorized to make changes.
			if self:can_user_do("ConfigureManager") == true then
				-- If so, patch the resource.
				self:patch_instance(response)
				-- If there were invalid properties in the POST request, return a 400 Bad Request code and extended error response
				if response["@Message.ExtendedInfo"] then
					self:add_error_body(response, 400, unpack(response["@Message.ExtendedInfo"]))
					response["@Message.ExtendedInfo"] = nil
				elseif response.NOCHANGE then
					print("ETH IFC PATCH NO CHANGE")
					self:set_status(204)
					response = {}
				else
					self:set_status(204)
					self:applySettingsObject()
				end
			else
				--Throw an error if the user is not authorized.
				self:error_insufficient_privilege()
			end
		else
			self:error_resource_missing_at_uri()
		end
	end

	-- After the response is created, we register it with the handler and then output it to the client.
	self:set_response(response)

	self:output()
end

-- ### PUT request handler for Manager/EthernetInterface
function EthernetInterfaceHandler:put(_manager_id, id, sd)

	local response = {}

	-- Check Redis for the presence of the Manager resource in question. If it isn't found, throw a 404
	local redis = self:get_db()
	local man_exists = yield(redis:exists("Redfish:Managers:".._manager_id..":ManagerType"))
	if man_exists == 0 then
		self:error_resource_missing_at_uri()
	end
	
	-- Create the PUT response for Ethernet Interface collection, instance, or settings object, based on what 'id' was given.
	if id == nil then
		-- When an HTTP method is rejected with status code 405, we must set an Allow header that lists valid HTTP methods for the URI
	    self:set_header("Allow", "GET")
		-- No PUT for collections
	    self:error_method_not_allowed()
	elseif sd ~= nil then
		-- Check Redis for the presence of the EthIfc object in question. If it isn't found, throw a 404
		if self:resourceExists() then
			-- Check if user is authorized to make changes.
			if self:can_user_do("ConfigureManager") == true then
				-- If so, replace the resource and respond with the updated version.
				self:put_settings(response)
				--self:get_instance(response)
				--self:applySettingsObject()
			else
				--Throw an error if the user is not authorized.
				self:error_insufficient_privilege()
			end
		else
			self:error_resource_missing_at_uri()
		end
	else
		if self:resourceExists() then
			-- When an HTTP method is rejected with status code 405, we must set an Allow header that lists valid HTTP methods for the URI
			self:set_header("Allow", "GET, PATCH")
			self:error_method_not_allowed()
		else
			self:error_resource_missing_at_uri()
		end
	end

	-- After the response is created, we register it with the handler and then output it to the client.
	self:set_response(response)

	self:output()
end

-- ### POST request handler for Manager/EthernetInterface
function EthernetInterfaceHandler:post(_manager_id, id, sd)

	local response = {}

	-- Check Redis for the presence of the Manager resource in question. If it isn't found, throw a 404
	local redis = self:get_db()
	local man_exists = yield(redis:exists("Redfish:Managers:".._manager_id..":ResourceExists"))
	if man_exists == 0 then
		self:error_resource_missing_at_uri()
	end
	
	-- Create the POST response for Ethernet Interface collection, instance, or settings object, based on what 'id' was given.
	if id == nil then
		-- When an HTTP method is rejected with status code 405, we must set an Allow header that lists valid HTTP methods for the URI
	    self:set_header("Allow", "GET")
		-- There is no collection for Ethernet Internet Settings objects
	    self:error_method_not_allowed()
	elseif sd ~= nil then
		-- Check Redis for the presence of the EthIfc object in question. If it isn't found, throw a 404
		if self:resourceExists() then
			-- Check if user is authorized to make changes.
			if self:can_user_do("ConfigureManager") == true then
				-- Attempt to create the resource.
				self:post_settings(response)
				-- If there were invalid properties in the POST request, return a 400 Bad Request code and extended error response
				if response["@Message.ExtendedInfo"] then
					self:add_error_body(response, 400, unpack(response["@Message.ExtendedInfo"]))
					response["@Message.ExtendedInfo"] = nil
				else
					local prefix = "Redfish:Managers:".._manager_id..":EthernetInterfaces:"..id..":"..sd
					self:set_status(204)
					self:applySettingsObject()
				end
			else
				--Throw an error if the user is not authorized.
				self:error_insufficient_privilege()
			end
		else
			self:error_resource_missing_at_uri()
		end
	else
		if self:resourceExists() then
			-- When an HTTP method is rejected with status code 405, we must set an Allow header that lists valid HTTP methods for the URI
			self:set_header("Allow", "GET, PATCH")
			self:error_method_not_allowed()
		else
			self:error_resource_missing_at_uri()
		end
	end

	-- After the response is created, we register it with the handler and then output it to the client.
	self:set_response(response)
	
	self:output()
end

-- ### DELETE request handler for Manager/EthernetInterface
function EthernetInterfaceHandler:delete(_manager_id, id, sd)

	local response = {}

	-- Check Redis for the presence of the Manager resource in question. If it isn't found, throw a 404
	local redis = self:get_db()
	local man_exists = yield(redis:exists("Redfish:Managers:".._manager_id..":ManagerType"))
	if man_exists == 0 then
		self:error_resource_missing_at_uri()
	end
	
	-- Create the DELETE response for Ethernet Interface collection, instance, or settings object, based on what 'id' was given.
	if id == nil then
		-- When an HTTP method is rejected with status code 405, we must set an Allow header that lists valid HTTP methods for the URI
	    self:set_header("Allow", "GET")
		-- No DELETE for collections
	    self:error_method_not_allowed()
	elseif sd ~= nil then
		-- Check Redis for the presence of the EthIfc object in question. If it isn't found, throw a 404
		if self:resourceExists() then
			-- Check if user is authorized to make changes.
			if self:can_user_do("ConfigureManager") == true then
				-- If so, delete the resource and respond with the resource that was just deleted.
				--self:get_instance(response)
				self:delete_settings(response)
			else
				--Throw an error if the user is not authorized.
				self:error_insufficient_privilege()
			end
		else
			self:error_resource_missing_at_uri()
		end
	else
		if self:resourceExists() then
			-- When an HTTP method is rejected with status code 405, we must set an Allow header that lists valid HTTP methods for the URI
			self:set_header("Allow", "GET, PATCH")
			self:error_method_not_allowed()
		else
			self:error_resource_missing_at_uri()
		end
	end

	-- After the response is created, we register it with the handler and then output it to the client.
	self:set_response(response)

	self:output()
end

-- #### GET handler for Ethernet Interfaces collection
function EthernetInterfaceHandler:get_collection(response)
	-- Before proceeding with the handler, we'll make sure the collection request is valid
	local collection_exists = self:parent_exists()
	self:assertTrue_404(collection_exists)

	-- Set up the local space: get a connection with Redis DB, gather url segment, establish redis prefix, and set scope
	local redis = self:get_db()

	local collection, instance, secondary_collection = self.url_segments[1], self.url_segments[2], self.url_segments[3];

	local prefix = "Redfish:Managers:"..instance..":EthernetInterfaces:"

	self:set_scope("Redfish:"..table.concat(self.url_segments,':'))

	-- Fill in Name and Description fields
	response["Name"] = "Ethernet Network Interface Collection"
	response["Description"] = "Collection of Ethernet Interfaces for this Manager"

	-- Search Redis for any Ethernet Interfaces, filter out any Ethernet Interface Settings objects, and pack the results into an odata link collections
	local key_array = yield(redis:keys(prefix.."*:MACAddress"))
	key_array = _.reject(key_array, function(key) return key:sub(-14) == ":SD:MACAddress" end)
	local odataIDs = utils.getODataIDArray(key_array, 1)

	-- Set Members fields based on results from Redis
	response["Members@odata.count"] = #odataIDs
	response["Members"] = odataIDs
	
	-- Add OEM extension properties to the response
	response = self:oem_extend(response, "query." .. self:get_oem_collection_path())

	-- Set the OData context and type for the response
	self:set_context(CONSTANTS.ETHERNET_INTERFACE_COLLECTION_CONTEXT)

	self:set_type(CONSTANTS.ETHERNET_INTERFACE_COLLECTION_TYPE)

	-- GET requests must respond with the 'Allow' header specifying what methods are available for the given URL
	self:set_allow_header("GET")
end
	
-- #### GET handler for Ethernet Interface instance
function EthernetInterfaceHandler:get_instance(response)
	-- Set up the local space: get a connection with Redis DB, gather url segment, establish redis prefix, and set scope
	local redis = self:get_db()

	local collection, instance, secondary_collection, id =
		self.url_segments[1], self.url_segments[2], self.url_segments[3], self.url_segments[4];

	local prefix = "Redfish:Managers:"..instance..":EthernetInterfaces:"..id
	
	self:set_scope("Redfish:"..table.concat(self.url_segments,':'))

	-- Create a Redis pipeline and add commands for all Ethernet Interface properties
	local pl = redis:pipeline()

	pl:mget({
			prefix..":Name",
			prefix..":Description",
			prefix..":PermanentMACAddress",
			prefix..":MACAddress",
			prefix..":SpeedMbps",
			prefix..":AutoNeg",
			prefix..":FullDuplex",
			prefix..":MTUSize",
			prefix..":HostName",
			prefix..":FQDN",
			prefix..":MaxIPv6StaticAddresses",
			prefix..":IPv6DefaultGateway",
			prefix..":InterfaceEnabled",
			prefix..":UefiDevicePath",
			})
	pl:hmget(prefix..":Status", "State", "Health")
	pl:hmget(prefix..":VLAN", "VLANEnable", "VLANId")
	pl:hgetall(prefix..":IPv4Addresses")
	pl:hgetall(prefix..":IPv6AddressPolicyTable")
	pl:hgetall(prefix..":IPv6StaticAddresses")
	pl:hgetall(prefix..":IPv6Addresses")
	pl:smembers(prefix..":NameServers")
	-- Run the Redis pipeline, then unpack the results  
	local db_result = yield(pl:run())

	-- Check that data was found in Redis, if not we throw a 404 NOT FOUND
	self:assert_resource(db_result)

	local general, status, vlan, ipv4_list, ipv6_policy_list, ipv6_static_list, ipv6_addr_list, dns = unpack(db_result)
	-- Add the data from Redis into the response, converting types where necessary
	response["Id"] = id
	response["Name"] = general[1]
	response["Description"] = general[2]
	response["PermanentMACAddress"] = general[3]
	response["MACAddress"] = general[4]
	response["SpeedMbps"] = tonumber(general[5])
	if type(general[6]) ~= "nil" then
		response["AutoNeg"] = utils.bool(general[6])
	end
	if type(general[7]) ~= "nil" then
		response["FullDuplex"] = utils.bool(general[7])
	end
	response["MTUSize"] = tonumber(general[8])
	response["HostName"] = general[9]
	response["FQDN"] = general[10]
	response["MaxIPv6StaticAddresses"] = tonumber(general[11])
	response["IPv6DefaultGateway"] = general[12]
	if type(general[13]) ~= "nil" then
		response["InterfaceEnabled"] = utils.bool(general[13])
	end
	response["UefiDevicePath"] = general[14]
	if status[1] or status[2] then
		response["Status"] = {
			State = general[13] and "Enabled" or "Disabled",
			Health = status[2]
		}
	end
	if type(vlan[1]) ~= "nil" then
		response["VLAN"] = {
			VLANEnable = utils.bool(vlan[1]),
			VLANId = tonumber(vlan[2])
		}
	end
	if ipv4_list[1] then
		response["IPv4Addresses"] = utils.convertHashListToArray(db_utils.from_kvlist(ipv4_list))
	end
	if ipv6_policy_list[1] then
		response["IPv6AddressPolicyTable"] = utils.convertHashListToArray(db_utils.from_kvlist(ipv6_policy_list))
	end
	if ipv6_static_list[1] then
		response["IPv6StaticAddresses"] = utils.convertHashListToArray(db_utils.from_kvlist(ipv6_static_list))
	end
	if ipv6_addr_list[1] then
		response["IPv6Addresses"] = utils.convertHashListToArray(db_utils.from_kvlist(ipv6_addr_list))
	end
	if dns[1] then
		response["NameServers"] = dns
	end

	-- TODO: Settings object and POST handler being deprecated in favor of normal PATCH paradigm
	-- -- Ethernet Instances use the Redfish Settings Object
	-- if sd == nil and self:resourceExists() then
	-- 	response["@Redfish.Settings"] = {}
	-- 	local settings_time = yield(redis:get(prefix..":SD:LastModified"))
	-- 	local settings_msgs = yield(redis:hgetall(prefix..":SettingsMessages"))
	-- 	if settings_time then
	-- 		response["@Redfish.Settings"].Time = tostring(settings_time)
	-- 		response["@Redfish.Settings"].ETag = "W/\"" .. tostring(settings_time) .. "\""
	-- 	end
	-- 	if settings_msgs then
	-- 		response["@Redfish.Settings"]["Messages"] = settings_msgs
	-- 	end
	-- 	response["@Redfish.Settings"]["@odata.type"] = "#Settings."..CONFIG.REDFISH_VERSION..".Settings"
	-- 	response["@Redfish.Settings"]["SettingsObject"] = response["@Redfish.Settings"]["SettingsObject"] or {}
	-- 	response["@Redfish.Settings"]["SettingsObject"]["@odata.id"] = CONFIG.SERVICE_PREFIX.."/"..collection.."/"..instance.."/EthernetInterfaces/"..id.."/SD"
	-- end
	-- Add OEM extension properties to the response
	response = self:oem_extend(response, "query." .. self:get_oem_instance_path())
	response["Links"] = self:oem_extend({}, "query." .. self:get_oem_instance_link_path())
	-- Set the OData context and type for the response
	local sL_table = _.keys(response)
	if #sL_table < 22 then
        local selectList = turbo.util.join(',', sL_table)
		self:set_context(CONSTANTS.ETHERNET_INTERFACE_INSTANCE_CONTEXT.."("..selectList..")")
	else
		self:set_context(CONSTANTS.ETHERNET_INTERFACE_INSTANCE_CONTEXT)
	end

	self:set_type(CONSTANTS.ETHERNET_INTERFACE_TYPE)
	-- Remove extraneous fields from the response
	utils.remove_nils(response)

	-- GET requests must respond with the 'Allow' header specifying what methods are available for the given URL
	if sd then
		self:set_allow_header("POST")
	else
		self:set_allow_header("GET, PATCH")
	end
end

    -- The 'edit_operations' table holds functions that know how to edit each property.
	-- For each property, validate the value, then create an error message or add appropriate Redis command based on outcome.
local edit_operations = {
	["InterfaceEnabled"] = function(pipe, prefix, value, extended, successful_sets)
		if type(value) ~= "boolean" then
			table.insert(extended, EthernetInterfaceHandler:create_message("Base", "PropertyValueTypeError", {"#/InterfaceEnabled"}, {tostring(value), "InterfaceEnabled"}))
		else
			pipe:set(prefix..":InterfaceEnabled", tostring(value))
			table.insert(successful_sets, prefix..":InterfaceEnabled")
		end
	end,
	["MACAddress"] = function(pipe, prefix, value, extended, successful_sets)
		if type(value) ~= "string" then
			table.insert(extended, EthernetInterfaceHandler:create_message("Base", "PropertyValueTypeError", {"#/MACAddress"}, {tostring(value), "MACAddress"}))
		elseif not string.match(value, "^[0-9A-Fa-f][0-9A-Fa-f][:-][0-9A-Fa-f][0-9A-Fa-f][:-][0-9A-Fa-f][0-9A-Fa-f][:-][0-9A-Fa-f][0-9A-Fa-f][:-][0-9A-Fa-f][0-9A-Fa-f][:-][0-9A-Fa-f][0-9A-Fa-f]$") then
			table.insert(extended, EthernetInterfaceHandler:create_message("Base", "PropertyValueFormatError", {"#/MACAddress"}, {tostring(value), "MACAddress"}))
		else
			pipe:set(prefix..":MACAddress", tostring(value))
			table.insert(successful_sets, prefix..":MACAddress")
		end
	end,
	["SpeedMbps"] = function(pipe, prefix, value, extended, successful_sets)
		if type(value) ~= "number" then
			table.insert(extended, EthernetInterfaceHandler:create_message("Base", "PropertyValueTypeError", {"#/SpeedMbps"}, {tostring(value), "SpeedMbps"}))
		else
			pipe:set(prefix..":SpeedMbps", tostring(value))
			table.insert(successful_sets, prefix..":SpeedMbps")
		end
	end,
	["AutoNeg"] = function(pipe, prefix, value, extended, successful_sets)
		if type(value) ~= "boolean" then
			table.insert(extended, EthernetInterfaceHandler:create_message("Base", "PropertyValueTypeError", {"#/AutoNeg"}, {tostring(value), "AutoNeg"}))
		else
			pipe:set(prefix..":AutoNeg", tostring(value))
			table.insert(successful_sets, prefix..":AutoNeg")
		end
	end,
	["FullDuplex"] = function(pipe, prefix, value, extended, successful_sets)
		if type(value) ~= "boolean" then
			table.insert(extended, EthernetInterfaceHandler:create_message("Base", "PropertyValueTypeError", {"#/FullDuplex"}, {tostring(value), "FullDuplex"}))
		else
			pipe:set(prefix..":FullDuplex", tostring(value))
			table.insert(successful_sets, prefix..":FullDuplex")
		end
	end,
	["MTUSize"] = function(pipe, prefix, value, extended, successful_sets)
		if type(value) ~= "number" then
			table.insert(extended, EthernetInterfaceHandler:create_message("Base", "PropertyValueTypeError", {"#/MTUSize"}, {tostring(value), "MTUSize"}))
		else
			pipe:set(prefix..":MTUSize", tostring(value))
			table.insert(successful_sets, prefix..":MTUSize")
		end
	end,
	["HostName"] = function(pipe, prefix, value, extended, successful_sets)
		if type(value) ~= "string" then
			table.insert(extended, EthernetInterfaceHandler:create_message("Base", "PropertyValueTypeError", {"#/HostName"}, {tostring(value), "HostName"}))
		else
			pipe:set(prefix..":HostName", tostring(value))
			table.insert(successful_sets, prefix..":HostName")
		end
	end,
	["FQDN"] = function(pipe, prefix, value, extended, successful_sets)
		if type(value) ~= "string" then
			table.insert(extended, EthernetInterfaceHandler:create_message("Base", "PropertyValueTypeError", {"#/FQDN"}, {tostring(value), "FQDN"}))
		else
			pipe:set(prefix..":FQDN", tostring(value))
			table.insert(successful_sets, prefix..":FQDN")
		end
	end,
	["NameServers"] = function(pipe, prefix, value, extended, successful_sets)
		-- Purge old NameServers list
		local res = pipe:del(prefix..":NameServers")
		-- Replace with new NameServers list
		for i, v in ipairs(value) do
			local ListMember = "NameServers/"..i
			if type(v) ~= "string" then
				table.insert(extended, EthernetInterfaceHandler:create_message("Base", "PropertyValueTypeError", {"#/"..ListMember}, {tostring(v), ListMember}))
			else
				pipe:sadd(prefix .. ":NameServers", v)
				table.insert(successful_sets, prefix .. ":NameServers:" .. i)
			end
		end
	end,
	["VLAN"] = function(pipe, prefix, value, extended, successful_sets)
		if type(value.VLANEnable) ~= "boolean" then
			table.insert(extended, EthernetInterfaceHandler:create_message("Base", "PropertyValueTypeError", {"#/VLAN/VLANEnable"}, {tostring(value.VLANEnable), "VLAN/VLANEnable"}))
		else
			pipe:hset(prefix..":VLAN", "VLANEnable", tostring(value.VLANEnable))
			table.insert(successful_sets, prefix..":VLAN:VLANEnable")
		end

		if type(value.VLANId) ~= "number" then
			table.insert(extended, EthernetInterfaceHandler:create_message("Base", "PropertyValueTypeError", {"#/VLAN/VLANId"}, {tostring(value.VLANId), "VLAN/VLANId"}))
		else
			pipe:hset(prefix..":VLAN", "VLANId", tostring(value.VLANId))
			table.insert(successful_sets, prefix..":VLAN:VLANId")
		end
	end,
	["IPv6AddressPolicyTable"] = function(pipe, prefix, value, extended, successful_sets)
		-- Purge old policy table
		local res = pipe:del(prefix..":IPv6AddressPolicyTable")
		-- Replace with policy table with new settings
		for i, v in ipairs(value) do
			local TableEntry = "IPv6AddressPolicyTable/"..i
			if v.Prefix ~= nil then
				if type(v.Prefix) ~= "string" then
					table.insert(extended, EthernetInterfaceHandler:create_message("Base", "PropertyValueTypeError", {"#/"..TableEntry.."/Prefix"}, {tostring(v.Prefix), TableEntry.."/Prefix"}))
				else
					pipe:hset(prefix .. ":IPv6AddressPolicyTable", i .. ":Prefix", v.Prefix)
					table.insert(successful_sets, prefix .. ":IPv6AddressPolicyTable:" .. i .. ":Prefix")
				end
			end

			if v.Precedence ~= nil then
				if type(v.Precedence) ~= "number" then
					table.insert(extended, EthernetInterfaceHandler:create_message("Base", "PropertyValueTypeError", {"#/"..TableEntry.."/Precedence"}, {tostring(v.Precedence), TableEntry.."/Precedence"}))
				elseif v.Precedence < 1 or v.Precedence > 100 then
					table.insert(extended, EthernetInterfaceHandler:create_message("Base", "PropertyValueNotInList", {"#/"..TableEntry.."/Precedence"}, {tostring(v.Precedence), TableEntry.."/Precedence"}))
				else
					pipe:hset(prefix .. ":IPv6AddressPolicyTable", i .. ":Precedence", v.Precedence)
					table.insert(successful_sets, prefix .. ":IPv6AddressPolicyTable:" .. i .. ":Precedence")
				end
			end

			if v.Label ~= nil then
				if type(v.Label) ~= "number" then
					table.insert(extended, EthernetInterfaceHandler:create_message("Base", "PropertyValueTypeError", {"#/"..TableEntry.."/Label"}, {tostring(v.Label), TableEntry.."/Label"}))
				elseif v.Label < 0 or v.Label > 100 then
					table.insert(extended, EthernetInterfaceHandler:create_message("Base", "PropertyValueNotInList", {"#/"..TableEntry.."/Label"}, {tostring(v.Label), TableEntry.."/Label"}))
				else
					pipe:hset(prefix .. ":IPv6AddressPolicyTable", i .. ":Label", v.Label)
					table.insert(successful_sets, prefix .. ":IPv6AddressPolicyTable:" .. i .. ":Label")
				end
			end
		end
	end,
	["IPv4Addresses"] = function(pipe, prefix, value, extended, successful_sets)
		-- Purge old address array
		local res = pipe:del(prefix..":IPv4Addresses")
		-- Replace with address array with new settings
		for i, v in ipairs(value) do
			local ArrayMember = "IPv4Addresses/"..i
			if v.Address ~= nil then
				if type(v.Address) ~= "string" then
					table.insert(extended, EthernetInterfaceHandler:create_message("Base", "PropertyValueTypeError", {"#/"..ArrayMember.."/Address"}, {tostring(v.Address), ArrayMember.."/Address"}))
				elseif not string.match(v.Address, "^%d?%d?%d%.%d?%d?%d.%d?%d?%d.%d?%d?%d$") then
					table.insert(extended, EthernetInterfaceHandler:create_message("Base", "PropertyValueFormatError", {"#/"..ArrayMember.."/Address"}, {tostring(v.Address), ArrayMember.."/Address"}))
				else
					pipe:hset(prefix .. ":IPv4Addresses", i .. ":Address", v.Address)
					table.insert(successful_sets, prefix .. ":IPv4Addresses:" .. i .. ":Address")
				end
			end

			if v.SubnetMask ~= nil then
				if type(v.SubnetMask) ~= "string" then
					table.insert(extended, EthernetInterfaceHandler:create_message("Base", "PropertyValueTypeError", {"#/"..ArrayMember.."/SubnetMask"}, {tostring(v.SubnetMask), ArrayMember.."/SubnetMask"}))
				elseif not string.match(v.SubnetMask, "^%d?%d?%d%.%d?%d?%d.%d?%d?%d.%d?%d?%d$") then
					table.insert(extended, EthernetInterfaceHandler:create_message("Base", "PropertyValueFormatError", {"#/"..ArrayMember.."/SubnetMask"}, {tostring(v.SubnetMask), ArrayMember.."/SubnetMask"}))
				else
					pipe:hset(prefix .. ":IPv4Addresses", i .. ":SubnetMask", v.SubnetMask)
					table.insert(successful_sets, prefix .. ":IPv4Addresses:" .. i .. ":SubnetMask")
				end
			end

			if v.Gateway ~= nil then
				if type(v.Gateway) ~= "string" then
					table.insert(extended, EthernetInterfaceHandler:create_message("Base", "PropertyValueTypeError", {"#/"..ArrayMember.."/Gateway"}, {tostring(v.Gateway), ArrayMember.."/Gateway"}))
				else
					pipe:hset(prefix .. ":IPv4Addresses", i .. ":Gateway", v.Gateway)
					table.insert(successful_sets, prefix .. ":IPv4Addresses:" .. i .. ":Gateway")
				end
			end

			if v.AddressOrigin ~= nil then
				if type(v.AddressOrigin) ~= "string" then
					table.insert(extended, EthernetInterfaceHandler:create_message("Base", "PropertyValueTypeError", {"#/IPv4Addresses/"..i.."/AddressOrigin"}, {tostring(v.AddressOrigin), "IPv4Addresses/"..i.."/AddressOrigin"}))
				else
					pipe:hset(prefix .. ":IPv4Addresses", i .. ":AddressOrigin", v.AddressOrigin)
					table.insert(successful_sets, prefix .. ":IPv4Addresses:" .. i .. ":AddressOrigin")
				end
			end
		end
	end,
    ["IPv6Addresses"] = function(pipe, prefix, value, extended, successful_sets)
		-- Purge old address array
		local res = pipe:del(prefix..":IPv6Addresses") print("mod ip6 address")
		-- Replace with address array with new settings
		for i, v in ipairs(value) do print(i,v)
			if v.Address ~= nil then
				if type(v.Address) ~= "string" then
					table.insert(extended, EthernetInterfaceHandler:create_message("Base", "PropertyValueTypeError", {"#/IPv6Addresses/"..i.."/Address"}, {tostring(v.Address), "IPv6Addresses/"..i.."/Address"}))
				else
					pipe:hset(prefix .. ":IPv6Addresses", i .. ":Address", v.Address)
					table.insert(successful_sets, prefix .. ":IPv6Addresses:" .. i .. ":Address")
				end
			end

			if v.AddressOrigin ~= nil then
				if type(v.AddressOrigin) ~= "string" then
					table.insert(extended, EthernetInterfaceHandler:create_message("Base", "PropertyValueTypeError", {"#/IPv6Addresses/"..i.."/AddressOrigin"}, {tostring(v.AddressOrigin), "IPv6Addresses/"..i.."/AddressOrigin"}))
				else
					pipe:hset(prefix .. ":IPv6Addresses", i .. ":AddressOrigin", v.AddressOrigin)
					table.insert(successful_sets, prefix .. ":IPv6Addresses:" .. i .. ":AddressOrigin")
				end
			end

			if v.AddressState ~= nil then
				if type(v.AddressState) ~= "string" then
					table.insert(extended, EthernetInterfaceHandler:create_message("Base", "PropertyValueTypeError", {"#/IPv6Addresses/"..i.."/AddressState"}, {tostring(v.AddressState), "IPv6Addresses/"..i.."/AddressState"}))
				else
					pipe:hset(prefix .. ":IPv6Addresses", i .. ":AddressState", v.AddressState)
					table.insert(successful_sets, prefix .. ":IPv6Addresses:" .. i .. ":AddressState")
				end
			end

			if v.PrefixLength ~= nil then
				if type(v.PrefixLength) ~= "number" then
					table.insert(extended, EthernetInterfaceHandler:create_message("Base", "PropertyValueTypeError", {"#/IPv6Addresses/"..i.."/PrefixLength"}, {tostring(v.PrefixLength), "IPv6Addresses/"..i.."/PrefixLength"}))
				else
					pipe:hset(prefix .. ":IPv6Addresses", i .. ":PrefixLength", v.PrefixLength)
					table.insert(successful_sets, prefix .. ":IPv6Addresses:" .. i .. ":PrefixLength")
				end
			end
		end
    end,
    ["IPv6StaticAddresses"] = function(pipe, prefix, value, extended, successful_sets)
		-- Purge old address array
		local res = pipe:del(prefix..":IPv6StaticAddresses") print("mod ip6 stat address")
		-- Replace with address array with new settings
		for i, v in ipairs(value) do print(i,v)
			if v.Address ~= nil then
				if type(v.Address) ~= "string" then
					table.insert(extended, EthernetInterfaceHandler:create_message("Base", "PropertyValueTypeError", {"#/IPv6StaticAddresses/"..i.."/Address"}, {tostring(v.Address), "IPv6StaticAddresses/"..i.."/Address"}))
				else
					pipe:hset(prefix .. ":IPv6StaticAddresses", i .. ":Address", v.Address)
					table.insert(successful_sets, prefix .. ":IPv6StaticAddresses:" .. i .. ":Address")
				end
			end

			if v.PrefixLength ~= nil then
				if type(v.PrefixLength) ~= "number" then
					table.insert(extended, EthernetInterfaceHandler:create_message("Base", "PropertyValueTypeError", {"#/IPv6StaticAddresses/"..i.."/PrefixLength"}, {tostring(v.PrefixLength), "IPv6StaticAddresses/"..i.."/PrefixLength"}))
				else
					pipe:hset(prefix .. ":IPv6StaticAddresses", i .. ":PrefixLength", v.PrefixLength)
					table.insert(successful_sets, prefix .. ":IPv6StaticAddresses:" .. i .. ":PrefixLength")
				end
			end
		end
	end
}

-- #### PATCH handler for Ethernet Interface instance
function EthernetInterfaceHandler:patch_instance(response)
	-- Set up the local space: get a connection with Redis DB, gather url segment, establish redis prefix, and set scope.
	local redis = self:get_db()

	local collection, instance, secondary_collection, id = 
		self.url_segments[1], self.url_segments[2], self.url_segments[3], self.url_segments[4];

	local prefix = "Redfish:Managers:"..instance..":EthernetInterfaces:"..id
	
	self:set_scope("Redfish:"..table.concat(self.url_segments,':'))

	-- check for null properties in request body
	local request_body = self:get_request().body
	local request_data_str, recursions = request_body:gsub("null", "\"666$NULLVALUEPROPERTY$666\"")
	local request_data = turbo.escape.json_decode(request_data_str)

	-- get current resource configuration
	local current_settings = {}
	self:get_instance(current_settings)

	print('request data')
	utils.ptr(request_data)
	print('current settings')
	utils.ptr(current_settings)

	-- merge request data and current settings
	local new_settings, settings_modified = utils.mergeWithNullProperties(request_data, current_settings)

	print('new settings')
	utils.ptr(new_settings)
	-- detect unknown properties in the request body
	local _ro
	local _wr
	local leftover_body
	_ro, _wr, leftover_body = utils.readonlyCheck(current_settings, property_access)

	local leftover_fields = utils.table_len(leftover_body)
	if leftover_fields ~= 0 and leftover_body ~= nil then
		local keys = _.keys(leftover_body)
		for k, v in pairs(keys) do
			table.insert(extended, self:create_message("Base", "PropertyUnknown", "#/" .. v, v))
		end
	end

	local pl = redis:pipeline()

	prefix = prefix .. ":SD"

	-- The 'extended' table will hold all of our "@Message.ExtendedInfo" errors that accumulate while making changes.
	local extended = {}
	local successful_sets = {}

	-- Add commands to pipeline as needed by referencing our 'edit_operations' table.
	for property, value in pairs(new_settings) do
		if edit_operations[property] then
			edit_operations[property](pl, prefix, value, extended, successful_sets)
		elseif request_data[property] then
			table.insert(extended, self:create_message("Base", "PropertyNotWritable", "#/"..property, tostring(property)))
		end
	end

	pl:mset({
		prefix..":ResourceExists", "true",
		prefix..":Name", current_settings.Name or "OData object to hold Ethernet Settings",
		prefix..":Description", current_settings.Description or "Ethernet Settings Object",
		prefix..":UefiDevicePath", current_settings.UefiDevicePath or "",
		prefix..":PermanentMACAddress", current_settings.PermanentMACAddress or "00:00:00:00:00:00",
		prefix..":MaxIPv6StaticAddresses", current_settings.MaxIPv6StaticAddresses or 1,
		prefix..":IPv6DefaultGateway", current_settings.IPv6DefaultGateway or "::",
		})
	if current_settings.Status then
		pl:hmset(prefix..":Status",
			"State", current_settings.Status.State or "Disabled",
			"HealthRollup", current_settings.Status.HealthRollup or "OK",
			"Health", current_settings.Status.Health or "OK"
		)
	end

	-- If we found invalid properties in a PATCH request, we return a 400 Bad Request, so database commands should be skipped
	if #extended ~= 0 then
		response["@Message.ExtendedInfo"] = extended
		pl:clear()
	elseif not settings_modified then
		pl:clear()
		response.NOCHANGE = true
	elseif #pl.pending_commands > 0 then
		-- Run any pending database commands.
		self:update_lastmodified(prefix, os.time(), pl, 1)
		local res = yield(pl:run())
		self:add_audit_log_entry(self:create_message("Security", "ResourceModified", nil, {"All", self:get_request().path}))
	end

	self:set_allow_header("GET, PATCH")
end

-- TODO: DEPRECATED
function EthernetInterfaceHandler:__patch_settings(response)
	-- Set up the local space: get a connection with Redis DB, gather url segment, establish redis prefix, and set scope.
	local redis = self:get_db()

	local collection, instance, secondary_collection, id = 
		self.url_segments[1], self.url_segments[2], self.url_segments[3], self.url_segments[4];

	local prefix = "Redfish:Managers:"..instance..":EthernetInterfaces:"..id..":SD"
	
	self:set_scope("Redfish:"..table.concat(self.url_segments,':'))

	local pl = redis:pipeline()

	-- Get the request body.
	local request_data = turbo.escape.json_decode(self:get_request().body)

    -- The 'extended' table will hold all of our "@Message.ExtendedInfo" errors that accumulate while making changes.
    local extended = {}
    local successful_sets = {}

	-- Split the request body into read-only and writable properties.
	local readonly_body
	local writable_body
	readonly_body, writable_body = utils.readonlyCheck(request_data, property_access)

	-- Add commands to pipeline as needed by referencing our 'edit_operations' table.
	if writable_body then
		for property, value in pairs(writable_body) do
			edit_operations[property](pl, prefix, value, extended, successful_sets)
		end
	end

	-- If the user attempts to PATCH read-only properties, respond with the proper error messages.
	if readonly_body then
		for property, value in pairs(readonly_body) do
			if type(value) == "table" then
		        for prop2, val2 in pairs(value) do
					table.insert(extended, self:create_message("Base", "PropertyNotWritable", "#/"..property.."/"..prop2, tostring(property.."/"..prop2)))
				end
			else
				table.insert(extended, self:create_message("Base", "PropertyNotWritable", "#/"..property, tostring(property)))
			end
		end
	end

	-- If we caught any errors along the way, add them to the response.
	if #extended ~= 0 then
		response["@Message.ExtendedInfo"] = extended
	end

	-- Run any pending database commands.
	if #pl.pending_commands > 0 then
		self:update_lastmodified(prefix, os.time(), pl, 1)
		local res = yield(pl:run())
		self:add_audit_log_entry(self:create_message("Security", "ResourceModified", nil, {turbo.util.join(", ", successful_sets), self:get_request().path}))
	end
end

-- TODO: DEPRECATED
function EthernetInterfaceHandler:__put_settings(response)

	-- Set up the local space: get a connection with Redis DB, gather url segment, establish redis prefix, and set scope.
	local redis = self:get_db()

	local collection, instance, secondary_collection, id = 
		self.url_segments[1], self.url_segments[2], self.url_segments[3], self.url_segments[4];

	local prefix = "Redfish:Managers:"..instance..":EthernetInterfaces:"..id..":SD"

	-- Purge any keys associated with the resource from Redis.
	local object_keys = yield(redis:keys(prefix..":*"))
	local num_del = yield(redis:del(object_keys))
	
	self:set_scope("Redfish:"..table.concat(self.url_segments,':'))

	local pl = redis:pipeline()

	-- Get the request body.
	local request_data = turbo.escape.json_decode(self:get_request().body)
	
	-- The 'extended' table will hold all of our "@Message.ExtendedInfo" errors that accumulate while making changes.
    local extended = {}
    local successful_sets = {}

	-- Add commands to pipeline as needed by referencing our 'edit_operations' table.
	for property, value in pairs(request_data) do
		if edit_operations[property] then
			edit_operations[property](pl, prefix, value, extended, successful_sets)
		end
	end

	-- Add default values for required read-only properties.
	pl:mset({
		prefix..":Name", "Ethernet Settings Object",
		prefix..":Description", "OData object to hold Ethernet Settings",
		prefix..":PermanentMACAddress", "00:00:00:00:00:00",
		})
	pl:hmset(prefix..":Status", "State", "Disabled", "HealthRollup", "OK", "Health", "OK")
	self:update_lastmodified(prefix, os.time(), pl, 1)

	if #extended ~= 0 then
		response["@Message.ExtendedInfo"] = extended
	end

	-- Run any pending database commands.
	if #pl.pending_commands > 0 then
		local res = yield(pl:run())
		self:add_audit_log_entry(self:create_message("Security", "ResourceModified", nil, {"All", self:get_request().path}))
	end
end

-- TODO: settings object and POST handler deprecated
function EthernetInterfaceHandler:__post_settings(response)
	-- Set up the local space: get a connection with Redis DB, gather url segment, establish redis prefix, and set scope.
	local redis = self:get_db()

	local collection, instance, secondary_collection, id = 
		self.url_segments[1], self.url_segments[2], self.url_segments[3], self.url_segments[4];

	local prefix = "Redfish:Managers:"..instance..":EthernetInterfaces:"..id
	
	self:set_scope("Redfish:"..table.concat(self.url_segments,':'))

	local pl = redis:pipeline()
	-- Get default values for read-only properties.
	pl:mget({
		prefix .. ":Name",
		prefix .. ":Description",
		prefix .. ":UefiDevicePath",
		prefix .. ":PermanentMACAddress",
		prefix .. ":MaxIPv6StaticAddresses",
		prefix .. ":IPv6DefaultGateway",
		})
	pl:hmget(prefix..":Status", "State", "HealthRollup", "Health")

	local current_settings, current_status = unpack(yield(pl:run()))

	pl = nil
	pl = redis:pipeline()
	prefix = prefix .. ":SD"

	-- Get the request body.
	local request_data = turbo.escape.json_decode(self:get_request().body)

    -- The 'extended' table will hold all of our "@Message.ExtendedInfo" errors that accumulate while making changes.
    local extended = {}
    local successful_sets = {}

	-- Add commands to pipeline as needed by referencing our 'edit_operations' table.
	for property, value in pairs(request_data) do
		if edit_operations[property] then
			edit_operations[property](pl, prefix, value, extended, successful_sets)
		else
			table.insert(extended, self:create_message("Base", "PropertyUnknown", "#/" .. property, property))
		end
	end

	pl:mset({
		prefix..":ResourceExists", "true",
		prefix..":Name", current_settings[1] or "OData object to hold Ethernet Settings",
		prefix..":Description", current_settings[2] or "Ethernet Settings Object",
		prefix..":UefiDevicePath", current_settings[3] or "",
		prefix..":PermanentMACAddress", current_settings[4] or "00:00:00:00:00:00",
		prefix..":MaxIPv6StaticAddresses", current_settings[5] or 1,
		prefix..":IPv6DefaultGateway", current_settings[6] or "::",
		})
	pl:hmset(prefix..":Status", "State", current_status[1] or "Disabled", "HealthRollup", current_status[2] or "OK", "Health", current_status[3] or "OK")

	-- If we found invalid properties in a POST request, we return a 400 Bad Request, so database commands should be skipped
	if #extended ~= 0 then
		response["@Message.ExtendedInfo"] = extended
		pl:clear()
	elseif #pl.pending_commands > 0 then
		-- Run any pending database commands.
		self:update_lastmodified(prefix, os.time(), pl, 1)
		local res = yield(pl:run())
		self:add_audit_log_entry(self:create_message("Security", "ResourceModified", nil, {"All", self:get_request().path}))
	end

	self:set_allow_header("POST")
end

-- TODO: DEPRECATED
function EthernetInterfaceHandler:__delete_settings(response)

	-- Set up the local space: get a connection with Redis DB, gather url segment, establish redis prefix, and set scope.
	local redis = self:get_db()

	local collection, instance, secondary_collection, id = 
		self.url_segments[1], self.url_segments[2], self.url_segments[3], self.url_segments[4];

	local prefix = "Redfish:Managers:"..instance..":EthernetInterfaces:"..id..":SD"
	
	self:set_scope("Redfish:"..table.concat(self.url_segments,':'))

	-- Purge any keys associated with the resource from Redis.
	local object_keys = yield(redis:keys(prefix..":*"))
	local num_del = yield(redis:del(object_keys))
	self:add_audit_log_entry(self:create_message("Security", "ResourceDeleted", nil, {self:get_request().path}))
end

-- #### Helper function for determining if the EthernetInterface resource exists
function EthernetInterfaceHandler:resourceExists()
	-- Set up the local space: get a connection with Redis DB, gather url segment, establish redis prefix
	local redis = self:get_db()

	local collection, instance, secondary_collection, id, sd = 
		self.url_segments[1], self.url_segments[2], self.url_segments[3], self.url_segments[4], self.url_segments[5];

	-- check for settings object using ResourceExists property
	local prefix = "Redfish:Managers:"..instance..":EthernetInterfaces:"..id

	local db_res = yield(self:get_db():get(prefix .. ":ResourceExists"))
	return db_res == "true"
end

-- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
-- TODO: this is a crude workaround in place until 'apply Settings on Event' mechanism is finished
-- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
function EthernetInterfaceHandler:applySettingsObject()
	local eth_name = self.url_segments[4]
	if eth_name then
		-- trigger the dummy pattern used in sync_agent ('applylan:*'), the value of the key doesn't actually matter
		local res = yield(self:get_db():set("applylan:"..eth_name, "Applying LAN settings!"))
		-- add a callback to trigger sync_agent to get data from ipmi and resync EthIfcs
		-- Create the callback using turbo.IOLoop
		local callback = function ()
			turbo.log.notice("REDFISH-LUA TRIGGERING LAN SETTINGS SYNC")
			-- trigger lan settings to re-sync
			os.execute("echo 0 > /tmp/reload-network-info")
		end
		-- trigger resync after 90 seconds
		local cb_ref = turbo.ioloop.instance():add_timeout(turbo.util.gettimemonotonic() + 90000, callback)
	end
end

return EthernetInterfaceHandler