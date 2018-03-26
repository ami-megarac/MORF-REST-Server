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

local SystemActionHandler = class("SystemActionHandler", RedfishHandler)

local yield = coroutine.yield

local allowed_reset = {"On", "ForceOff", "GracefulShutdown", "GracefulRestart", "ForceRestart"}

-- ### GET request handler for Systems Actions
function SystemActionHandler:get(_system_id, id, action)
	self:set_header("Allow", "POST")
	self:error_method_not_allowed()
end

-- ### POST request handler for Systems Actions
function SystemActionHandler:post(_system_id, action)
	local url = self.request.headers:get_url()
	local request_data = self:get_json()
	local response = {}
	local extended = {}
	local prefix = "Redfish:Systems:" .. _system_id

	if action then
		space, action = string.match(action, "([^/^.]+)%.([^/^.]+)")
	end
    local redis_key = "Redfish:Systems:" .. _system_id .. ":PowerState"
	
	-- Handles action here
	if space == 'ComputerSystem' and action == 'Reset' then
		
		if type(request_data) == "nil" then
                  self:error_malformed_json()
            else
                  local resettype = request_data.ResetType
                  
                  local redis = self:get_db()
                  local pl = redis:pipeline()
                  local keys_to_watch = {}
                  local System_Status = yield(redis:get(redis_key))
                  
                  if System_Status ~= nil and System_Status == "Off" and (resettype == "GracefulShutdown" or resettype == "GracefulRestart" or resettype == "ForceRestart") then
                        
                        table.insert(extended, self:create_message("Base", "ActionNotSupported", {"#" .. url}, {"Unable to perform '" .. resettype .."' operation on the Host Machine since it is already in 'PowerOff' state !!"}))	
							
                  elseif not turbo.util.is_in(resettype, allowed_reset) then
                        
                        self:error_action_parameter_unknown("ResetType", resettype)
                  else
				local redis_action_key = "Redfish:Systems:" .. _system_id .. ":Actions:Reset"
            
                        pl:set(redis_action_key, resettype)
				
                        table.insert(keys_to_watch, redis_key)
                  end
                  
			-- Run any pending database commands.
			if #pl.pending_commands > 0 then
		
				local post_errors, timedout_keys, result = self:doPOST(keys_to_watch, pl, CONFIG.PATCH_TIMEOUT)
				for _i, err in pairs(post_errors) do
				    table.insert(extended, self:create_message(err.Registry, err.MessageId, err.RelatedProperties, err.MessageArgs))
				end
				for _i, to_key in pairs(timedout_keys) do
				    
				    table.insert(extended, self:create_message("IPMI", "Timeout"))
				end
			end
            end
	-- Always have the else condition similar to "default" case to respond no other actions or post operations available
	elseif self:get_request().path:find("Actions") then
		self:error_action_not_supported()
	else 
		self:error_resource_missing_at_uri()
	end
    
    if #extended ~= 0 then
		self:add_error_body(response,400,extended)
	else
		self:update_lastmodified(redis_key, os.time())
        self:set_status(204)
    end
    
    self:set_response(response)
    self:output()

end

return SystemActionHandler
