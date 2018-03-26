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
-- [See "turboredis.lua"](https://github.com/enotodden/turboredis)
local redis_utils = require("turboredis.util")

local SystemEthernetInterfaceHandler = class("SystemEthernetInterfaceHandler", RedfishHandler)

local yield = coroutine.yield

-- Set the path names for system ethernet interface OEM extensions
local collection_oem_path = "system.system-ethernetinterface-collection"
local instance_oem_path = "system.system-ethernetinterface-instance"
SystemEthernetInterfaceHandler:set_all_oem_paths(collection_oem_path, instance_oem_path)

--Handles GET requests for System Ethernet Interface collection and instance
function SystemEthernetInterfaceHandler:get(id1, id2)

	local response = {}
	
	if id2 == nil then
		--GET collection
		self:get_collection(response)
	else
		--GET instance
		self:get_instance(response)
	end

	self:set_response(response)

	self:output()
end

-- Handles GET System Ethernet Interface collection
function SystemEthernetInterfaceHandler:get_collection(response)
	-- Before proceeding with the handler, we'll make sure the collection request is valid
	local collection_exists = self:parent_exists()
	self:assertTrue_404(collection_exists)

	local redis = self:get_db()
	local url_segments = self:get_url_segments();

	local collection, instance, secondary_collection = 
		url_segments[1], url_segments[2], url_segments[3];

	local prefix = "Redfish:" .. collection .. ":" .. instance .. ":" .. secondary_collection

	self:set_scope("Redfish:" .. table.concat(url_segments, ":"))

	-- Creating response
	response["Name"] = "Ethernet Interface Collection"
	response["Description"] = "Collection of ethernet interfaces for this system"

	local odataIDs = utils.getODataIDArray(yield(redis:keys(prefix .. ":*:MACAddress")), 1)

	response["Members@odata.count"] = #odataIDs
	response["Members"] = odataIDs

	response = self:oem_extend(response, "query." .. self:get_oem_collection_path())

	self:set_context(CONSTANTS.ETHERNET_INTERFACE_COLLECTION_CONTEXT)
	self:set_type(CONSTANTS.ETHERNET_INTERFACE_COLLECTION_TYPE)

	-- GET requests must respond with the 'Allow' header specifying what methods are available for the given URL
	self:set_allow_header("GET")
end

-- Handles GET System Ethernet Interface instance
function SystemEthernetInterfaceHandler:get_instance(response)
	local redis = self:get_db()
	local url_segments = self:get_url_segments();

	local collection, instance, secondary_collection, id = 
		url_segments[1], url_segments[2], url_segments[3], url_segments[4];

	local prefix = "Redfish:" .. collection .. ":" .. instance .. ":" .. secondary_collection .. ":" .. id

	self:set_scope("Redfish:"..table.concat(url_segments,':'))

	--Retrieving data from database
	local pl = redis:pipeline()
	pl:mget({
			prefix .. ":Name",
			prefix .. ":Description",
			prefix .. ":PermanentMACAddress",
			prefix .. ":MACAddress",
			prefix .. ":SpeedMbps",
			prefix .. ":FullDuplex",
			prefix .. ":HostName",
			prefix .. ":FQDN",
			prefix .. ":IPv6DefaultGateway",
			prefix .. ":UefiDevicePath",
			prefix .. ":InterfaceEnabled",
			prefix .. ":AutoNeg",
			prefix .. ":MTUSize",
			prefix .. ":MaxIPv6StaticAddresses"
		})
	pl:hmget(prefix .. ":Status", "State", "Health", "HealthRollup")
	pl:hgetall(prefix .. ":IPv4Addresses")
	pl:hgetall(prefix .. ":IPv6Addresses")
	pl:smembers(prefix .. ":NameServers")
	pl:hgetall(prefix .. ":IPv6AddressPolicyTable")
	pl:hgetall(prefix .. ":IPv6StaticAddresses")

    local db_result = yield(pl:run())

    -- Check that data was found in Redis, if not we throw a 404 NOT FOUND
    self:assert_resource(db_result)

	local general, status, ipv4, ipv6, dns, ipv6_policy_list, ipv6_static_list = unpack(db_result)

	--Creating response using data from database
	response["Id"] = id
	response["Name"] = general[1]
	response["Description"] = general[2]
	response["PermanentMACAddress"] = general[3]
	response["MACAddress"] = general[4]
	response["SpeedMbps"] = tonumber(general[5])
	response["FullDuplex"] = utils.bool(general[6])
	response["HostName"] = general[7]
	response["FQDN"] = general[8]
	response["IPv6DefaultGateway"] = general[9]
	response["UefiDevicePath"] = general[10]
	response["InterfaceEnabled"] = utils.bool(general[11])
	response["AutoNeg"] = utils.bool(general[12])
	response["MTUSize"] = tonumber(general[13])
	response["MaxIPv6StaticAddresses"] = tonumber(general[14])
	response["Status"] = {
		State = status[1],
		Health = status[2],
		HealthRollup = status[3]
	}
	response["IPv4Addresses"] = utils.convertHashListToArray(redis_utils.from_kvlist(ipv4))
	response["IPv6Addresses"] = utils.convertHashListToArray(redis_utils.from_kvlist(ipv6))
	response["IPv6AddressPolicyTable"] = utils.convertHashListToArray(redis_utils.from_kvlist(ipv6_policy_list))
	response["IPv6StaticAddresses"] = utils.convertHashListToArray(redis_utils.from_kvlist(ipv6_static_list))
	response["NameServers"] = dns
	response["VLANs"] = {}
	response["VLANs"]["@odata.id"] = CONFIG.SERVICE_PREFIX .. "/" .. collection .. "/" .. instance .. "/" .. secondary_collection .. "/" .. id .. '/VLANs'

	response = self:oem_extend(response, "query." .. self:get_oem_instance_path())

	utils.remove_nils(response)

	local keys = _.keys(response)
	if #keys < 22 then
		local select_list = turbo.util.join(",", keys)
		self:set_context(CONSTANTS.ETHERNET_INTERFACE_INSTANCE_CONTEXT .. "(" .. select_list .. ")")
	else
		self:set_context(CONSTANTS.ETHERNET_INTERFACE_INSTANCE_CONTEXT)
	end

	self:set_type(CONSTANTS.ETHERNET_INTERFACE_TYPE)

	-- GET requests must respond with the 'Allow' header specifying what methods are available for the given URL
	self:set_allow_header("GET, PATCH")
end

--Handles PATCH request for System Ethernet Interface
function SystemEthernetInterfaceHandler:patch(_system_id, id)

	local url_segments = self:get_url_segments()
	local collection, instance, secondary_collection, inner_instance = url_segments[1], url_segments[2], url_segments[3], url_segments[4]
	local response = {}

	--Throwing error if request is to collection
	if inner_instance == nil then
		-- Allow an OEM patch handler for system eth ifc collections, if none exists, return with the normal 405 response
		self:set_header("Allow", "GET")
		self:set_status(405)

		response = self:oem_extend(response, "patch." .. self:get_oem_collection_path())

		if self:get_status() == 405 then
			self:error_method_not_allowed()
		end
	else
		-- Allow the OEM patch handlers for system eth ifc instances to have the first chance to handle the request body
		response = self:oem_extend(response, "patch." .. self:get_oem_instance_path())
	end

	--Making sure current user has permission to modify ethernet interface settings
	if self:can_user_do("ConfigureComponents") == true then
		local redis = self:get_db()
		
		local exists = yield(redis:exists("Redfish:Systems:".._system_id..":EthernetInterfaces:"..id..":MACAddress"))
		if exists ~= 1 then
			self:error_resource_missing_at_uri()
		else
			local request_data = turbo.escape.json_decode(self:get_request().body)

			self:set_scope("Redfish:" .. table.concat(url_segments, ":"))

			local pl = redis:pipeline()
			local prefix = "Redfish:" .. collection .. ":" .. instance .. ":" .. secondary_collection .. ":" .. inner_instance
			local extended = {}
			local successful_sets = {}

			--Validating InterfaceEnabled property and adding error if property is incorrect
			if request_data.InterfaceEnabled ~= nil then
				if type(request_data.InterfaceEnabled) ~= "boolean" then
					table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"InterfaceEnabled"}, {request_data.InterfaceEnabled, "InterfaceEnabled"}))
				else
					--InterfaceEnabled is valid and will be added to database
					pl:set(prefix .. ":InterfaceEnabled", tostring(request_data.InterfaceEnabled))
					table.insert(successful_sets, "InterfaceEnabled")
				end
				request_data.InterfaceEnabled = nil
			end

			--Setting MACAddress
			if request_data.MACAddress ~= nil then
				if string.match(request_data.MACAddress, "^[0-9A-Fa-f][0-9A-Fa-f][:-][0-9A-Fa-f][0-9A-Fa-f][:-][0-9A-Fa-f][0-9A-Fa-f][:-][0-9A-Fa-f][0-9A-Fa-f][:-][0-9A-Fa-f][0-9A-Fa-f][:-][0-9A-Fa-f][0-9A-Fa-f]$") == nil then
					table.insert(extended, self:create_message("Base", "PropertyValueFormatError", {"#/MACAddress"}, {request_data.MACAddress, "MACAddress"}))
				else
					pl:set(prefix .. ":MACAddress", request_data.MACAddress)
					table.insert(successful_sets, "MACAddress")
				end
				request_data.MACAddress = nil
			end

			--Validating AutoNeg and adding property or adding error if property is incorrect
			if request_data.AutoNeg ~= nil then
				if type(request_data.AutoNeg) ~= "boolean" then
					table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"AutoNeg"}, {request_data.AutoNeg, "AutoNeg"}))
				else
					--AutoNeg is valid and will be added to database
					pl:set(prefix .. ":AutoNeg", tostring(request_data.AutoNeg))
					table.insert(successful_sets, "AutoNeg")
				end
				request_data.AutoNeg = nil
			end

			--Validating FullDuplex and adding property or adding error if property is incorrect
			if request_data.FullDuplex ~= nil then
				if type(request_data.FullDuplex) ~= "boolean" then
					table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"FullDuplex"}, {request_data.FullDuplex, "FullDuplex"}))
				else
					--FullDuplex is valid and will be added to database
					pl:set(prefix .. ":FullDuplex", tostring(request_data.FullDuplex))
					table.insert(successful_sets, "FullDuplex")
				end
				request_data.FullDuplex = nil
			end

			--Validating SpeedMbps and adding property or adding error if property is incorrect
			if request_data.SpeedMbps ~= nil then
				if tonumber(request_data.SpeedMbps) == nil then
					table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"SpeedMbps"}, {request_data.SpeedMbps, "SpeedMbps"}))
				else
					--SpeedMbps is valid and will be added to database
					pl:set(prefix .. ":SpeedMbps", request_data.SpeedMbps)
					table.insert(successful_sets, "SpeedMbps")
				end
				request_data.SpeedMbps = nil
			end

			--Validating MTUSize and adding property or adding error if property is incorrect
			if request_data.MTUSize ~= nil then
				if tonumber(request_data.MTUSize) == nil then
					table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"MTUSize"}, {request_data.MTUSize, "MTUSize"}))
				else
					--MTUSize is valid and will be added to database
					pl:set(prefix .. ":MTUSize", request_data.MTUSize)
					table.insert(successful_sets, "MTUSize")
				end
				request_data.MTUSize = nil
			end

			--Setting HostName
			if request_data.HostName ~= nil then
				pl:set(prefix .. ":HostName", request_data.HostName)
				table.insert(successful_sets, "HostName")
				request_data.HostName = nil
			end

			--Setting FQDN
			if request_data.FQDN ~= nil then
				pl:set(prefix .. ":FQDN", request_data.FQDN)
				table.insert(successful_sets, "FQDN")
				request_data.FQDN = nil
			end

			--Setting IPv6AddressPolicyTable properties
			if request_data.IPv6AddressPolicyTable ~= nil then 
				local index = 0
				for k, v in pairs(request_data.IPv6AddressPolicyTable) do
					pl:hset(prefix .. ":IPv6AddressPolicyTable", index .. ":Prefix", v.Prefix)
					table.insert(successful_sets, "IPv6AddressPolicyTable:Prefix")
					if tonumber(v.Precedence) == nil then
						table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/Precedence"}, {v.Precedence, "Precedence"}))
					elseif tonumber(v.Precedence) < 1 or tonumber(v.Precedence) > 100 then
						--self:add_extended_info(extended, msg_prefix .. ".PropertyValueFormatError", {"#/Precedence"}, msg["PropertyValueFormatError"]["Message"]:format(v.Precedence, "Precedence"), msg["PropertyValueFormatError"]["Severity"], msg["PropertyValueFormatError"]["Resolution"])
						table.insert(extended, self:create_message("Base", "PropertyValueFormatError", {"#/Precedence"}, {v.Precedence, "Precedence"}))
					else
						pl:hset(prefix .. ":IPv6AddressPolicyTable", index .. ":Precedence", v.Precedence)
						table.insert(successful_sets, "IPv6AddressPolicyTable:Precedence")
					end

					if tonumber(v.Label) == nil then
						table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/Label"}, {v.Label, "Label"}))
					elseif tonumber(v.Label) < 0 or tonumber(v.Label) > 100 then
						--self:add_extended_info(extended, msg_prefix .. ".PropertyValueFormatError", {"#/Label"}, msg["PropertyValueFormatError"]["Message"]:format(v.Label, "Label"), msg["PropertyValueFormatError"]["Severity"], msg["PropertyValueFormatError"]["Resolution"])
						table.insert(extended, self:create_message("Base", "PropertyValueFormatError", {"#/Label"}, {v.Label, "Label"}))
					else
						pl:hset(prefix .. ":IPv6AddressPolicyTable", index .. ":Label", v.Label)
						table.insert(successful_sets, "IPv6AddressPolicyTable:Label")
					end
					index = index + 1
				end
				request_data.IPv6AddressPolicyTable = nil
			end
			local result = yield(pl:run())
			self:add_audit_log_entry(self:create_message("Security", "ResourceModified", nil, {turbo.util.join(", ", successful_sets), self:get_request().path}))

			--Checking if there are any additional properties in the request and creating an error to show these properties
			local leftover_fields = utils.table_len(request_data)
			if leftover_fields ~= 0 then
				local keys = _.keys(request_data)
				table.insert(extended, self:create_message("Base", "PropertyNotWritable", keys, turbo.util.join(",", keys)))
			end

			--Checking if there were errors and adding them to the response if there are
			if #extended ~= 0 then
				response["@Message.ExtendedInfo"] = extended
			end

			self:get_instance(response)
		end
	else
		self:error_insufficient_privilege()
	end

	self:set_response(response)
	self:output()
end

return SystemEthernetInterfaceHandler