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
local SerialInterfaceHandler = class("SerialInterfaceHandler", RedfishHandler)
local yield = coroutine.yield
-- Set the path names for serial interface OEM extensions
local collection_oem_path = "manager.manager-serialinterface-collection"
local instance_oem_path = "manager.manager-serialinterface-instance"
SerialInterfaceHandler:set_all_oem_paths(collection_oem_path, instance_oem_path)
-- The 'property_access' table specifies read/write permission for all properties.
local property_access = require("property-access.SerialInterface")["SerialInterface"]
-- ### GET request handler for Manager/SerialInterfaces
function SerialInterfaceHandler:get(_manager_id, id)
	local response = {}
	-- Create the GET response for Serial Interface collection or instance, based on what 'id' was given.	
	if id == nil then
		self:get_collection(response)
	else
		self:get_instance(response)
	end
	-- After the response is created, we register it with the handler and then output it to the client.
	self:set_response(response)
	self:output()
end
-- ### PATCH request handler for Manager/SerialInterfaces
function SerialInterfaceHandler:patch(_manager_id, id)
	if self:can_user_do("ConfigureManager") == false then
		self:error_insufficient_privilege()
	end
	local response = {}
	-- Check Redis for the presence of the Manager resource in question. If it isn't found, throw a 404
	local redis = self:get_db()
	local man_exists = yield(redis:exists("Redfish:Managers:".._manager_id..":ManagerType"))
	if man_exists == 0 then
		self:error_resource_missing_at_uri()
	else
		-- Create the PATCH response for Serial Interface collection or instance, based on what 'id' was given.	
		if id == nil then
			-- Allow an OEM patch handler for serial interface collections, if none exists, return with the normal 405 response
			self:set_header("Allow", "GET")
			self:set_status(405)
			response = self:oem_extend(response, "patch." .. self:get_oem_collection_path())
			if self:get_status() == 405 then
				self:error_method_not_allowed()
			end
		else
			-- Allow the OEM patch handlers for serial interface instances to have the first chance to handle the request body
			response = self:oem_extend(response, "patch." .. self:get_oem_instance_path())
			-- Check if user is authorized to make changes.
			if self:can_user_do("ConfigureManager") == true then
				-- If so, patch the resource and respond with the updated version. 
				-- Check Redis for the presence of the Serial Interface instance in question. If it isn't found, throw a 404
				local instance_exists = yield(redis:exists("Redfish:Managers:".._manager_id..":SerialInterfaces:"..id..":Name"))
				if instance_exists == 1 then
					self:patch_instance(response)
					--self:get_instance(response)
				else
					self:error_resource_missing_at_uri()
				end
			else
				--Throw an error if the user is not authorized.			
				self:error_insufficient_privilege()
			end
		end
	end
	-- After the response is created, we register it with the handler and then output it to the client.
	self:set_response(response)
	self:output()
end
-- #### GET handler for Serial Interfaces collection
function SerialInterfaceHandler:get_collection(response)
	-- Before proceeding with the handler, we'll make sure the collection request is valid
	local collection_exists = self:parent_exists()
	self:assertTrue_404(collection_exists)
	-- Set up the local space: get a connection with Redis DB, gather url segment, establish redis prefix, and set scope
	local redis = self:get_db()
	local collection, instance, secondary_collection = 
		self.url_segments[1], self.url_segments[2], self.url_segments[3];
	local prefix = "Redfish:Managers:"..instance..":SerialInterfaces:"
	self:set_scope("Redfish:"..table.concat(self.url_segments,':'))
	-- Fill in Name and Description fields
	response["Name"] = "Serial Interface Collection"
	response["Description"] = "Collection of Serial Interfaces for this System"
	-- Search Redis for any Serial Interfaces, and pack the results into an array
	local odataIDs = utils.getODataIDArray(yield(redis:keys(prefix.."*:Parity")), 1)
	-- Set Members fields based on results from Redis
	response["Members@odata.count"] = #odataIDs
	response["Members"] = odataIDs
	-- Add OEM extension properties to the response
    response = self:oem_extend(response, "query." .. self:get_oem_collection_path())
	-- Set the OData context and type for the response
	self:set_context(CONSTANTS.SERIAL_INTERFACE_COLLECTION_CONTEXT)
	self:set_type(CONSTANTS.SERIAL_INTERFACE_COLLECTION_TYPE)
	-- GET requests must respond with the 'Allow' header specifying what methods are available for the given URL
	self:set_allow_header("GET")
