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

local ManagerHandler = class("ManagerHandler", RedfishHandler)

local yield = coroutine.yield

-- Set the path names for manager OEM extensions
local collection_oem_path = "manager.manager-collection"
local instance_oem_path = "manager.manager-instance"
local action_oem_path = "manager.manager-instance-actions"
local link_oem_path = "manager.manager-instance-links"
ManagerHandler:set_all_oem_paths(collection_oem_path, instance_oem_path, nil, action_oem_path, link_oem_path)

-- The 'property_access' table specifies read/write permission for all properties.
local property_access = require("property-access.Manager")["Manager"]

-- ### GET request handler for Manager/
function ManagerHandler:get(id, action)

	local response = {}

	-- Reject GET requests to Action URLs with a proper 405 response
	if action then
		self:set_allow_header("POST")
		self:error_method_not_allowed()
	end

	-- Create the GET response for Manager collection or instance, based on what 'id' was given.
	if id == "/redfish/v1/Managers" then
		self:get_collection(response)
	else
		self:get_instance(response)
	end

	-- After the response is created, we register it with the handler and then output it to the client.
	self:set_response(response)

	self:output()
end

-- ### PATCH request handler for Manager/
function ManagerHandler:patch(id)

	local response = {}

	-- Create the PATCH response for Manager collection or instance, based on what 'id' was given.
	if id == "/redfish/v1/Managers" then
		-- Allow an OEM patch handler for manager collections, if none exists, return with the normal 405 response
		self:set_header("Allow", "GET")
		self:set_status(405)

		response = self:oem_extend(response, "patch." .. self:get_oem_collection_path())

		if self:get_status() == 405 then
			self:error_method_not_allowed()
		end
	else
		-- Allow OEM patch handlers for manager instances to have the first chance to handle the request body
		response = self:oem_extend(response, "patch." .. self:get_oem_instance_path())

		-- Check if user is authorized to make changes.
		if self:can_user_do("ConfigureManager") == true then
			-- If so, patch the resource and respond with the updated version. 
			-- Check Redis for the presence of the Manager resource in question. If it isn't found, throw a 404
			local redis = self:get_db()
			local man_exists = yield(redis:exists("Redfish:Managers:"..id..":ManagerType"))
			if man_exists == 1 then
				self:patch_instance(response)
			else
				self:error_resource_missing_at_uri()
			end
		else
			--Throw an error if the user is not authorized.			
			self:error_insufficient_privilege()
		end
	end

	-- After the response is created, we register it with the handler and then output it to the client.
	self:set_response(response)

	self:output()
end

local allowed_resets = {"ForceRestart"}
-- local allowed_forcefail = {"ForceFailover"}
-- local allowed_modifications = {"ModifyRedundancySet"}

