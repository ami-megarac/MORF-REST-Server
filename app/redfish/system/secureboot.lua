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
local yield = coroutine.yield
local SecureBootHandler = class("SecureBootHandler", RedfishHandler)

local ResetKeys_allowable_vals = {"ResetAllKeysToDefault", "DeleteAllKeys", "DeletePK"}
function SecureBootHandler:get(url_capture0)
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
		prefix .. ":SecureBootEnable",
		prefix .. ":SecureBootCurrentBoot",
		prefix .. ":SecureBootMode"
	})

	local db_result = yield(pl:run())
	self:assert_resource(db_result)
	local general = unpack(db_result)
	response["Id"] = general[1]
	response["Name"] = general[2]
	response["Description"] = general[3]
	response["SecureBootEnable"] = utils.bool(general[4])
	response["SecureBootCurrentBoot"] = general[5]
	response["SecureBootMode"] = general[6]
	-- ATTENTION: The target and action parameter for this action may not be correct. Please double check them and make the appropraite changes.
	self:add_action({
		["#SecureBoot.ResetKeys"] = {
			target = CONFIG.SERVICE_PREFIX .. "/" .. table.concat(url_segments, "/") .. "/Actions/SecureBoot.ResetKeys",
			["ResetKeysType@Redfish.AllowableValues"] = ResetKeys_allowable_vals
		},
	})
	response = self:oem_extend(response, "query.secureboot-instance")
	utils.remove_nils(response)
  
	-- Set the OData context and type for the response
	local keys = _.keys(response)
	if #keys < 7 then
		local select_list = turbo.util.join(",", keys)
		self:set_context(CONSTANTS.SECUREBOOT_CONTEXT .. "(" .. select_list .. ")")
	else
		self:set_context(CONSTANTS.SECUREBOOT_CONTEXT .. "(*)")
	end
	
	self:set_type(CONSTANTS.SECUREBOOT_TYPE)
	self:set_allow_header("GET,PATCH")
	self:set_response(response)
	self:output()
end

function SecureBootHandler:patch(url_capture0)
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
		if type(request_data.SecureBootEnable) ~= "nil" then
			if type(request_data.SecureBootEnable) ~= "boolean" then
				table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/SecureBootEnable"}, {tostring(request_data.SecureBootEnable) .. "(" .. type(request_data.SecureBootEnable) .. ")", "SecureBootEnable"}))
			else
				pl:set(prefix .. ":SecureBootEnable", tostring(request_data.SecureBootEnable))
				table.insert(successful_sets, "SecureBootEnable")
			end
			request_data.SecureBootEnable = nil
		end
		response = self:oem_extend(response, "patch.secureboot-instance")
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
return SecureBootHandler
