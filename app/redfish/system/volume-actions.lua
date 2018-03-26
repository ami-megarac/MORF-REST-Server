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
local yield = coroutine.yield
local VolumeActionHandler = class("VolumeActionHandler", RedfishHandler)

-- ATTENTION: These allowable values need to be filled in with the appropriate values
local Initialize_allowable_vals = {}

-- ATTENTION: These handlers cover very general action handling. It is possible that they will need to be changed to fit this specific action.

function VolumeActionHandler:get()
	self:set_header("Allow", "POST")
	self:error_method_not_allowed()
end

function VolumeActionHandler:post(url_capture0, url_capture1, url_capture2, url_capture3)
	local request_data = self:get_json()
	local response = {}
	local space, action
	local url_segments = self:get_url_segments()
	if url_capture3 then
		space, action = string.match(url_capture3, "([^/^.]+)%.([^/^.]+)")
	end
	if space == "Volume" and action == "Initialize" then
		if not turbo.util.is_in(request_data.InitializeType, Initialize_allowable_vals) then
			self:error_action_parameter_format("InitializeType", request_data.InitializeType)
		end
		local redis_action_key = "Redfish:" .. table.concat(url_segments, ":"):match("(.*):.*") .. ":Initialize"
		local action_res = yield(self:get_db():set(redis_action_key, request_data.InitializeType))
	elseif self:get_request().path:find("Actions") then
		self:error_action_not_supported()
	else 
		self:error_resource_missing_at_uri()
	end
	self:set_status(204)
	self:set_response(response)
	self:output()
end
return VolumeActionHandler