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
local AccountServiceHandler = class("AccountServiceHandler", RedfishHandler)
local yield = coroutine.yield

-- Set the path names for account service OEM extensions
local singleton_oem_path = "account-service.accountservice-instance"
AccountServiceHandler:set_oem_singleton_path(singleton_oem_path)

--Handles GET requests for Account Service
function AccountServiceHandler:get(instance)
	local response = {}
	local redis = self:get_db()
	local url_segments = self:get_url_segments();
	local collection = url_segments[1];
	local prefix = "Redfish:" .. collection
	self:set_scope("Redfish:" .. table.concat(url_segments, ":"))
	--Retrieving data from database
	local pl = redis:pipeline()
	pl:mget({
			prefix .. ":Name",
			prefix .. ":Description",
			prefix .. ":ServiceEnabled",
			prefix .. ":AuthFailureLoggingThreshold",
			prefix .. ":MinPasswordLength",
			prefix .. ":AccountLockoutThreshold",
			prefix .. ":AccountLockoutDuration",
			prefix .. ":AccountLockoutCounterResetAfter"
		})
	pl:hmget(prefix .. ":Status", "State", "Health")
	-- Check that data was found in Redis, if not we throw a 404 NOT FOUND
	local db_result = yield(pl:run())
	self:assert_resource(db_result)
	local general, status = unpack(db_result)
	--Creating response using data from database
	response["Id"] = collection
	response["Name"] = general[1]
	response["Description"] = general[2]
	response["ServiceEnabled"] = utils.bool(general[3])
	response["AuthFailureLoggingThreshold"] = tonumber(general[4])
	response["MinPasswordLength"] = tonumber(general[5])
	response["AccountLockoutThreshold"] = tonumber(general[6])
	response["AccountLockoutDuration"] = tonumber(general[7])
	response["AccountLockoutCounterResetAfter"] = tonumber(general[8])
	response["Status"] = {
		State = general[3] == "true" and "Enabled" or "Disabled",
		Health = status[2]
	}
	
	response["Accounts"] = {}
	response["Accounts"]["@odata.id"] = CONFIG.SERVICE_PREFIX .. "/" .. collection .. "/Accounts"
	response["Roles"] = {}
	response["Roles"]["@odata.id"] = CONFIG.SERVICE_PREFIX .. "/" .. collection .. "/Roles"
	response = self:oem_extend(response, "query." .. self:get_oem_singleton_path())
	utils.remove_nils(response)
	local keys = _.keys(response)
	if #keys < 12 then
		local select_list = turbo.util.join(",", keys)
		self:set_context(CONSTANTS.ACCOUNTSERVICE_CONTEXT .. "(" .. select_list .. ")")
	else
		self:set_context(CONSTANTS.ACCOUNTSERVICE_CONTEXT)
	end
	self:set_type(CONSTANTS.ACCOUNT_SERVICE_TYPE)
	self:set_response(response)
	-- GET requests must respond with the 'Allow' header specifying what methods are available for the given URL
	self:set_allow_header("GET, PATCH")
	self:output()
