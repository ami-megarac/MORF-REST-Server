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
-- [See "config.lua"](/config.html)
local CONFIG = require("config")
-- [See "utils.lua"](/utils.html)
local utils = require("utils")
-- [See "turbo library"](http://turbolua.org)
local turbo = require("turbo")
-- [See "underscore.lua"](https://mirven.github.io/underscore.lua/)
local _ = require("underscore")

local RoleHandler = class("RoleHandler", RedfishHandler)

local yield = coroutine.yield

-- Set the path names for role OEM extensions
local collection_oem_path = "account-service.accountservice-role-collection"
local instance_oem_path = "account-service.accountservice-role-instance"
RoleHandler:set_all_oem_paths(collection_oem_path, instance_oem_path, nil, nil, nil)

--Handles GET requests for Role collection and instance
function RoleHandler:get(instance)

	local response = {}

	if instance == "/redfish/v1/AccountService/Roles" then
		--GET collection
		self:get_collection(response)
	else
		--GET instance
		self:get_instance(response)
	end

	self:set_response(response)

	self:output()
end

--Handles GET Role collection
function RoleHandler:get_collection(response)
	-- Before proceeding with the handler, we'll make sure the collection request is valid
	local collection_exists = self:parent_exists()
	self:assertTrue_404(collection_exists)

	local redis = self:get_db()
	local url_segments = self:get_url_segments();

	local collection, secondary_collection = url_segments[1], url_segments[2];

	local prefix = "Redfish:" .. collection .. ":" .. secondary_collection

	self:set_scope("Redfish:" .. table.concat(url_segments, ":"))

	-- Creating response
	response["Name"] = "Roles Collection"

	local odataIDs = utils.getODataIDArray(yield(redis:keys(prefix .. ":*:Name")), 1)

	response["Members@odata.count"] = #odataIDs
	response["Members"] = odataIDs

	response = self:oem_extend(response, "query." .. self:get_oem_collection_path())

	self:set_context(CONSTANTS.ROLE_COLLECTION_CONTEXT)
	self:set_type(CONSTANTS.ROLE_COLLECTION_TYPE)
	
		-- GET requests must respond with the 'Allow' header specifying what methods are available for the given URL
	self:set_allow_header("GET, POST")
	
end

--Handles GET Role instance
function RoleHandler:get_instance(response)
	local redis = self:get_db()
	local url_segments = self:get_url_segments();

	local collection, secondary_collection, id = url_segments[1], url_segments[2], url_segments[3];

	local prefix = "Redfish:" .. collection .. ":" .. secondary_collection .. ":" .. id

	self:set_scope("Redfish:" .. table.concat(url_segments, ":"))

	local pl = redis:pipeline()

	--Retrieving data from database
	pl:mget({
			prefix .. ":Name",
			prefix .. ":Description",
			prefix .. ":IsPredefined"
		})
	pl:smembers(prefix .. ":AssignedPrivileges")
	pl:smembers(prefix .. ":OemPrivileges")

	-- Check that data was found in Redis, if not we throw a 404 NOT FOUND
	local db_result = yield(pl:run())
	self:assert_resource(db_result)

	local general, assigned, oem = unpack(db_result)

	--Creating response using data from database
	response["Id"] = id
	response["Name"] = general[1]
	response["Description"] = general[2]
	response["IsPredefined"] = utils.bool(general[3])
	response["AssignedPrivileges"] = assigned
	response["OemPrivileges"] = oem

	response = self:oem_extend(response, "query." .. self:get_oem_instance_path())

	utils.remove_nils(response)

	local keys = _.keys(response)
	if #keys < 6 then
		local select_list = turbo.util.join(",", keys)
		self:set_context(CONSTANTS.ROLE_INSTANCE_CONTEXT .. "(" .. select_list .. ")")
	else
		self:set_context(CONSTANTS.ROLE_INSTANCE_CONTEXT .. "(*)")
	end

	if not utils.bool(general[3]) then
		self:set_allow_header("GET, PATCH, DELETE")
	else
		self:set_allow_header("GET")
	end
	self:set_type(CONSTANTS.ROLE_TYPE)
end

--Handling POST request for Role
function RoleHandler:post(id)
	local url_segments = self:get_url_segments();
	local collection, secondary_collection, instance = url_segments[1], url_segments[2], url_segments[3]
	local arr = {"Operator","Administrator","ReadOnly"}
	
	if instance ~= nil then
		if not turbo.util.is_in(instance, arr) then
			self:error_resource_missing_at_uri()
		end
	end

	--Throwing error if request is to collection
	if secondary_collection == nil then
		-- When an HTTP method is rejected with status code 405, we must set an Allow header that lists valid HTTP methods for the URI
	    self:set_header("Allow", "GET")
		-- No PATCH for collections
	    self:error_method_not_allowed()
	end

	if id ~= "/redfish/v1/AccountService/Roles" then
		self:set_allow_header("GET, PATCH, DELETE")
		-- No PATCH for collections
	    self:error_method_not_allowed()
	end

	--Making sure current user has permission to modify role settings
	if self:can_user_do("ConfigureUsers") == true then
		local redis = self:get_db()
		local request_data = turbo.escape.json_decode(self:get_request().body)
		local response = {}
		local extended = {}

		if request_data.Id == nil then
			table.insert(extended, self:create_message("Base", "PropertyMissing", {"#/Id"}, "Id"))
		end

		--Making sure required AssignedPrivileges field is present
		if request_data.AssignedPrivileges == nil and request_data.OemPrivileges == nil then
			table.insert(extended, self:create_message("Base", "PropertyMissing", {"#/AssignedPrivileges or #/OemPrivileges"}, "AssignedPrivileges or OemPrivileges"))
		end

		--Making sure required Name field is present
		if request_data.Name == nil then
			table.insert(extended, self:create_message("Base", "PropertyMissing", {"#/Name"}, "Name"))
		end

		--Responding with an error if an error is found
		if #extended ~= 0 then
			self:add_error_body(response, 400, unpack(extended))
			self:set_response(response)
			self:output()
			return
		end

		--Checking if role already exists
		local roles = yield(redis:keys("Redfish:" .. collection .. ":" .. secondary_collection .. ":*:AssignedPrivileges"))
		for key, val in pairs(roles) do
			local parts = utils.split(val, ":")
			local cur_role = parts[table.getn(parts) - 1]

			if cur_role == request_data.Id then
				self:error_resource_already_exists()
			end
		end

		--Creating new role with request data
		local pl = redis:pipeline()
		local prefix = "Redfish:" .. collection .. ":" .. secondary_collection .. ":" .. request_data.Id
		pl:set(prefix .. ":Name", request_data.Name)
		if request_data.Description then
			pl:set(prefix .. ":Description", request_data.Description)
		end
		pl:set(prefix .. ":IsPredefined", "false")
		if request_data.AssignedPrivileges then
			pl:sadd(prefix .. ":AssignedPrivileges", request_data.AssignedPrivileges)
		end
		if request_data.OemPrivileges then
			pl:sadd(prefix .. ":OemPrivileges", request_data.OemPrivileges)
		end
		-- Update last modified so that E-Tag can respond properly
		self:update_lastmodified(prefix, os.time(), pl, 2)
		local result = yield(pl:run())

		--Retrieving data from database
		pl = redis:pipeline()
		pl:mget({
				prefix .. ":Name",
				prefix .. ":Description",
				prefix .. ":IsPredefined"
			})
		pl:smembers(prefix .. ":AssignedPrivileges")
		pl:smembers(prefix .. ":OemPrivileges")

		local general, assigned, oem = unpack(yield(pl:run()))

		--Creating response using data from database
		response["Id"] = request_data.Id
		response["Name"] = general[1]
		response["Description"] = general[2]
		response["IsPredefined"] = utils.bool(general[3])
		response["AssignedPrivileges"] = assigned
		response["OemPrivileges"] = oem

		response = self:oem_extend(response, "query." .. self:get_oem_instance_path())

		utils.remove_nils(response)

		local keys = _.keys(response)
		if #keys < 6 then
			local select_list = turbo.util.join(",", keys)
			self:set_context(CONSTANTS.ROLE_INSTANCE_CONTEXT .. "(" .. select_list .. ")")
		else
			self:set_context(CONSTANTS.ROLE_INSTANCE_CONTEXT)
		end
		self:update_lastmodified(prefix, os.time())
		self:set_status(201)
		local new_role_uri = CONFIG.SERVICE_PREFIX .. "/" .. collection .. "/" .. secondary_collection .. "/" .. request_data.Id
		utils.add_event_entry(redis, "Redfish:Managers:Self:LogServices:EventLog", "EventLog.1.0.0", "ResourceAdded", {new_role_uri}, "Event", "Informational", prefix, nil, nil, new_role_uri .. " - " .. tostring(os.time()), "ResourceAdded")

		self:add_header("Location", new_role_uri)
		self:set_type(CONSTANTS.ROLE_TYPE)
		self:set_response(response)
		self:output()
	else
		--Throwing error if user is not authorized
		self:error_insufficient_privilege()
	end
end

--Handles PATCH request for Role
function RoleHandler:patch()
	local url_segments = self:get_url_segments();
	local collection, secondary_collection, instance = url_segments[1], url_segments[2], url_segments[3]
	local response = {}

	--Throwing error if request is to collection
	if instance == nil then
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
	end

	--Making sure current user has permission to modify role settings
	if self:can_user_do("ConfigureUsers") == true then
		local redis = self:get_db()
		local request_data = turbo.escape.json_decode(self:get_request().body)
		local extended = {}

		--Making sure the role is not a predefined role
		local predefined = yield(redis:get("Redfish:" .. collection .. ":" .. secondary_collection .. ":" .. instance .. ":IsPredefined"))
		if predefined == nil then
			self:error_resource_missing_at_uri()
		end

		if utils.bool(predefined) == true then
			self:set_header("Allow", "GET")
			self:error_method_not_allowed()
		end

		local pl = redis:pipeline()
		local prefix = "Redfish:" .. collection .. ":" .. secondary_collection .. ":" .. instance

		--Deleting and then setting AssignedPrivileges
		if request_data.AssignedPrivileges ~= nil then
			pl:del(prefix .. ":AssignedPrivileges", request_data.AssignedPrivileges)
			pl:sadd(prefix .. ":AssignedPrivileges", request_data.AssignedPrivileges)
			request_data.AssignedPrivileges = nil
		end

		--Deleting and then setting OemPrivileges
		if request_data.OemPrivileges ~= nil then
			pl:del(prefix .. ":OemPrivileges", request_data.OemPrivileges)
			pl:sadd(prefix .. ":OemPrivileges", request_data.OemPrivileges)
			request_data.OemPrivileges = nil
		end

		if #pl.pending_commands > 0 then
			-- Update last modified so that E-Tag can respond properly
			self:update_lastmodified(prefix, os.time(), pl, 2)

			local result = yield(pl:run())
		end

		--Checking if there are any additional properties in the request and creating an error to show these properties
		local leftover_fields = utils.table_len(request_data)
		if leftover_fields ~= 0 then
			local keys = _.keys(request_data)
			table.insert(extended, self:create_message("Base", "PropertyNotWritable", keys, turbo.util.join(",", keys)))
		end

		--Checking if there were errors and adding them to the response if there are
		if #extended ~= 0 then
			self:add_error_body(response,400,unpack(extended))
		else
			self:update_lastmodified(prefix, os.time())
			self:set_status(204)
		end

		self:set_response(response)
		self:output()
	else
		--Throwing error if user is not authorized
		self:error_insufficient_privilege()
	end
end

--Handles DELETE request for Role
function RoleHandler:delete()
	local url_segments = self:get_url_segments();
	local collection, secondary_collection, instance = url_segments[1], url_segments[2], url_segments[3]
	local response = {}

	--Throwing error if request is to collection
	if instance == nil then
		-- When an HTTP method is rejected with status code 405, we must set an Allow header that lists valid HTTP methods for the URI
	    self:set_header("Allow", "GET")
		-- No PATCH for collections
	    self:error_method_not_allowed()
	end

	--Making sure current user has permission to modify role settings
	if self:can_user_do("ConfigureUsers") == true then
		local redis = self:get_db()

		--Making sure the role is not a predefined role
		local predefined = yield(redis:get("Redfish:" .. collection .. ":" .. secondary_collection .. ":" .. instance .. ":IsPredefined"))
		if predefined == nil then
			self:error_resource_missing_at_uri(response)
		end
		
		if utils.bool(predefined) == true then
			self:set_header("Allow", "GET")
		    self:error_method_not_allowed()
		end
		
		--Deleting user
		local role_info = yield(redis:keys("Redfish:" .. collection .. ":" .. secondary_collection .. ":" .. instance .. ":*"))
		if #role_info == 0 then
			self:error_resource_missing_at_uri()
		end
		yield(redis:del(unpack(role_info)))

		local deleted_role_uri = CONFIG.SERVICE_PREFIX .. "/" .. collection .. "/" .. secondary_collection .. "/" .. instance
		utils.add_event_entry(redis, "Redfish:Managers:Self:LogServices:EventLog", "EventLog.1.0.0", "ResourceRemoved", {deleted_role_uri}, "Event", "Informational", "Redfish:" .. collection .. ":" .. secondary_collection .. ":" .. instance, nil, nil, deleted_role_uri .. " - " .. tostring(os.time()), "ResourceRemoved")
		
		-- Update last modified so that E-Tag can respond properly
		self:update_lastmodified("Redfish:" .. collection .. ":" .. secondary_collection, os.time(), nil, 1)		
		self:set_status(204)
	else
		--Throwing error if user is not authorized
		self:error_insufficient_privilege()
	end
end

return RoleHandler