-- ### POST request handler for Manager/
function ManagerHandler:post(id, action)

	local url = self.request.headers:get_url()

	local request_data = self:get_json()

	local response = {}

	local missing = {}
	
	local prefix = "Redfish:Managers:" .. id

	if id == "/redfish/v1/Managers" then
		-- When an HTTP method is rejected with status code 405, we must set an Allow header that lists valid HTTP methods for the URI
		self:set_header("Allow", "GET")
		-- No PATCH for collections
		self:error_method_not_allowed()
	end

	if action then
		space, action = string.match(action, "([^/^.]+)%.([^/^.]+)")
	end
	-- Handles action here
	if space == 'Manager' and action == 'Reset' then

		local resettype = request_data and request_data.ResetType

		local exists = yield(self:get_db():get("Redfish:Managers:" .. id .. ":Name"))
	  	if not exists then
				self:error_resource_missing_at_uri()
	  	end

		if not turbo.util.is_in(resettype, allowed_resets) then

			self:error_action_parameter_format("ResetType", resettype)

		else

			local redis_action_key = "Redfish:Managers:" .. id .. ":Actions:Reset"

			local action_res = yield(self:get_db():set(redis_action_key, resettype))
			self:update_lastmodified("Redfish:Managers:" .. id ..":Actions:Reset", os.time())
			self:set_status(204)

		end
	-- ForceFailover and ModifyRedundancySet are not meaningful except in certain systems that have multiple truly redudant Managers
		-- elseif space == 'Manager' and action == 'ForceFailover' then

		-- 	local failtarget = request_data and request_data.FailoverTarget
		-- 	-- TODO: make real param for ForceFailover
		-- 	if not turbo.util.is_in(failtarget, allowed_forcefail) then
		--		self:error_action_parameter_unknown("FailoverTarget")

		-- 	else

		-- 		local redis_action_key = "Redfish:Managers:" .. id .. ":Actions:ForceFailover"

		-- 		local action_res = yield(self:get_db():set(redis_action_key, failtarget))

		-- 	end

		-- elseif space == 'Manager' and action == 'ModifyRedundancySet' then

		-- 	local modifytype = request_data and request_data.Modification
		-- 	-- TODO: make real param for ModifyRedundancySet
		-- 	if not turbo.util.is_in(modifytype, allowed_modifications) then

		--		self:error_action_parameter_unknown("Modification")
		-- 	else

		-- 		local redis_action_key = "Redfish:Managers:" .. id .. "Actions:ModifyRedundancySet"

		-- 		local action_res = yield(self:get_db():set(redis_action_key, "CLEAR_PENDING"))

		-- 	end

	-- Always have the else condition similar to "default" case to respond no other actions or post operations available
	elseif self:get_request().path:find("Actions") then
		self:error_action_not_supported()
	else
		--self:error_resource_missing_at_uri()
		self:error_method_not_allowed()
	end

	self:set_response(response)

	self:output()

end

-- #### GET handler for Managers collection
function ManagerHandler:get_collection(response)
	-- Before proceeding with the handler, we'll make sure the collection request is valid
	local collection_exists = self:parent_exists()
	self:assertTrue_404(collection_exists)

	-- Set up the local space: get a connection with Redis DB, gather url segment, establish redis prefix, and set scope
	local redis = self:get_db()

	self:set_scope("Redfish:Managers")
	-- Fill in Name field
	response["Name"] = "Manager Collection"
	-- Search Redis for any Ethernet Interfaces, and pack the results into an array
	local odataIDs = utils.getODataIDArray(yield(redis:keys("Redfish:Managers:*:ManagerType")), 1)
	-- Set Members fields based on results from Redis
	response["Members@odata.count"] = #odataIDs
	response["Members"] = odataIDs

	-- Add OEM extension properties to the response
	response = self:oem_extend(response, "query." .. self:get_oem_collection_path())
	-- Set the OData context and type for the response
	self:set_context(CONSTANTS.MANAGERS_COLLECTION_CONTEXT)
	self:set_type(CONSTANTS.MANAGER_COLLECTION_TYPE)

	-- GET requests must respond with the 'Allow' header specifying what methods are available for the given URL
	self:set_allow_header("GET")
end

