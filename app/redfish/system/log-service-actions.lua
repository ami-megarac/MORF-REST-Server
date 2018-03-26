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

local SystemLogServiceActionHandler = class("SystemLogServiceActionHandler", RedfishHandler)

local yield = coroutine.yield

local allowed_clears = { "ClearAll" }

-- ### GET request handler for System/LogServices Actions
function SystemLogServiceActionHandler:get(_system_id, id, action)
	self:set_allow_header("POST")

	self:error_method_not_allowed()
end

-- ### POST request handler for System/LogServices Actions
function SystemLogServiceActionHandler:post(_system_id, id, action)

	if self:can_user_do("ConfigureComponents") == false then
		self:error_insufficient_privilege()
	end

        local redis = self:get_db()

        local prefix = "Redfish:Systems:Self:LogServices:BIOS"

        self:set_scope(prefix)

        local pl = redis:pipeline()

        --Retrieving data from database
        pl:mget(prefix .. ":ServiceEnabled")

	local db_result = yield(pl:run())

	local general = unpack(db_result)


	local url = self.request.headers:get_url()

	local request_data = self:get_json()

	local response = {}

	local missing = {}


	if general[1] == "false" then
		self:error_service_disabled()
	end


	if action then
		space, action = string.match(action, "([^/^.]+)%.([^/^.]+)")
	end
	-- Handles action here
	if id == "BIOS" and space == 'LogService' and action == 'ClearLog' then

		local cleartype = request_data and request_data.ClearType

		if not turbo.util.is_in(cleartype, allowed_clears) then
			self:error_action_parameter_format("ClearType", cleartype)
		else
			local redis_action_key = "Redfish:Systems:" .. _system_id .. ":LogServices:BIOS:Actions:ClearLog"
			local action_res = yield(self:get_db():set(redis_action_key, "CLEAR_PENDING"))
			local reset = yield(self:get_db():set("Redfish:Systems:Reset", 0))
			self:update_lastmodified(prefix, os.time())
			self:set_status(204)
		end

	-- Always have the else condition similar to "default" case to respond no other actions or post operations available
	elseif self:get_request().path:find("Actions") then
		self:error_action_not_supported()
	else 
		self:error_resource_missing_at_uri()
	end
    
    self:add_audit_log_entry(self:create_message("Security", "ResourceDeleted", nil, {"/redfish/v1/Systems/Self/LogServices/"..id.."/Entries"}))
    
	self:set_response(response)

	self:output()

end

return SystemLogServiceActionHandler
