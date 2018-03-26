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

local ChassisLogServiceHandler = class("ChassisLogServiceHandler", RedfishHandler)

local yield = coroutine.yield

-- Set the path names for chassis log service OEM extensions
local collection_oem_path = "chassis.chassis-logservice-collection"
local instance_oem_path = "chassis.chassis-logservice-instance"
local action_oem_path = "chassis.chassis-logservice-instance-actions"
ChassisLogServiceHandler:set_all_oem_paths(collection_oem_path, instance_oem_path, nil, action_oem_path)

-- The 'property_access' table specifies read/write permission for all properties.
local property_access = require("property-access.LogService")["LogService"]

-- ### GET request handler for Chassis/LogServices
function ChassisLogServiceHandler:get(id1, id2)

	local response = {}

	-- Create the GET response for Log Service collection or instance, based on what 'id' was given.
	if id2 == nil then
		self:get_collection(response)
	else
        self:get_instance(response)
	end

	-- After the response is created, we register it with the handler and then output it to the client.
	self:set_response(response)

	self:output()
end

-- ### PATCH request handler for Chassis/LogServices
function ChassisLogServiceHandler:patch(id1, id2)	

	local response = {}

	-- Check Redis for the presence of the chassis resource in question. If it isn't found, throw a 404
	local redis = self:get_db()
	
  local _exists = yield(redis:exists("Redfish:Chassis:"..id1..":ChassisType"))
	if _exists == 0 then
		self:error_resource_missing_at_uri()
	end

	-- Create the PATCH response for Log Service collection or instance, based on what 'id' was given.

	if id2 == nil then
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

		-- Check if user is authorized to make changes.
		if self:can_user_do("ConfigureComponents") == true then
			-- If so, patch the resource and respond with the updated version. 
			self:patch_instance(response)
			self:get_instance(response)
		else
			--Throw an error if the user is not authorized.
			self:error_insufficient_privilege()
		end
	end

	-- After the response is created, we register it with the handler and then output it to the client.
	self:set_response(response)

	self:output()
end

local allowed_clears = { "ClearAll" }

-- #### GET handler for Log Services collection
function ChassisLogServiceHandler:get_collection(response)
	-- Before proceeding with the handler, we'll make sure the collection request is valid
	local collection_exists = self:parent_exists()
	self:assertTrue_404(collection_exists)

	-- Set up the local space: get a connection with Redis DB, gather url segment, establish redis prefix, and set scope
	local redis = self:get_db()

	local collection, instance, secondary_collection = 
		self.url_segments[1], self.url_segments[2], self.url_segments[3];

	local prefix = "Redfish:Chassis:"..instance..":LogServices:"

	self:set_scope("Redfish:"..table.concat(self.url_segments,':'))
	-- Fill in Name and Description fields
	response["Name"] = "Log Service Collection"
	response["Description"] = "Collection of Log Services for this Chassis"
	-- Search Redis for any Log Services, and pack the results into an array
	local odataIDs = utils.getODataIDArray(yield(redis:keys(prefix.."*:ServiceEnabled")), 1)
	-- Set Members fields based on results from Redis
	response["Members@odata.count"] = #odataIDs
	response["Members"] = odataIDs

	-- Add OEM extension properties to the response
	response = self:oem_extend(response, "query." .. self:get_oem_collection_path())
	-- Set the OData context and type for the response
	self:set_context(CONSTANTS.LOGSERVICE_COLLECTION_CONTEXT)
	self:set_type(CONSTANTS.LOG_SERVICE_COLLECTION_TYPE)

	-- GET requests must respond with the 'Allow' header specifying what methods are available for the given URL
	self:set_allow_header("GET")
end