-- #### GET handler for Manager instance
function ManagerHandler:get_instance(response)
	-- Set up the local space: get a connection with Redis DB, gather url segment, establish redis prefix, and set scope
	local redis = self:get_db()

	local collection, id = self.url_segments[1], self.url_segments[2];

	local prefix = "Redfish:Managers:" .. id
	self:set_scope(prefix)

	-- date/time should be updated whenever it's queried (based on synced date/time setting)
	local sync_date_time = yield(redis:get(prefix .. ":SyncedDateTime"))
	if sync_date_time == "true" then
		local pl = redis:pipeline()
		pl:set("GET:Redfish:Managers:"..id..":UpdateDateTime", "update")
		self:doGET({"Redfish:Managers:"..id..":DateTime", "Redfish:Managers:"..id..":DateTimeLocalOffset"}, pl, CONFIG.PATCH_TIMEOUT)
	end

	-- Create a Redis pipeline and add commands for all Manager properties
	pl = redis:pipeline()

	pl:mget({
			prefix .. ":Name",
			prefix .. ":ManagerType",
			prefix .. ":Description",
			prefix .. ":ServiceEntryPointUUID",
			prefix .. ":UUID",
			prefix .. ":Model",
			prefix .. ":DateTime",
			prefix .. ":DateTimeLocalOffset",
			prefix .. ":GraphicalConsole:ServiceEnabled",
			prefix .. ":GraphicalConsole:MaxConcurrentSessions",
			prefix .. ":SerialConsole:ServiceEnabled",
			prefix .. ":SerialConsole:MaxConcurrentSessions",
			prefix .. ":CommandShell:ServiceEnabled",
			prefix .. ":CommandShell:MaxConcurrentSessions",
			prefix .. ":FirmwareVersion"
		})
	pl:hmget(prefix .. ":Status", "State", "Health")
	pl:smembers(prefix .. ":GraphicalConsole:ConnectTypesSupported")
	pl:smembers(prefix .. ":SerialConsole:ConnectTypesSupported")
	pl:smembers(prefix .. ":CommandShell:ConnectTypesSupported")
	pl:smembers(prefix .. ":ManagerForServers")
	pl:smembers(prefix .. ":ManagerForChassis")
	-- For Managers we also search for the existence/member count of certain properties
	pl:keys(prefix .. ":NetworkProtocol:Name")
	pl:keys(prefix .. ":EthernetInterfaces:*:Name")
	pl:keys(prefix .. ":SerialInterfaces:*:Name")
	pl:keys(prefix .. ":LogServices:*:ServiceEnabled")
	pl:keys(prefix .. ":VirtualMedia:*:ImageName")
	pl:keys(prefix .. ":HostInterfaces:*:Name")
	-- Query the database to find what Redundancy members we need to retrieve for this Manager
	local redundancy_keys = yield(redis:keys(prefix .. ":Redundancy:*:Name"))
	-- Add queries for Redundancy data to the pipeline
	if redundancy_keys then
		for _i, key in ipairs(redundancy_keys) do
			local redundancy_id = key:split(":")[5]
			pl:mget({
					prefix .. ":Redundancy:" .. redundancy_id .. ":Name",
					prefix .. ":Redundancy:" .. redundancy_id .. ":Mode",
					prefix .. ":Redundancy:" .. redundancy_id .. ":MaxNumSupported",
					prefix .. ":Redundancy:" .. redundancy_id .. ":MinNumNeeded"
				})
			pl:hmget(prefix .. ":Redundancy:" .. redundancy_id .. ":Status", "State", "Health")
			pl:smembers(prefix .. ":Redundancy:" .. redundancy_id .. ":RedundancySet")
		end
	end
	-- Run the Redis pipeline, and unpack the results
	local db_result = yield(pl:run())

	-- Check that data was found in Redis, if not we throw a 404 NOT FOUND
	self:assert_resource(db_result)

	local general, status, gconsole_types, sconsole_types, cmdshl_types, mngr_srvr, 
			mngr_chassis, np_exists, eth_exists, ser_exists, log_exists, vm_exists, host_exists = unpack(db_result)
			
	local UUID = yield(redis:get("Redfish:UUID"))
	
	-- Add the data from Redis into the response, converting types and creating sub-objects where necessary
	response["Id"] = id
	response["Name"] = general[1]
	response["ManagerType"] = general[2]
	response["Description"] = general[3]
	--response["ServiceEntryPointUUID"] = general[4]
	response["ServiceEntryPointUUID"] = UUID
	--response["UUID"] = general[5]
	response["UUID"] = UUID
	response["Model"] = general[6]
	response["DateTime"] = general[7]
	response["DateTimeLocalOffset"] = general[8]
	if status[1] or status[2] then
		response["Status"] = {
			State = status[1],
			Health = status[2]
		}
	end
	-- Sub-objects should only be created when being filled with valid data
	if general[9] or general[10] or #gconsole_types > 0 then
		response["GraphicalConsole"] = {
			ServiceEnabled = utils.bool(general[9]),
			MaxConcurrentSessions = tonumber(general[10]),
			ConnectTypesSupported = gconsole_types
		}
	end
	if general[11] or general[12] or #sconsole_types > 0 then
		response["SerialConsole"] = {
			ServiceEnabled = utils.bool(general[11]),
			MaxConcurrentSessions = tonumber(general[12]),
			ConnectTypesSupported = sconsole_types
		}
	end
	if general[13] or general[14] or #cmdshl_types > 0 then
		response["CommandShell"] = {
			ServiceEnabled = utils.bool(general[13]),
			MaxConcurrentSessions = tonumber(general[14]),
			ConnectTypesSupported = cmdshl_types
		}
	end
	response["FirmwareVersion"] = general[15]
	-- Properties that consist of @odata.id links to other resources should only be included if the reference is found to exist in Redis
	if #np_exists > 0 then
		response["NetworkProtocol"] = response["NetworkProtocol"] or {}
		response["NetworkProtocol"]["@odata.id"] = CONFIG.SERVICE_PREFIX.."/"..collection.."/"..id.."/NetworkProtocol"
	end
	if #eth_exists > 0 then
		response["EthernetInterfaces"] = response["EthernetInterfaces"] or {}
		response["EthernetInterfaces"]["@odata.id"] = CONFIG.SERVICE_PREFIX.."/"..collection.."/"..id.."/EthernetInterfaces"
	end
	if #host_exists > 0 then
		response["HostInterfaces"] = response["HostInterfaces"] or {}
		response["HostInterfaces"]["@odata.id"] = CONFIG.SERVICE_PREFIX.."/"..collection.."/"..id.."/HostInterfaces"
	end
	if #ser_exists > 0 then
		response["SerialInterfaces"] = response["SerialInterfaces"] or {}
		response["SerialInterfaces"]["@odata.id"] = CONFIG.SERVICE_PREFIX.."/"..collection.."/"..id.."/SerialInterfaces"
	end
	if #log_exists > 0 then
		response["LogServices"] = response["LogServices"] or {}
		response["LogServices"]["@odata.id"] = CONFIG.SERVICE_PREFIX.."/"..collection.."/"..id.."/LogServices"
	end
	if #vm_exists > 0 then
		response["VirtualMedia"] = response["VirtualMedia"] or {}
		response["VirtualMedia"]["@odata.id"] = CONFIG.SERVICE_PREFIX.."/"..collection.."/"..id.."/VirtualMedia"
	end
	-- All actions key starts with # 
	-- Target will be automatically added to server handler
	-- AllowableValues are expected in the actions
	self:add_action({
			["#Manager.Reset"] = {
				target = CONFIG.SERVICE_PREFIX.."/"..collection.."/"..id.."/Actions/Manager.Reset",
				["ResetType@Redfish.AllowableValues"] = allowed_resets
			}
		})
	-- ForceFailover and ModifyRedundancySet are not meaningful except in certain systems that have multiple truly redudant Managers
	--  self:add_action({
	--  		["#Manager.ForceFailover"] = {
	--  			target = CONFIG.SERVICE_PREFIX.."/"..collection.."/"..id.."/Actions/Manager.ForceFailover"
	--  		}
	-- 	})
	--  self:add_action({
	-- 		["#Manager.ModifyRedundancySet"] = {
	-- 			target = CONFIG.SERVICE_PREFIX.."/"..collection.."/"..id.."/Actions/Manager.ModifyRedundancySet"
	-- 		}
	-- 	})

	-- Fill in rendundancy properties
	if redundancy_keys then
		response["Redundancy"] = response["Redundancy"] or {}
		for i, key in ipairs(redundancy_keys) do
			local redundancy_id = key:split(":")[5]
			local redundancy_general = db_result[12 + 3*i - 2]
			local redundancy_status = db_result[12 + 3*i - 1]
			local redundancy_set = db_result[12 + 3*i]
			response["Redundancy"][i] = 
				self:oem_extend({
					Name = redundancy_general[1],
					MemberId = redundancy_id,
					Mode = redundancy_general[2],
					MaxNumSupported = redundancy_general[3],
					MinNumNeeded = redundancy_general[4],
					Status = {
						State = redundancy_status[1],
						Health = redundancy_status[2]
					},
					RedundancySet = utils.getODataIDArray(redundancy_set)
				}, "query.manager.manager-redundancy")
		end
	end
	-- Add OEM extension properties to the response
	response["Links"] = self:oem_extend({
		ManagerForServers = utils.getODataIDArray(mngr_srvr),
		ManagerForChassis = utils.getODataIDArray(mngr_chassis)
	}, "query." .. self:get_oem_instance_link_path())
	response["Actions"] = self:oem_extend(response["Actions"], "query." .. self:get_oem_instance_action_path())
	response = self:oem_extend(response, "query." .. self:get_oem_instance_path())
	-- Set the OData context and type for the response
	local sL_table = _.keys(response)
	if #sL_table < 22 then
		local selectList = turbo.util.join(',', sL_table)
		self:set_context(CONSTANTS.MANAGER_INSTANCE_CONTEXT .. "(" .. selectList .. ")")
	else
		self:set_context(CONSTANTS.MANAGER_INSTANCE_CONTEXT .. "(*)")
	end
	self:set_type(CONSTANTS.MANAGER_TYPE)
	-- Remove extraneous fields from the response
	utils.remove_nils(response)

	-- GET requests must respond with the 'Allow' header specifying what methods are available for the given URL
	self:set_allow_header("GET, PATCH")
