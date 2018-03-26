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

local LogServiceHandler = class("LogServiceHandler", RedfishHandler)

local yield = coroutine.yield

-- Set the path names for manager log service OEM extensions
local collection_oem_path = "manager.manager-logservice-collection"
local instance_oem_path = "manager.manager-logservice-instance"
local action_oem_path = "manager.manager-logservice-instance-actions"
LogServiceHandler:set_all_oem_paths(collection_oem_path, instance_oem_path, nil, action_oem_path)

-- The 'property_access' table specifies read/write permission for all properties.
local property_access = require("property-access.LogService")["LogService"]
--local overwrite = {"NeverOverWrites", "Unknown", "WrapsWhenFull"}
-- ### GET request handler for Manager/LogServices
function LogServiceHandler:get(_manager_id, id)

	local response = {}

	-- Create the GET response for Log Service collection or instance, based on what 'id' was given.
	if id == nil then
		self:get_collection(response)
	else
        self:get_instance(response)
	end

	-- After the response is created, we register it with the handler and then output it to the client.
	self:set_response(response)

	self:output()
end

-- ### PATCH request handler for Manager/LogServices
function LogServiceHandler:patch(_manager_id, id)	
	local url_segments = self:get_url_segments()
	local collection, instance, secondary_collection, inner_instance = url_segments[1], url_segments[2], url_segments[3], url_segments[4]
	
	--Throwing error if request is to collection
	if inner_instance == nil then
		-- Allow an OEM patch handler for manager log service collections, if none exists, return with the normal 405 response
		self:set_header("Allow", "GET")
		self:set_status(405)

		response = self:oem_extend(response, "patch." .. self:get_oem_collection_path())

		if self:get_status() == 405 then
			self:error_method_not_allowed()
		end
	else
		-- Allow the OEM patch handlers for manager log service instances to have the first chance to handle the request body
		response = self:oem_extend(response, "patch." .. self:get_oem_instance_path())
	end
	
	-- Check Redis for the presence of the Manager resource in question. If it isn't found, throw a 404
	if self:can_user_do("ConfigureManager") == true then
		local redis = self:get_db()
		local response = {}
		
		local man_exists = yield(redis:exists("Redfish:Managers:".._manager_id..":ManagerType"))
		if man_exists == 0 then
			self:add_error_body(response, 404, self:create_message("Base", "ResourceMissingAtURI", nil, "/redfish/v1/Managers/".._manager_id))
		else
			local request_data = turbo.escape.json_decode(self:get_request().body)
			self:set_scope("Redfish:" .. table.concat(url_segments, ":"))
			local pl = redis:pipeline()
			local prefix = "Redfish:" .. collection .. ":" .. instance .. ":" .. secondary_collection .. ":" .. inner_instance
			local extended = {}
			local successful_sets = {}
			--Validating ServiceEnabled property and adding error if property is incorrect
			if request_data.ServiceEnabled ~= nil then
				if type(request_data.ServiceEnabled) ~= "boolean" then
					table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/ServiceEnabled"}, {request_data.ServiceEnabled, "ServiceEnabled"}))
				else
					--ServiceEnabled is valid and will be added to database
					pl:set(prefix .. ":ServiceEnabled", tostring(request_data.ServiceEnabled))
					table.insert(successful_sets, "ServiceEnabled")
				end
				request_data.ServiceEnabled = nil
			end
			--Setting DateTime
			if request_data.DateTime ~= nil then
				if string.match(request_data.DateTime, "^[1-2][0-9][0-9][0-9][-][0-1][0-9][-][0-3][0-9]T[0-1][0-9]:[0-5][0-9]:[0-5][0-9]Z$") == nil and
					string.match(request_data.DateTime, "^[1-2][0-9][0-9][0-9][-][0-1][0-9][-][0-3][0-9]T[0-1][0-9]:[0-5][0-9]:[0-5][0-9][-+][0-1][0-9]:[0-5][0-9]$") == nil then
					table.insert(extended, self:create_message("Base", "PropertyValueFormatError", {"#/DateTime"}, {request_data.DateTime, "DateTime"}))
				else
					pl:set("PATCH:" .. prefix .. ":DateTime", request_data.DateTime)
					table.insert(successful_sets, "DateTime")
				end
				request_data.DateTime = nil
			end
			--Setting DateTimeLocalOffset
			if request_data.DateTimeLocalOffset ~= nil then
				if string.match(request_data.DateTimeLocalOffset, "^[-+][0-1][0-9]:[0-5][0-9]$") == nil then
					table.insert(extended, self:create_message("Base", "PropertyValueFormatError", {"#/DateTimeLocalOffset"}, {request_data.DateTimeLocalOffset, "DateTimeLocalOffset"}))
				else
					pl:set("PATCH:" .. prefix .. ":DateTimeLocalOffset", request_data.DateTimeLocalOffset)
					table.insert(successful_sets, "DateTimeLocalOffset")
				end
				request_data.DateTimeLocalOffset = nil
			end
			--Patching OverWritePolicy after validation
			--Removing Overwritepolicy property from patch operation
			--[[
			if request_data.OverWritePolicy ~= nil then
				if turbo.util.is_in(request_data.OverWritePolicy, overwrite)==nil then
					table.insert(extended, self:create_message("Base", "PropertyValueNotInList", {"#/OverWritePolicy"}, {request_data.OverWritePolicy, "OverWritePolicy"}))
				else
					pl:set(prefix .. ":OverWritePolicy", request_data.OverWritePolicy)
					table.insert(successful_sets, "OverWritePolicy")
				end
				request_data.OverWritePolicy = nil
			end
			]]--
			self:update_lastmodified(self:get_scope(),os.time(),pl,2)
			local result = yield(pl:run())
			self:add_audit_log_entry(self:create_message("Security", "ResourceModified", nil, {turbo.util.join(", ", successful_sets), self:get_request().path}))
            -- Split the request body into read-only and writable properties.
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
				for _i, ro_val in pairs(values) do
					table.insert(extended, self:create_message("Base", "PropertyNotWritable", ro_val, ro_val))
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
				for _i, unknown_val in pairs(keys) do
					table.insert(extended, self:create_message("Base", "PropertyUnknown", unknown_val, unknown_val))
				end
			end
			
			--Checking if there were errors and adding them to the response if there are
			if #extended ~= 0 then
				self:add_error_body(response,400, unpack(extended))
			else
				self:update_lastmodified(prefix, os.time())
				self:set_status(204)
			end
			
			-- After the response is created, we register it with the handler and then output it to the client.
			self:set_response(response)
			self:output()
		end
	else
		self:error_insufficient_privilege()
	end