end
-- #### GET handler for Serial Interface instance
function SerialInterfaceHandler:get_instance(response)
	-- Set up the local space: get a connection with Redis DB, gather url segment, establish redis prefix, and set scope
	local redis = self:get_db()
	local collection, instance, secondary_collection, id = 
		self.url_segments[1], self.url_segments[2], self.url_segments[3], self.url_segments[4];
	local prefix = "Redfish:Managers:"..instance..":SerialInterfaces:"..id
	
	self:set_scope("Redfish:"..table.concat(self.url_segments,':'))
	-- Create a Redis pipeline and add commands for all Serial Interface properties
	local pl = redis:pipeline()
	pl:mget({
			prefix..":Name",
			prefix..":Description",
			prefix..":InterfaceEnabled",
			prefix..":SignalType",
			prefix..":BitRate",
			prefix..":Parity",
			prefix..":DataBits",
			prefix..":StopBits",
			prefix..":FlowControl",
			prefix..":ConnectorType",
			prefix..":PinOut"
			})
	-- Run the Redis pipeline, and unpack the results
    local db_result = yield(pl:run())
    -- Check that data was found in Redis, if not we throw a 404 NOT FOUND
    self:assert_resource(db_result)
	local general = unpack(db_result)
	-- Add the data from Redis into the response, converting types where necessary
	response["Id"] = id
	response["Name"] = general[1]
	response["Description"] = general[2]
	if type(general[3]) ~= "nil" then
		response["InterfaceEnabled"] = utils.bool(general[3])
	end
    response["SignalType"] = general[4]
    response["BitRate"] = general[5]
    response["Parity"] = general[6]
    response["DataBits"] = general[7]
    response["StopBits"] = general[8]
    response["FlowControl"] = general[9]
    response["ConnectorType"] = general[10]
    response["PinOut"] = general[11]
	-- Add OEM extension properties to the response
    response = self:oem_extend(response, "query." .. self:get_oem_instance_path())
	-- Set the OData context and type for the response
	local sL_table = _.keys(response)
	if #sL_table < 12 then
        local selectList = turbo.util.join(',', sL_table)
		self:set_context(CONSTANTS.SERIAL_INTERFACE_INSTANCE_CONTEXT.."("..selectList..")")
	else
		self:set_context(CONSTANTS.SERIAL_INTERFACE_INSTANCE_CONTEXT)
	end
	self:set_type(CONSTANTS.SERIAL_INTERFACE_TYPE)
	-- Remove extraneous fields from the response
	utils.remove_nils(response)
	-- GET requests must respond with the 'Allow' header specifying what methods are available for the given URL
	self:set_allow_header("GET, PATCH")
