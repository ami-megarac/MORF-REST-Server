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

local LogServiceActionHandler = class("LogServiceActionHandler", RedfishHandler)

local yield = coroutine.yield

local allowed_clears = { "ClearAll" }

-- ### GET request handler for Chassis/LogServices Actions
function LogServiceActionHandler:get(_chassis_id, id, action)
	self:set_allow_header("POST")
	self:error_method_not_allowed()
end

-- ### POST request handler for Chassis/LogServices Actions
function LogServiceActionHandler:post(_chassis_id, id, action)

	local url = self.request.headers:get_url()

	local request_data = self:get_json()

	local response = {}

	local missing = {}

	if action then
		space, action = string.match(action, "([^/^.]+)%.([^/^.]+)")
	end
	-- Handles action here
	if id == 'Logs' and space == 'LogService' and action == 'ClearLog' then
		local retrive_service = "Redfish:Chassis:" .. _chassis_id .. ":LogServices:" .. id .. ":ServiceEnabled"
		local service_res = yield(self:get_db():get(retrive_service))
		
		if service_res == "false" then
			self:error_service_disabled()
		else
			local cleartype = request_data and request_data.ClearType
			if not turbo.util.is_in(cleartype, allowed_clears) then
				self:error_action_parameter_format("ClearType", cleartype)
			else
				local redis_action_key = "Redfish:Chassis:" .. _chassis_id .. ":LogServices:" .. id .. ":Actions:ClearLog"
				local action_res = yield(self:get_db():set(redis_action_key, cleartype))
				self:set_status(204)
			end
		end
		
	-- Always have the else condition similar to "default" case to respond no other actions or post operations available
	elseif self:get_request().path:find("Actions") then
		self:error_action_not_supported()
	else
		self:error_resource_missing_at_uri()
	end
	
	self:add_audit_log_entry(self:create_message("Security", "ResourceDeleted", nil, {"/redfish/v1/Chassis/Self/LogServices/"..id.."/Entries"}))

	self:set_response(response)

	self:output()

end

return LogServiceActionHandler