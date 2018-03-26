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
local SecureBootActionHandler = class("SecureBootActionHandler", RedfishHandler)

local ResetKeys_allowable_vals = {"ResetAllKeysToDefault", "DeleteAllKeys", "DeletePK"}

-- ATTENTION: These handlers cover very general action handling. It is possible that they will need to be changed to fit this specific action.

function SecureBootActionHandler:get()
	self:set_header("Allow", "POST")
	self:error_method_not_allowed()
end

function SecureBootActionHandler:post(url_capture0, url_capture1)
	local url_segments = self:get_url_segments()
	local request_data = self:get_json()
	local response = {}
	local space, action
	if url_capture1 then
		space, action = string.match(url_capture1, "([^/^.]+)%.([^/^.]+)")
	end
	if space == "SecureBoot" and action == "ResetKeys" then
		if not turbo.util.is_in(request_data.ResetKeysType, ResetKeys_allowable_vals) then
			self:error_action_parameter_format("ResetKeysType", request_data.ResetKeysType)
		end

		local redis_action_key = "Redfish:" .. table.concat(url_segments, ":"):match("(.*):.*") .. ":ResetKeys"
		local action_res = yield(self:get_db():set(redis_action_key, request_data.ResetKeysType))
	elseif self:get_request().path:find("Actions") then
		self:error_action_not_supported()
	else 
		self:error_resource_missing_at_uri()
	end
	self:set_status(204)
	self:set_response(response)
	self:output()
end
return SecureBootActionHandler
