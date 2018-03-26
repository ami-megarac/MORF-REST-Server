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
-- [See "md5.lua"](https://github.com/kikito/md5.lua)
local md5 = require("md5")

local AccountHandler = class("AccountHandler", RedfishHandler)

local yield = coroutine.yield

-- Set the path names for account OEM extensions
local collection_oem_path = "account-service.accountservice-account-collection"
local instance_oem_path = "account-service.accountservice-account-instance"
local link_oem_path = "account-service.accountservice-account-instance-links"
AccountHandler:set_all_oem_paths(collection_oem_path, instance_oem_path, nil, nil, link_oem_path)

--Handles GET requests for Account collection and instance
function AccountHandler:get(instance)

	local response = {}

	if instance == "/redfish/v1/AccountService/Accounts" then
		--GET collection
		self:get_collection(response)
	else
		--GET instance
		self:get_instance(response)
	end

	self:set_response(response)

	self:output()
end

--Handles GET Account collection
function AccountHandler:get_collection(response)
	-- Before proceeding with the handler, we'll make sure the collection request is valid
	local collection_exists = self:parent_exists()
	self:assertTrue_404(collection_exists)

	local redis = self:get_db()
	local url_segments = self:get_url_segments();

	local collection, secondary_collection = url_segments[1], url_segments[2];

	local prefix = "Redfish:" .. collection .. ":" .. secondary_collection

	self:set_scope("Redfish:" .. table.concat(url_segments, ":"))

	-- Creating response
	response["Name"] = "Accounts Collection"

	local odataIDs = utils.getODataIDArray(yield(redis:keys(prefix .. ":*:UserName")), 1)

	response["Members@odata.count"] = #odataIDs
	response["Members"] = odataIDs

	response = self:oem_extend(response, "query." .. self:get_oem_collection_path())

	self:set_context(CONSTANTS.ACCOUNT_COLLECTION_CONTEXT)
	self:set_type(CONSTANTS.MANAGER_ACCOUNT_COLLECTION_TYPE)

	-- GET requests must respond with the 'Allow' header specifying what methods are available for the given URL
	self:set_allow_header("GET, POST")
end

--Handles GET Account instance
function AccountHandler:get_instance(response, instance)
	local redis = self:get_db()
	local url_segments = self:get_url_segments();

	local collection, secondary_collection, id = url_segments[1], url_segments[2], url_segments[3]
	id = id or instance

	local prefix = "Redfish:" .. collection .. ":" .. secondary_collection .. ":" .. id

	self:set_scope("Redfish:" .. table.concat(url_segments, ":"))

	local pl = redis:pipeline()

	--Retrieving data from database
	pl:mget({
			prefix .. ":Name",
			prefix .. ":Description",
			prefix .. ":Enabled",
			prefix .. ":UserName",
			prefix .. ":RoleId",
			prefix .. ":Locked"
		})

	-- Check that data was found in Redis, if not we throw a 404 NOT FOUND
	local db_result = yield(pl:run())
	self:assert_resource(db_result)

	local general = unpack(db_result)

	--Creating response using data from database
	response["Id"] = tostring(id)
	response["Name"] = general[1]
	response["Description"] = general[2]
	response["Enabled"] = utils.bool(general[3])
	response["UserName"] = general[4]
	response["RoleId"] = general[5]
	response["Locked"] = utils.bool(general[6])

	response["Links"] = {}
	response["Links"]["Roles"] = {}
	response["Links"]["Roles"]["@odata.id"] = CONFIG.SERVICE_PREFIX .. "/" .. collection .. "/Roles/" .. general[5]
	self:oem_extend(response["Links"], "query." .. self:get_oem_instance_link_path())
	
	response = self:oem_extend(response, "query." .. self:get_oem_instance_path())
	utils.remove_nils(response)

	local keys = _.keys(response)
	if #keys < 8 then
		local select_list = turbo.util.join(",", keys)
		self:set_context(CONSTANTS.ACCOUNT_INSTANCE_CONTEXT .. "(" .. select_list .. ")")
	else
		self:set_context(CONSTANTS.ACCOUNT_INSTANCE_CONTEXT .. "(*)")
	end
	self:set_type(CONSTANTS.ACCOUNT_TYPE)

	-- GET requests must respond with the 'Allow' header specifying what methods are available for the given URL
	self:set_allow_header("GET, PATCH, DELETE")
end

--Handling POST request for Account
function AccountHandler:post(id)

	local url_segments = self:get_url_segments();
	local collection, secondary_collection = url_segments[1], url_segments[2];

	if secondary_collection == nil then
		-- When an HTTP method is rejected with status code 405, we must set an Allow header that lists valid HTTP methods for the URI
	    self:set_header("Allow", "GET")
		-- No PATCH for collections
	    self:error_method_not_allowed()
	end

	if id ~= "/redfish/v1/AccountService/Accounts" then
		self:set_allow_header("GET, PATCH, DELETE")
		-- No PATCH for collections
	    self:error_method_not_allowed()
	end

	local redis = self:get_db()
	local enabled = yield(redis:get("Redfish:" .. collection .. ":ServiceEnabled"))

	if enabled ~= "true" then
		self:error_service_disabled()
	end

	--Making sure current user has permission to modify user settings
	if self:can_user_do("ConfigureUsers") == true then
		local request_data = turbo.escape.json_decode(self:get_request().body)
		
		if request_data == nil or request_data =="" then
			self:error_unrecognized_request_body()
		end

		local response = {}
		local extended = {}

		--Making sure required Password field is present
		if request_data.Password == nil then
			table.insert(extended, self:create_message("Base", "PropertyMissing", {"#/Password"}, "Password"))
		else
			local min_password_len = yield(redis:get("Redfish:" .. collection .. ":MinPasswordLength"))
            if type(request_data.Password) == "string" then
                if #request_data.Password < tonumber(min_password_len) then
                    table.insert(extended, self:create_message("Base", "PropertyValueFormatError", {"#/Password"}, {"of length " .. #request_data.Password, "Password"}))
                end
            else 
                    table.insert(extended, self:create_message("Base", "PropertyValueFormatError", {"#/Password"}, {"type should be string", "Password"}))
            end
		end

		--Making sure required UserName field is present
		if request_data.UserName == nil then
			table.insert(extended, self:create_message("Base", "PropertyMissing", {"#/UserName"}, "UserName"))
		end

		--Making sure required RoleId field is present
		if request_data.RoleId == nil then
			table.insert(extended, self:create_message("Base", "PropertyMissing", {"#/RoleId"}, "RoleId"))
		else
			local roles = yield(redis:keys("Redfish:AccountService:Roles:*:Name"))
			if not turbo.util.is_in("Redfish:AccountService:Roles:" .. request_data.RoleId .. ":Name", roles) then
				table.insert(extended, self:create_message("Base", "PropertyValueNotInList", {"#/RoleId"}, {request_data.RoleId, "RoleId"}))
			end
		end

		--Validating Enabled property and adding error if property is incorrect
		if request_data.Enabled ~= nil and type(request_data.Enabled) ~= "boolean" then
			table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/Enabled"}, {request_data.Enabled, "Enabled"}))
		end

		--Responding with an error if an error is found
		if #extended ~= 0 then
			local error_msg = {}
			self:add_error_body(error_msg, 400, unpack(extended))
			self:write(error_msg)
			self:finish()
			return
		end

		--Making sure there is not a user with the same username and throwing an error if there is
		local users = yield(redis:keys("Redfish:" .. collection .. ":" .. secondary_collection .. ":*:UserName"))
		local ids = {}
		local index = 1
		for key, val in pairs(users) do
			local parts = utils.split(val, ":")
			local cur_user = yield(redis:get(val))

			if cur_user == request_data.UserName then
				self:error_resource_already_exists()
			end

			ids[parts[table.getn(parts) - 1] ] = 1
		end
		
		while ids[tostring(index)] ~= nil do
			index = index + 1
		end

		--Creating new user with request data
		local pl = redis:pipeline()
		local prefix = "Redfish:" .. collection .. ":" .. secondary_collection .. ":" .. index
		pl:set(prefix .. ":Name", request_data.Name)
		pl:set(prefix .. ":Description", request_data.Description)
		pl:set(prefix .. ":Enabled", tostring(request_data.Enabled))
		pl:set(prefix .. ":Password", md5.sumhexa(request_data.Password .. CONFIG.SALT))
		pl:set(prefix .. ":UserName", request_data.UserName)
		pl:set(prefix .. ":RoleId", request_data.RoleId)
		pl:set(prefix .. ":Role", "Redfish:AccountService:Roles:" .. request_data.RoleId)
		pl:set(prefix .. ":Locked", "false")

		-- Update last modified so that E-Tag can respond properly
		self:update_lastmodified(prefix, os.time(), pl)

		local result = yield(pl:run())
		
		local new_account_uri = CONFIG.SERVICE_PREFIX .. "/" .. collection .. "/" .. secondary_collection .. "/" .. index
		utils.add_event_entry(redis, "Redfish:Managers:Self:LogServices:EventLog", "EventLog.1.0.0", "ResourceAdded", {new_account_uri}, "Event", "Informational", prefix, nil, nil, new_account_uri .. " - " .. tostring(os.time()), "ResourceAdded")
        
        self.response_table["@odata.id"] = self.request.headers:get_url()
        self.response_table["@odata.context"] = CONFIG.SERVICE_PREFIX .. "/$metadata" .. self.current_context .. "AccountService/Members/Accounts"
        self.last_modified = coroutine.yield(self.redis:get(self.scope .. ":LastModified")) or tostring(utils.fileTime('/usr/local/'))
        self.response_table["@odata.etag"] = "W/\""..self.last_modified.."\""

		--Retrieving data from database
		self:set_status(201)
		self:add_header("Location", new_account_uri)

		self:get_instance(response, index)
		
		self:set_response(response)
		self:output()
	else
		self:error_insufficient_privilege()
	end
end

--Handles PATCH request for Account
function AccountHandler:patch()

	local url_segments = self:get_url_segments()
	local collection, secondary_collection, instance = url_segments[1], url_segments[2], url_segments[3]
	local redis = self:get_db()
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

	local user = yield(redis:get("Redfish:" .. collection .. ":" .. secondary_collection .. ":" .. instance .. ":UserName"))
	if user == nil then
		self:error_resource_missing_at_uri()
	end

	local enabled = yield(redis:get("Redfish:" .. collection .. ":ServiceEnabled"))

	if enabled ~= "true" then
		self:error_service_disabled()
	end

	--Making sure current user has permission to modify user settings
	if self:can_user_do("ConfigureUsers") == true or (self:can_user_do("ConfigureSelf") == true and user == self.username) then
		local request_data = turbo.escape.json_decode(self:get_request().body)
		if request_data == nil or request_data =="" then
			self:error_unrecognized_request_body()
		end
		self:set_scope("Redfish:" .. table.concat(url_segments, ":"))

		local pl = redis:pipeline()
		local prefix = "Redfish:" .. collection .. ":" .. secondary_collection .. ":" .. instance
		local extended = {}
		local successful_sets = {}

		--Validating Enabled property and adding error if property is incorrect
		if request_data.Enabled ~= nil then
			if type(request_data.Enabled) ~= "boolean" then
				table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/Enabled"}, {request_data.Enabled, "Enabled"}))
			else
				--Enabled is valid and will be added to database
				pl:set(prefix .. ":Enabled", tostring(request_data.Enabled))
				table.insert(successful_sets, "Enabled")
			end
			request_data.Enabled = nil
		end

		--Making sure there is not a user with the same username and throwing an error if there is
		if request_data.UserName ~= nil then
			local users = yield(redis:keys("Redfish:" .. collection .. ":" .. secondary_collection .. ":*:UserName"))
			local duplicate_user = false
			for key, val in pairs(users) do
				local parts = utils.split(val, ":")
				local cur_user = yield(redis:get(val))

				if cur_user == request_data.UserName and parts[table.getn(parts) - 1] ~= instance then
					local temp = {}
					table.insert(extended, self:create_message("Base", "ResourceAlreadyExists", {"#/UserName"}))
					duplicate_user = true
				end
			end

			if duplicate_user == false then
				pl:set(prefix .. ":UserName", request_data.UserName)
				self.username = request_data.UserName
				table.insert(successful_sets, "UserName")
			end
			request_data.UserName = nil
		end

		--Setting Password
		if request_data.Password ~= nil then
			local min_password_len = yield(redis:get("Redfish:" .. collection .. ":MinPasswordLength"))
			if #request_data.Password < tonumber(min_password_len) then
				table.insert(extended, self:create_message("Base", "PropertyValueFormatError", {"#/Password"}, {"of length " .. #request_data.Password, "Password"}))
			else
				pl:set(prefix .. ":Password", md5.sumhexa(request_data.Password .. CONFIG.SALT))
				table.insert(successful_sets, "Password")
			end

			request_data.Password = nil
		end

		--Making sure user has permission to change the RoleId and adding an error if the user does not
		if request_data.RoleId ~= nil then
			local cur_role = yield(redis:get("Redfish:" .. collection .. ":" .. secondary_collection .. ":" .. instance .. ":RoleId"))
			if self:can_user_do("ConfigureUsers") == false and request_data.RoleId ~= cur_role then
				table.insert(extended, self:create_message("Base", "InsufficientPrivilege", {"#/RoleId"}))
			elseif not turbo.util.is_in("Redfish:AccountService:Roles:" .. request_data.RoleId .. ":Name", yield(redis:keys("Redfish:AccountService:Roles:*:Name"))) then
				table.insert(extended, self:create_message("Base", "PropertyValueNotInList", {"#/RoleId"}, {request_data.RoleId, "RoleId"}))
			else
				pl:set(prefix .. ":RoleId", request_data.RoleId)
				table.insert(successful_sets, "RoleId")
			end
			request_data.RoleId = nil
		end

		--Validating Locked property and adding error if property is incorrect
		if request_data.Locked ~= nil then
			if self:can_user_do("ConfigureUsers") == true then
				if request_data.Locked == false then
					pl:set(prefix .. ":Locked", tostring(request_data.Locked))
					table.insert(successful_sets, "Locked")
				elseif type(request_data.Locked) ~= "boolean" then
					table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/Locked"}, {tostring(request_data.Locked), "Locked"}))
				elseif request_data.Locked == true then
					table.insert(extended, self:create_message("Base", "PropertyValueNotInList", {"#/Locked"}, {tostring(request_data.Locked), "Locked"}))
				end
			else
				table.insert(extended, self:create_message("Security", "InsufficientPrivilegeForProperty", {"#/Locked"}, {"Locked"}))
			end
			request_data.Locked = nil
		end

		-- If we have valid property updates to run, run the pipeline,
		-- update last modified so that E-Tag can respond properly,
		-- and log the event in the audit log
		if #pl.pending_commands > 0 then
			self:update_lastmodified(self:get_scope(), os.time(), pl)
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
			self:set_status(204)
		end
	else
		self:error_insufficient_privilege()
	end

	self:set_response(response)
	self:output()
end

--Handles DELETE request for Account
function AccountHandler:delete(id)

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

	local redis = self:get_db()
	local enabled = yield(redis:get("Redfish:" .. collection .. ":ServiceEnabled"))

	if enabled ~= "true" then
		self:error_service_disabled()
	end

	--Making sure current user has permission to modify user settings
	if self:can_user_do("ConfigureUsers") == true then			
		--Deleting user
		local user_info = yield(redis:keys("Redfish:" .. collection .. ":" .. secondary_collection .. ":" .. instance .. ":*"))
		if #user_info == 0 then
			self:error_resource_missing_at_uri()
		end
		yield(redis:del(unpack(user_info)))
		self:update_lastmodified("Redfish:" .. collection .. ":" .. secondary_collection, os.time())
		local deleted_account_uri = CONFIG.SERVICE_PREFIX .. "/" .. collection .. "/" .. secondary_collection .. "/" .. instance
		utils.add_event_entry(redis, "Redfish:Managers:Self:LogServices:EventLog", "EventLog.1.0.0", "ResourceRemoved", {deleted_account_uri}, "Event", "Informational", "Redfish:" .. collection .. ":" .. secondary_collection .. ":" .. instance, nil, nil, deleted_account_uri .. " - " .. tostring(os.time()), "ResourceRemoved")
		
		self:set_status(204)
	else
		self:error_insufficient_privilege()
	end
end

return AccountHandler