end
--Handles PATCH request for Account
function AccountServiceHandler:patch()
	local url_segments = self:get_url_segments()
	local collection = url_segments[1]
	local redis = self:get_db()
	local response = {}

	-- Allow the OEM patch handlers for the account service to have the first chance to handle the request body
	response = self:oem_extend(response, "patch." .. self:get_oem_singleton_path())

	--Making sure current user has permission to modify user settings
	if self:can_user_do("ConfigureUsers") == true then
		local request_data = turbo.escape.json_decode(self:get_request().body)
		self:set_scope("Redfish:" .. table.concat(url_segments, ":"))
		local pl = redis:pipeline()
		local prefix = "Redfish:" .. collection
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
		if request_data.AuthFailureLoggingThreshold ~= nil then
			if tonumber(request_data.AuthFailureLoggingThreshold) == nil then
				table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/AuthFailureLoggingThreshold"}, {request_data.AuthFailureLoggingThreshold, "AuthFailureLoggingThreshold"}))
			elseif tonumber(request_data.AuthFailureLoggingThreshold) < 0 or tonumber(request_data.AuthFailureLoggingThreshold) >= 9223372036854775807 then
				table.insert(extended, self:create_message("Base", "PropertyValueNotInList", {"#/AuthFailureLoggingThreshold"}, {request_data.AuthFailureLoggingThreshold, "AuthFailureLoggingThreshold"}))
			else
				pl:set(prefix .. ":AuthFailureLoggingThreshold", tostring(request_data.AuthFailureLoggingThreshold))
				table.insert(successful_sets, "AuthFailureLoggingThreshold")
			end
			request_data.AuthFailureLoggingThreshold = nil
		end
		if request_data.AccountLockoutThreshold ~= nil then
			if tonumber(request_data.AccountLockoutThreshold) == nil then
				table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/AccountLockoutThreshold"}, {request_data.AccountLockoutThreshold, "AccountLockoutThreshold"}))
			elseif tonumber(request_data.AccountLockoutThreshold) < 0 then
				table.insert(extended, self:create_message("Base", "PropertyValueNotInList", {"#/AccountLockoutThreshold"}, {request_data.AccountLockoutThreshold, "AccountLockoutThreshold"}))
			else
				pl:set(prefix .. ":AccountLockoutThreshold", tostring(request_data.AccountLockoutThreshold))
				table.insert(successful_sets, "AccountLockoutThreshold")
			end
			request_data.AccountLockoutThreshold = nil
		end
		local lockout_dur = nil
		local reset_after = nil
		if request_data.AccountLockoutDuration ~= nil then
			if tonumber(request_data.AccountLockoutDuration) == nil then
				table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/AccountLockoutDuration"}, {request_data.AccountLockoutDuration, "AccountLockoutDuration"}))
			elseif tonumber(request_data.AccountLockoutDuration) < 0 then
				table.insert(extended, self:create_message("Base", "PropertyValueNotInList", {"#/AccountLockoutDuration"}, {request_data.AccountLockoutDuration, "AccountLockoutDuration"}))
			else
				lockout_dur = tonumber(request_data.AccountLockoutDuration)
			end
			request_data.AccountLockoutDuration = nil
		end
		if request_data.AccountLockoutCounterResetAfter ~= nil then
			if tonumber(request_data.AccountLockoutCounterResetAfter) == nil then
				table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/AccountLockoutCounterResetAfter"}, {request_data.AccountLockoutCounterResetAfter, "AccountLockoutCounterResetAfter"}))
			elseif tonumber(request_data.AccountLockoutCounterResetAfter) < 0 then
				table.insert(extended, self:create_message("Base", "PropertyValueNotInList", {"#/AccountLockoutCounterResetAfter"}, {request_data.AccountLockoutCounterResetAfter, "AccountLockoutCounterResetAfter"}))
			else
				reset_after = request_data.AccountLockoutCounterResetAfter
			end
			request_data.AccountLockoutCounterResetAfter = nil
		end
		-- Checking lockout duration to make sure that is greater than or equal to the reset after counter
		if lockout_dur then
			local reset_after_temp = reset_after or yield(redis:get(prefix .. ":AccountLockoutCounterResetAfter"))
			if tonumber(lockout_dur) < tonumber(reset_after_temp) then
				table.insert(extended, self:create_message("Base", "PropertyValueNotInList", {"#/AccountLockoutDuration"}, {tostring(lockout_dur), "AccountLockoutDuration"}))
				-- Setting reset_after to nil to prevent the AccountLockoutCounterResetAfter handling from printing an error because its error is the same as the above error
				reset_after = nil
			else
				pl:set(prefix .. ":AccountLockoutDuration", tostring(lockout_dur))
				table.insert(successful_sets, "AccountLockoutDuration")
			end
		end
		-- Checking reset after counter to make sure that is greater than or equal to the lockout duration
		if reset_after then
			local lockout_dur_temp = lockout_dur or yield(redis:get(prefix .. ":AccountLockoutDuration"))
			if tonumber(reset_after) > tonumber(lockout_dur_temp) then
				table.insert(extended, self:create_message("Base", "PropertyValueNotInList", {"#/AccountLockoutDuration"}, {tostring(reset_after), "AccountLockoutDuration"}))
			else
				pl:set(prefix .. ":AccountLockoutCounterResetAfter", tostring(reset_after))
				table.insert(successful_sets, "AccountLockoutCounterResetAfter")
			end
		end
				-- If we have valid property updates to run, run the pipeline,
		-- update last modified so that E-Tag can respond properly,
		-- and log the event in the audit log
		if #pl.pending_commands > 0 then
			self:update_lastmodified(self:get_scope(), os.time(), pl)
			local result = yield(pl:run())
			self:add_audit_log_entry(self:create_message("Security", "ResourceModified", nil, {turbo.util.join(", ", successful_sets), self:get_request().path}))
		end
		
		--Checking if there are any additional properties in the request and creating an error to show these properties
		local leftover_fields = utils.table_len(request_data)
		if leftover_fields ~= 0 then
			local keys = _.keys(request_data)
			for k, v in pairs(keys) do
				table.insert(extended, self:create_message("Base", "PropertyNotWritable", "#/" .. v, v))
			end
		end
		--Checking if there were errors and adding them to the response if there are
		if #extended ~= 0 then
			self:add_error_body(response,400,unpack(extended))
		else
			self:update_lastmodified(prefix, os.time())
			self:set_status(204)
		end
