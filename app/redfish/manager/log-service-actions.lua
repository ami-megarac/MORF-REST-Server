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

local redis_scan = require('redis_scan')

local LogServiceActionHandler = class("LogServiceActionHandler", RedfishHandler)

local yield = coroutine.yield

local allowed_clears = { "ClearAll" }

-- ### GET request handler for Manager/LogServices Actions
function LogServiceActionHandler:get(_manager_id, id, action)
	self:set_allow_header("POST")
	self:error_method_not_allowed()
end

-- ### POST request handler for Manager/LogServices Actions
function LogServiceActionHandler:post(_manager_id, id, action)

	if self:can_user_do("ConfigureManager") == false then
		self:error_insufficient_privilege()
	end

	local url = self.request.headers:get_url()

	local request_data = self:get_json()

	local response = {}

	local missing = {}

	if action then
		space, action = string.match(action, "([^/^.]+)%.([^/^.]+)")
	end
	-- Handles action here
	if id == 'SEL' and space == 'LogService' and action == 'ClearLog' then
		local retrive_service = "Redfish:Managers:" .. _manager_id .. ":LogServices:SEL:ServiceEnabled"
		local service_res = yield(self:get_db():get(retrive_service))
		
		if service_res == "false" then
		
			self:error_service_disabled()
		else
		
			local cleartype = request_data and request_data.ClearType

			if not turbo.util.is_in(cleartype, allowed_clears) then

				self:error_action_parameter_format("ClearType", cleartype)

			else

				local redis_action_key = "Redfish:Managers:" .. _manager_id .. ":LogServices:SEL:Actions:ClearLog"

				local action_res = yield(self:get_db():set(redis_action_key, cleartype))
				local reset = yield(self:get_db():set("Redfish:Managers:" .. _manager_id .. ":LogServices:SEL:Reset", 0))
				self:update_lastmodified("Redfish:Managers:" .. _manager_id .. ":LogServices:SEL", os.time())
				self:set_status(204)
			end
		end

	elseif (id == 'AuditLog' or id == 'EventLog') and space == 'LogService' and action == 'ClearLog' then
		local retrive_service = "Redfish:Managers:" .. _manager_id .. ":LogServices:" .. id .. ":ServiceEnabled"
		local service_res = yield(self:get_db():get(retrive_service))
		
		if service_res == "false" then
		
				self:error_service_disabled()
		else
		
			local cleartype = request_data and request_data.ClearType

			if not turbo.util.is_in(cleartype, allowed_clears) then

				self:error_action_parameter_format("ClearType", cleartype)

			else

				-- Audit Log is only contained in the Redfish service, so we can clear it directly
				local sel_log_entries_prefix = "Redfish:Managers:" .. _manager_id .. ":LogServices:" .. id .. ":Entries:*"
				local cursor = 0
				--print("cursor : " .. cursor)
				local result = yield(self:get_db():scan(cursor, "MATCH", sel_log_entries_prefix, "COUNT", 2000))
				--print("cursor : " .. result[1])
				while tonumber(result[1]) > 0 do
					if result[2][1] ~= NULL then
						yield(self:get_db():del(unpack(result[2])))
						result = yield(self:get_db():scan(result[1], "MATCH", sel_log_entries_prefix, "COUNT", 2000))
						--print("cursor : " .. result[1])
					elseif (result[2][1] == NULL and tonumber(result[1]) > 0) then
						result = yield(self:get_db():scan(result[1], "MATCH", sel_log_entries_prefix, "COUNT", 2000))
						--print("cursor : " .. result[1])
					end
				end
				if result[2][1] ~= NULL then
					 yield(self:get_db():del(unpack(result[2])))
				end
				print("Cleared Successfully")
				self:update_lastmodified("Redfish:Managers:" .. _manager_id .. ":LogServices:" .. id, os.time())
                self:set_status(204)
			end
			
		end
	-- Always have the else condition similar to "default" case to respond no other actions or post operations available
	elseif self:get_request().path:find("Actions") then
		self:error_action_not_supported()
	else 
		self:error_resource_missing_at_uri()
	end
    
    self:add_audit_log_entry(self:create_message("Security", "ResourceDeleted", nil, {"/redfish/v1/Managers/Self/LogServices/"..id.."/Entries"}))
	self:set_response(response)

	self:output()

end

return LogServiceActionHandler