end

-- #### PATCH handler for Manager instance
function ManagerHandler:patch_instance(response)
	-- Set up the local space: get a connection with Redis DB, gather url segment, establish redis prefix, and set scope.
	local redis = self:get_db()

	local collection, id = self.url_segments[1], self.url_segments[2];

	local prefix = "Redfish:Managers:" .. id
	self:set_scope(prefix)

	local pl = redis:pipeline()

	-- Get the request body.
	local request_data = turbo.escape.json_decode(self:get_request().body)

	-- The 'extended' table will hold all of our "@Message.ExtendedInfo" errors that accumulate while making changes.
	local extended = {}
	local successful_sets = {}
	local keys_to_watch = {}
	-- The 'patch_operations' table holds functions that know how to PATCH each property.
	-- For each property, validate the value, then create an error message or add appropriate Redis command based on outcome.
	local patch_operations = {
		["SerialConsole.ServiceEnabled"] = function(pipe, value)
			if not type(value) == "boolean" then
				table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/SerialConsole/ServiceEnabled"}, {tostring(value), "SerialConsole/ServiceEnabled"}))
				
			else
				pipe:set(prefix..":SerialConsole:ServiceEnabled", tostring(value))
				table.insert(successful_sets, "SerialConsole:ServiceEnabled")
			end
		end,
		["CommandShell.ServiceEnabled"] = function(pipe, value)
			if not type(value) == "boolean" then
				table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/CommandShell/ServiceEnabled"}, {tostring(value), "CommandShell/ServiceEnabled"}))
				
			else
				pipe:set("PATCH:"..prefix..":CommandShell:ServiceEnabled", tostring(value))
				table.insert(successful_sets, "CommandShell:ServiceEnabled")
				table.insert(keys_to_watch, prefix..":CommandShell:ServiceEnabled")
			end
		end,
		["GraphicalConsole.ServiceEnabled"] = function(pipe, value)
			if not type(value) == "boolean" then
				table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/GraphicalConsole/ServiceEnabled"}, {tostring(value), "GraphicalConsole/ServiceEnabled"}))
				
			else
				pipe:set("PATCH:"..prefix..":GraphicalConsole:ServiceEnabled", tostring(value))
				table.insert(successful_sets, "GraphicalConsole:ServiceEnabled")
				table.insert(keys_to_watch, prefix..":GraphicalConsole:ServiceEnabled")
			end
		end,
		["DateTime"] = function(pipe, value)
			if not type(value) == "string" then

				table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/DateTime"}, {tostring(value), "DateTime"}))

			elseif string.match(value, "^[1-2][0-9][0-9][0-9][-][0-1][0-9][-][0-3][0-9]T[0-2][0-9]:[0-5][0-9]:[0-5][0-9]Z$") == nil and
					string.match(value, "^[1-2][0-9][0-9][0-9][-][0-1][0-9][-][0-3][0-9]T[0-2][0-9]:[0-5][0-9]:[0-5][0-9][-+][0-1][0-9]:[0-5][0-9]$") == nil then

				table.insert(extended, self:create_message("Base", "PropertyValueFormatError", {"#/DateTime"}, {value, "DateTime"}))

			else
				pipe:set("PATCH:"..prefix..":DateTime", tostring(value))
				table.insert(successful_sets, "DateTime")
			end
		end,
		["DateTimeLocalOffset"] = function(pipe, value)
			if not type(value) == "string" then

				table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/DateTimeLocalOffset"}, {tostring(value), "DateTimeLocalOffset"}))

			elseif string.match(value, "^[-+][0-1][0-9]:[0-5][0-9]$") == nil then

				table.insert(extended, self:create_message("Base", "PropertyValueFormatError", {"#/DateTimeLocalOffset"}, {value, "DateTimeLocalOffset"}))

			else
				pipe:set("PATCH:"..prefix..":DateTimeLocalOffset", tostring(value))
				table.insert(successful_sets, "DateTimeLocalOffset")
			end
		end
	}

	-- Split the request body into read-only and writable properties.
	local readonly_body
	local writable_body
	local leftover_body
	readonly_body, writable_body, leftover_body = utils.readonlyCheck(request_data, property_access)

	-- Add commands to pipeline as needed by referencing our 'patch_operations' table.
	if writable_body then
		for property, value in pairs(writable_body) do
			if type(value) == "table" then
				for prop2, val2 in pairs(value) do
					patch_operations[property.."."..prop2](pl, val2)
				end
			else
				patch_operations[property](pl, value)
			end  
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

		--Checking for unknown properties if any
	local leftover_fields = utils.table_len(leftover_body)
	if leftover_fields ~= 0 and leftover_body ~= nil then
		local keys = _.keys(leftover_body)
		for k, v in pairs(keys) do
			table.insert(extended, self:create_message("Base", "PropertyUnknown", "#/" .. v, v))
		end
	end

	-- Run any pending database commands.
	if #pl.pending_commands > 0 then

		-- doPATCH will block until it sees that the keys we are PATCHing have been changed, or receives an error response about why the PATCH failed, or until it times out
		-- doPATCH returns a table of any error messages received, and, if a timeout occurs, any keys that had yet to be modified when the timeout happened

		-- if keys_to_watch is empty then there are no PATCH operations that require a wait, so we can skip the doPATCH call
		if #keys_to_watch == 0 then

			local result = yield(pl:run())

		else
			local patch_errors, timedout_keys, result = self:doPATCH(keys_to_watch, pl, CONFIG.PATCH_TIMEOUT)
			for _i, err in pairs(patch_errors) do
				table.insert(extended, self:create_message(err.Registry, err.MessageId, err.RelatedProperties, err.MessageArgs))
			end
			for _i, to_key in pairs(timedout_keys) do
				local property_key = to_key:split("Managers:[^:]*:", nil, true)[2]
				local key_segments = property_key:split(":")
				local property_name = "#/" .. table.concat(key_segments, "/")
				table.insert(extended, self:create_message("SyncAgent", "PatchTimeout", property_name, {CONFIG.PATCH_TIMEOUT/1000, property_name}))
			end
		end

		self:update_lastmodified(self:get_scope(), os.time())
		self:add_audit_log_entry(self:create_message("Security", "ResourceModified", nil, {turbo.util.join(", ", successful_sets), self:get_request().path}))
	end

	-- If we caught any errors along the way, add them to the response.
	if #extended ~= 0 then
		self:add_error_body(response,400,unpack(extended))
	else
		self:set_status(204)
	end
end

return ManagerHandler
