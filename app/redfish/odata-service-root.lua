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

-- [See "odata-handler.lua"](/odata-handler.html)
local ODataHandler = require("odata-handler")

local oDataServiceRootHandler = class("oDataServiceRootHandler", ODataHandler)
function oDataServiceRootHandler:get()
	
	local response = {}

	response["value"] = {
		{
			name = "Service",
			kind = "Singleton",
			url = "/redfish/v1/"
		},
		{
			name = "Systems",
			kind = "Singleton",
			url = "/redfish/v1/Systems"
		},
		{
			name = "Chassis",
			kind = "Singleton",
			url = "/redfish/v1/Chassis"
		},
		{
			name = "Managers",
			kind = "Singleton",
			url = "/redfish/v1/Managers"
		},
		{
			name = "Tasks",
			kind = "Singleton",
			url = "/redfish/v1/TaskService"
		},
		{
			name = "AccountService",
			kind = "Singleton",
			url = "/redfish/v1/AccountService"
		},
		{
			name = "SessionService",
			kind = "Singleton",
			url = "/redfish/v1/SessionService"
		},
		{
			name = "EventService",
			kind = "Singleton",
			url = "/redfish/v1/EventService"
		},
		{
			name = "JsonSchemas",
			kind = "Singleton",
			url = "/redfish/v1/JsonSchemas"
		},
		{
			name = "Registries",
			kind = "Singleton",
			url = "/redfish/v1/Registries"
		},
		{
			name = "Sessions",
			kind = "Singleton",
			url = "/redfish/v1/SessionService/Sessions"
		}
	}

	self:set_response(response)
	self:set_context("")
	self:set_type(nil)

	-- GET requests must respond with the 'Allow' header specifying what methods are available for the given URL
	self:set_header("Allow", "GET")

	self:output()
end

return oDataServiceRootHandler