-- #### GET handler for Log Service instance
function ChassisLogServiceHandler:get_instance(response)
	-- Set up the local space: get a connection with Redis DB, gather url segment, establish redis prefix, and set scope
	local redis = self:get_db()

	local collection, instance, secondary_collection, id = 
		self.url_segments[1], self.url_segments[2], self.url_segments[3], self.url_segments[4];

	local prefix = "Redfish:Chassis:"..instance..":LogServices:"..id
	
	self:set_scope("Redfish:"..table.concat(self.url_segments,':'))
	-- Create a Redis pipeline and add commands for all Log Service properties
	local pl = redis:pipeline()

	pl:mget({
			prefix..":Name",
			prefix..":Description",
			prefix..":ServiceEnabled",
			prefix..":MaxNumberOfRecords",
			prefix..":OverWritePolicy",
			prefix..":DateTime",
			prefix..":DateTimeLocalOffset"
			})
	pl:hmget(prefix..":Status", "State", "Health")
	-- Run the Redis pipeline, and unpack the results  
	local db_result = yield(pl:run())

	-- Check that data was found in Redis, if not we throw a 404 NOT FOUND
	self:assert_resource(db_result)

	local general, status = unpack(db_result)
	-- Add the data from Redis into the response, converting types where necessary
	response["Id"] = id
	response["Name"] = general[1]
	response["Description"] = general[2]
	if type(general[3]) ~= "nil" then
		response["ServiceEnabled"] = utils.bool(general[3])
	end
	response["MaxNumberOfRecords"] = tonumber(general[4])
	response["OverWritePolicy"] = general[5]
	response["DateTime"] = general[6]
	response["DateTimeLocalOffset"] = general[7]
	if status[1] or status[2] then
		response["Status"] = {
			State = status[1],
			Health = status[2]
		}
	end
	response["Entries"] = response["Entries"] or {}
	response["Entries"]["@odata.id"] = CONFIG.SERVICE_PREFIX..'/'..collection..'/'..instance..'/LogServices/'..id..'/Entries'
	self:add_action({
			["#LogService.ClearLog"] = {
				target = CONFIG.SERVICE_PREFIX..'/'..collection..'/'..instance..'/'..secondary_collection..'/'..id..'/Actions/LogService.ClearLog',
				["ClearType@Redfish.AllowableValues"] = allowed_clears
			}
		})
	-- Add OEM extension properties to the response
	response["Actions"] = self:oem_extend(response["Actions"], "query." .. self:get_oem_instance_action_path())
	response = self:oem_extend(response, "query." .. self:get_oem_instance_path())
	-- Set the OData context and type for the response
	local sL_table = _.keys(response)
	if #sL_table < 11 then
        local selectList = turbo.util.join(',', sL_table)
		self:set_context(CONSTANTS.LOGSERVICE_INSTANCE_CONTEXT.."("..selectList..")")
	else
		self:set_context(CONSTANTS.LOGSERVICE_INSTANCE_CONTEXT)
	end
	self:set_type(CONSTANTS.LOG_SERVICE_TYPE)
	-- Remove extraneous fields from the response
	utils.remove_nils(response)

	-- GET requests must respond with the 'Allow' header specifying what methods are available for the given URL
	self:set_allow_header("GET, PATCH")
end

function ChassisLogServiceHandler:patch_instance(response)
	-- Set up the local space: get a connection with Redis DB, gather url segment, establish redis prefix, and set scope.
	local redis = self:get_db()

	local collection, instance, secondary_collection, id = 
		self.url_segments[1], self.url_segments[2], self.url_segments[3], self.url_segments[4];

	local prefix = "Redfish:Chassis:"..instance..":LogServices:"..id
	
	self:set_scope("Redfish:"..table.concat(self.url_segments,':'))

	local pl = redis:pipeline()

	-- Get the request body.
	local request_data = turbo.escape.json_decode(self:get_request().body)

	-- The 'extended' table will hold all of our "@Message.ExtendedInfo" errors that accumulate while making changes.
    local extended = {}
    local successful_sets = {}
	-- The 'patch_operations' table holds functions that know how to PATCH each property.
	-- For each property, validate the value, then create an error message or add appropriate Redis command based on outcome.
    local patch_operations = {
		["ServiceEnabled"] = function(pipe, value)
			if not type(value) == "boolean" then
				table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/ServiceEnabled"}, {tostring(value), "ServiceEnabled"}))
			else
				pipe:set(prefix..":ServiceEnabled", tostring(value))
				table.insert(successful_sets, "ServiceEnabled")
			end
		end,
		["DateTime"] = function(pipe, value)
			-- TODO: need to add correct DateTime validation
			if not type(value) == "string" then
				table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/DateTime"}, {tostring(value), "DateTime"}))
			else
				pipe:set(prefix..":DateTime", tostring(value))
				table.insert(successful_sets, "DateTime")
			end
		end,
		["DateTimeLocalOffset"] = function(pipe, value)
			-- TODO: need to add correct DateTime validation
			if not type(value) == "string" then
				table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/DateTimeLocalOffset"}, {tostring(value), "DateTimeLocalOffset"}))
			else
				pipe:set(prefix..":DateTimeLocalOffset",  tostring(value))
				table.insert(successful_sets, "DateTimeLocalOffset")
			end
		end
	}

	-- Split the request body into read-only and writable properties.
	local readonly_body
	local writable_body
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
		local res = yield(pl:run())
		self:add_audit_log_entry(self:create_message("Security", "ResourceModified", nil, {turbo.util.join(", ", successful_sets), self:get_request().path}))

	end
end

return ChassisLogServiceHandler