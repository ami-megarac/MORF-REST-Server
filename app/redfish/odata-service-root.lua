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