--[[
		--Creating response
		pl = redis:pipeline()
		pl:mget({
				prefix .. ":Name",
				prefix .. ":Description",
				prefix .. ":ServiceEnabled",
				prefix .. ":AuthFailureLoggingThreshold",
				prefix .. ":MinPasswordLength",
				prefix .. ":AccountLockoutThreshold",
				prefix .. ":AccountLockoutDuration",
				prefix .. ":AccountLockoutCounterResetAfter"
			})
		pl:hmget(prefix .. ":Status", "State", "Health")
		local general, status = unpack(yield(pl:run()))
		--Creating response using data from database
		response["Id"] = collection
		response["Name"] = general[1]
		response["Description"] = general[2]
		response["ServiceEnabled"] = utils.bool(general[3])
		response["AuthFailureLoggingThreshold"] = tonumber(general[4])
		response["MinPasswordLength"] = tonumber(general[5])
		response["AccountLockoutThreshold"] = tonumber(general[6])
		response["AccountLockoutDuration"] = tonumber(general[7])
		response["AccountLockoutCounterResetAfter"] = tonumber(general[8])
		response["Status"] = {
			State = status[1],
			Health = status[2]
		}
		
		response["Accounts"] = {}
		response["Accounts"]["@odata.id"] = CONFIG.SERVICE_PREFIX .. "/" .. collection .. "/Accounts"
		response["Roles"] = {}
		response["Roles"]["@odata.id"] = CONFIG.SERVICE_PREFIX .. "/" .. collection .. "/Roles"
		response = self:oem_extend(response, "query.account-service.accountservice-instance")
		utils.remove_nils(response)
		local keys = _.keys(response)
		if #keys < 12 then
			local select_list = turbo.util.join(",", keys)
			self:set_context(collection .. "(" .. select_list .. ")")
		else
			self:set_context(collection .. "(*)")
		end
		self:set_type(CONSTANTS.ACCOUNT_SERVICE_TYPE)
]]--
		self:set_response(response)
		self:output()
	else
		self:error_insufficient_privilege()
	end
end
return AccountServiceHandler