end
-- #### PATCH handler for Serial Interface instance
function SerialInterfaceHandler:patch_instance(response)
	-- Set up the local space: get a connection with Redis DB, gather url segment, establish redis prefix, and set scope.
	local redis = self:get_db()
	local collection, instance, secondary_collection, id = 
		self.url_segments[1], self.url_segments[2], self.url_segments[3], self.url_segments[4];
	local prefix = "Redfish:Managers:"..instance..":SerialInterfaces:"..id
	
	self:set_scope("Redfish:"..table.concat(self.url_segments,':'))
	local pl = redis:pipeline()
	-- Get the request body.
	local request_data = turbo.escape.json_decode(self:get_request().body)
    -- The 'AlVal_*' tables contain allowed values for properties with enumerated types. 
    local AlVal_BitRate = { "1200", "2400", "4800", "9600", "19200", "38400", "57600", "115200", "230400" }
    local AlVal_Parity = { "None", "Even", "Odd", "Mark", "Space" }
    local AlVal_DataBits = { "5", "6", "7", "8" }
    local AlVal_StopBits = { "1", "2" }
    local AlVal_FlowControl = { "None", "Software", "Hardware" }
	-- The 'extended' table will hold all of our "@Message.ExtendedInfo" errors that accumulate while making changes.
    local extended = {}
    local successful_sets = {}
    local keys_to_watch = {}
	-- The 'patch_operations' table holds functions that know how to PATCH each property.
	-- For each property, validate the value, then create an error message or add appropriate Redis command based on outcome.
    local patch_operations = {
		["InterfaceEnabled"] = function(pipe, value)
			if not type(value) == "boolean" then
				table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/InterfaceEnabled"}, {tostring(value), "InterfaceEnabled"}))
			else
				pipe:set("PATCH:"..prefix..":InterfaceEnabled", tostring(value))
				table.insert(keys_to_watch, prefix..":InterfaceEnabled")
				table.insert(successful_sets, "InterfaceEnabled")
				
			end
			request_data.InterfaceEnabled = nil
		end,
		["BitRate"] = function(pipe, value)
			if not turbo.util.is_in(value, AlVal_BitRate) then
				table.insert(extended, self:create_message("Base", "PropertyValueNotInList", {"#/BitRate"}, {tostring(value), "BitRate"}))
			else
				pipe:set("PATCH:"..prefix..":BitRate", tostring(value))
				table.insert(keys_to_watch, prefix..":BitRate")
				table.insert(successful_sets, "BitRate")
			end
			request_data.BitRate = nil
		end,
		["Parity"] = function(pipe, value)
			if not turbo.util.is_in(value, AlVal_Parity) then
				table.insert(extended, self:create_message("Base", "PropertyValueNotInList", {"#/Parity"}, {tostring(value), "Parity"}))
			else
				pipe:set("PATCH:"..prefix..":Parity", tostring(value))
				table.insert(keys_to_watch, prefix..":Parity")
				table.insert(successful_sets, "Parity")
			end
			request_data.Parity = nil
		end,
		["DataBits"] = function(pipe, value)
			if not turbo.util.is_in(value, AlVal_DataBits) then
				table.insert(extended, self:create_message("Base", "PropertyValueNotInList", {"#/DataBits"}, {tostring(value), "DataBits"}))
			else
				pipe:set("PATCH:"..prefix..":DataBits", tostring(value))
				table.insert(keys_to_watch, prefix..":DataBits")
				table.insert(successful_sets, "DataBits")
			end
			request_data.DataBits = nil
		end,
		["StopBits"] = function(pipe, value)
			if not turbo.util.is_in(value, AlVal_StopBits) then
				table.insert(extended, self:create_message("Base", "PropertyValueNotInList", {"#/StopBits"}, {tostring(value), "StopBits"}))
			else
				pipe:set("PATCH:"..prefix..":StopBits", tostring(value))
				table.insert(keys_to_watch, prefix..":StopBits")
				table.insert(successful_sets, "StopBits")
			end
			request_data.StopBits = nil
		end,
		["FlowControl"] = function(pipe, value)
			if not turbo.util.is_in(value, AlVal_FlowControl) then
				table.insert(extended, self:create_message("Base", "PropertyValueNotInList", {"#/FlowControl"}, {tostring(value), "FlowControl"}))
			else
				pipe:set("PATCH:"..prefix..":FlowControl", tostring(value))
				table.insert(keys_to_watch, prefix..":FlowControl")
				table.insert(successful_sets, "FlowControl")
			end
			request_data.FlowControl = nil
		end
	}
	
	-- Split the request body into read-only and writable properties.
	local readonly_body
	local writable_body
	local read_only = {}
	readonly_body, writable_body = utils.readonlyCheck(request_data, property_access)
	
	-- Add commands to pipeline as needed by referencing our 'patch_operations' table.
	if writable_body then
		for property, value in pairs(writable_body) do
			patch_operations[property](pl, value)
		end
	end
	
	-- If the user attempts to PATCH read-only properties, respond with the proper error messages.
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
	
	-- Run any pending database commands.
	if #pl.pending_commands > 0 then
		
		-- doPATCH will block until it sees that the keys we are PATCHing have been changed, or receives an error response about why the PATCH failed, or until it times out
		-- doPATCH returns a table of any error messages received, and, if a timeout occurs, any keys that had yet to be modified when the timeout happened
		local patch_errors, timedout_keys, result = self:doPATCH(keys_to_watch, pl, CONFIG.PATCH_TIMEOUT)
		for _i, err in pairs(patch_errors) do
			table.insert(extended, self:create_message(err.Registry, err.MessageId, err.RelatedProperties, err.MessageArgs))
		end
		for _i, to_key in pairs(timedout_keys) do
			local property_key = to_key:split("SerialInterfaces:[^:]+:", nil, true)[2]
			local key_segments = property_key:split(":")
			local property_name = "#/" .. table.concat(key_segments, "/")
			table.insert(extended, self:create_message("SyncAgent", "PatchTimeout", property_name, {CONFIG.PATCH_TIMEOUT/1000, property_name}))
		end
		self:add_audit_log_entry(self:create_message("Security", "ResourceModified", nil, {turbo.util.join(", ", successful_sets), self:get_request().path}))
	end
	
	-- If we caught any errors along the way, add them to the response.
	if #extended ~= 0 then 			
		self:add_error_body(response,400, unpack(extended))
	else 
		self:update_lastmodified(prefix, os.time())
		self:set_status(204) 		
	end
end
return SerialInterfaceHandler