end


local allowed_clears = { "ClearAll" }

-- #### GET handler for Log Services collection
function LogServiceHandler:get_collection(response)
	-- Before proceeding with the handler, we'll make sure the collection request is valid
	local collection_exists = self:parent_exists()
	self:assertTrue_404(collection_exists)

	-- Set up the local space: get a connection with Redis DB, gather url segment, establish redis prefix, and set scope
	local redis = self:get_db()

	local collection, instance, secondary_collection = 
		self.url_segments[1], self.url_segments[2], self.url_segments[3];

	local prefix = "Redfish:Managers:"..instance..":LogServices:"

	self:set_scope("Redfish:"..table.concat(self.url_segments,':'))
	-- Fill in Name and Description fields
	response["Name"] = "Log Service Collection"
	response["Description"] = "Collection of Log Services for this System"
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
function LogServiceHandler:get_instance(response)
	-- Set up the local space: get a connection with Redis DB, gather url segment, establish redis prefix, and set scope
	local redis = self:get_db()

	local collection, instance, secondary_collection, id = 
		self.url_segments[1], self.url_segments[2], self.url_segments[3], self.url_segments[4];

	local prefix = "Redfish:Managers:"..instance..":LogServices:"..id
	
	self:set_scope("Redfish:"..table.concat(self.url_segments,':'))

	-- date/time should be updated whenever it's queried (based on synced date/time setting)
	local sync_date_time = yield(redis:get(prefix .. ":SyncedDateTime"))
	local dt_prefix = prefix
	if sync_date_time == "true" then
		dt_prefix = "Redfish:Managers:"..instance
		local pl = redis:pipeline()
		pl:set("GET:Redfish:Managers:"..instance..":UpdateDateTime", "update")
		self:doGET({dt_prefix..":DateTime", dt_prefix..":DateTimeLocalOffset"}, pl, CONFIG.PATCH_TIMEOUT)
	end
	-- Create a Redis pipeline and add commands for all Log Service properties
	pl = redis:pipeline()

	pl:mget({
			prefix..":Name",
			prefix..":Description",
			prefix..":ServiceEnabled",
			prefix..":MaxNumberOfRecords",
			prefix..":OverWritePolicy",
			dt_prefix .. ":DateTime",
			dt_prefix .. ":DateTimeLocalOffset"
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
			State = general[3] == "true" and "Enabled" or "Disabled",
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

-- function LogServiceHandler:patch_instance(response)
-- 	-- Set up the local space: get a connection with Redis DB, gather url segment, establish redis prefix, and set scope.
-- 	local redis = self:get_db()

-- 	local collection, instance, secondary_collection, id = 
-- 		self.url_segments[1], self.url_segments[2], self.url_segments[3], self.url_segments[4];

-- 	local prefix = "Redfish:Managers:"..instance..":LogServices:"..id
	
-- 	self:set_scope("Redfish:"..table.concat(self.url_segments,':'))

-- 	local pl = redis:pipeline()

-- 	-- Get the request body.
-- 	local request_data = turbo.escape.json_decode(self:get_request().body)

-- 	-- The 'extended' table will hold all of our "@Message.ExtendedInfo" errors that accumulate while making changes.
--     local extended = {}
--     local successful_sets = {}
--     local keys_to_watch = {}
-- 	-- The 'patch_operations' table holds functions that know how to PATCH each property.
-- 	-- For each property, validate the value, then create an error message or add appropriate Redis command based on outcome.
--     local patch_operations = {
-- 		["ServiceEnabled"] = function(pipe, value)
-- 			if not type(value) == "boolean" then
-- 				table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/ServiceEnabled"}, {tostring(value), "ServiceEnabled"}))
-- 			else
-- 				pipe:set(prefix..":ServiceEnabled", tostring(value))
-- 				self:update_lastmodified(self:get_scope())
-- 				table.insert(successful_sets, "ServiceEnabled")
-- 			end
-- 		end,
-- 		["DateTime"] = function(pipe, value)
-- 			-- TODO: need to add correct DateTime validation
-- 			if not type(value) == "string" then
-- 				table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/DateTime"}, {tostring(value), "DateTime"}))
-- 			else
-- 				pipe:set("PATCH:"..prefix..":DateTime", tostring(value))
-- 				table.insert(keys_to_watch, prefix..":DateTime")
-- 				table.insert(successful_sets, "DateTime")
-- 			end
-- 		end,
-- 		["DateTimeLocalOffset"] = function(pipe, value)
-- 			-- TODO: need to add correct DateTime validation
-- 			if not type(value) == "string" then
-- 				table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/DateTimeLocalOffset"}, {tostring(value), "DateTimeLocalOffset"}))
-- 			else
-- 				pipe:set("PATCH:"..prefix..":DateTimeLocalOffset",  tostring(value))
-- 				table.insert(keys_to_watch, prefix..":DateTimeLocalOffset")
-- 				table.insert(successful_sets, "DateTimeLocalOffset")
-- 			end
-- 		end
-- 	}

-- 	-- Split the request body into read-only and writable properties.
-- 	local readonly_body
-- 	local writable_body
-- 	readonly_body, writable_body = utils.readonlyCheck(request_data, property_access)
-- 	-- Add commands to pipeline as needed by referencing our 'patch_operations' table.
-- 	if writable_body then
-- 		for property, value in pairs(writable_body) do
-- 			patch_operations[property](pl, value)
-- 		end
-- 	end

-- 	-- If the user attempts to PATCH read-only properties, respond with the proper error messages.
-- 	if readonly_body then
-- 		for property, value in pairs(readonly_body) do
-- 			if type(value) == "table" then
-- 		        for prop2, val2 in pairs(value) do
-- 					table.insert(extended, self:create_message("Base", "PropertyNotWritable", "#/"..property.."/"..prop2, tostring(property.."/"..prop2)))
-- 				end
-- 			else
-- 				table.insert(extended, self:create_message("Base", "PropertyNotWritable", "#/"..property, tostring(property)))
-- 			end
-- 		end
-- 	end
-- 	-- Run any pending database commands.
-- 	if #pl.pending_commands > 0 then
		
--         -- doPATCH will block until it sees that the keys we are PATCHing have been changed, or receives an error response about why the PATCH failed, or until it times out
--         -- doPATCH returns a table of any error messages received, and, if a timeout occurs, any keys that had yet to be modified when the timeout happened
--         local patch_errors, timedout_keys, result = self:doPATCH(keys_to_watch, pl, CONFIG.PATCH_TIMEOUT)
--         for _i, err in pairs(patch_errors) do
--             table.insert(extended, self:create_message(err.Registry, err.MessageId, err.RelatedProperties, err.MessageArgs))
--         end
--         for _i, to_key in pairs(timedout_keys) do
--             local property_key = to_key:split("LogServices:[^:]*:", nil, true)[2]
--             local key_segments = property_key:split(":")
--             local property_name = "#/" .. table.concat(key_segments, "/")
--             table.insert(extended, self:create_message("SyncAgent", "PatchTimeout", property_name, {CONFIG.PATCH_TIMEOUT/1000, property_name}))
--         end
-- 		self:add_audit_log_entry(self:create_message("Security", "ResourceModified", nil, {turbo.util.join(", ", successful_sets), self:get_request().path}))
-- 	end

-- 	-- If we caught any errors along the way, add them to the response.
-- 	if #extended ~= 0 then
-- 		response["@Message.ExtendedInfo"] = extended
-- 	end
-- end

return LogServiceHandler