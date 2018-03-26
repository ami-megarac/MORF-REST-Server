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

-------------
-- ODataHandler module
-- @module ODataHandler
-- @author AMI MegaRAC

-- [See "turbo library"](http://turbolua.org)
local turbo = require("turbo")
-- [See "underscore.lua"](https://mirven.github.io/underscore.lua/)
local _ = require("underscore")
-- [See "config.lua"](/config.html)
local CONFIG = require("config")
local utils = require("utils")

local ODataHandler = class("ODataHandler", turbo.web.RequestHandler)

-- Serves the metadata document for the get request "/redfish/v1/$metadata"
function ODataHandler:get()
       local data = utils.read_from_file("./static/$metadata")
       -- Set all OData headers
        self:set_header("OData-Version", "4.0")
        self:set_header("Content-Type", "application/xml")
        self:set_header("Link", "/redfish/v1/$metadata")
        self:set_header("Cache-Control", "private")
        self:set_header("Access-Control-Allow-Origin", "*")
        self:set_header("Allow", "None")
       self:write(data);
end


--- PATCH operation enabled for turbo framework
-- Override PATCH to implement a PATCH handler
-- @param[opt] URL Incoming URL or matched regular expression
function ODataHandler:patch(...) self:error_method_not_allowed() end

--- POST operation enabled for turbo framework
-- Override POST to implement a POST handler
-- @param[opt] URL Incoming URL or matched regular expression
function ODataHandler:post(...) self:error_method_not_allowed() end

--- PUT operation enabled for turbo framework
-- Override PUT to implement a PUT handler
-- @param[opt] URL Incoming URL or matched regular expression
function ODataHandler:put(...) self:error_method_not_allowed() end

--- DELETE operation enabled for turbo framework
-- Override DELETE to implement a DELETE handler
-- @param[opt] URL Incoming URL or matched regular expression
function ODataHandler:delete(...) self:error_method_not_allowed() end

--- Initialize a new application class instance.
-- @param application Name of the application
-- @param request Request object
-- @param url_args URL argument
-- @param options Other options
function ODataHandler:initialize(application, request, url_args, options)

	turbo.web.RequestHandler.initialize(self, application, request, url_args, options)

	self.request = request

	self.url_args = url_args

	self.options = options

	self.application = application
	
	self.SUPPORTED_METHODS = {"GET", "HEAD", "POST", "DELETE", "PUT", "PATCH", "OPTIONS"}

	self.query_parameters = {}

	self.supported_query_parameters = {
		["expand"] = false,
		["filter"] = false,
		["format"] = false,
		["inlinecount"] = false,
		["select"] = false,
		["orderby"] = false,
		["count"] = false,
		["skip"] = true,
		["top"] = true
	}

	self.response_table = {}

end

--- Redefine this method if you want to do something after the class has been initialized.
-- This method unlike on_create, is only called if the method has been found to be supported.
-- @return Boolean
function ODataHandler:prepare()
	local url_args = self.request.arguments or {}
	for key, value in pairs(url_args) do
		local query, name = key:match("^(%$)(.+)$")
		if query and name then
			self.query_parameters[name] = value
		end
	end
	setmetatable(self.query_parameters, {__index = function(t,k) return false end})

	-- Fixed as per https://github.com/DMTF/spmf/issues/1067
	local odata_version = self.request.headers:get('odata-version', true)

	if odata_version ~= nil and odata_version ~= "4.0" then
		self:error_precondition_failed("OData-Version == 4.0")
	end
	-- Handle skip and top parameter validation
	if self.query_parameters.skip then
		if not tonumber(self.query_parameters.skip) then
			self:error_query_parameter_value_type("$skip", tostring(self.skip), self.response_table)
			self:write(self.response_table)
			self:finish()
			return false
		elseif tonumber(self.query_parameters.skip) < 0 then
			self:error_query_parameter_out_of_range("$skip", tostring(self.skip), "[0, inf)", self.response_table)
			self:write(self.response_table)
			self:finish()
			return false
		end
	end
	if self.query_parameters.top then
		if not tonumber(self.query_parameters.top) then
			self:error_query_parameter_value_type("$top", tostring(self.top), self.response_table)
			self:write(self.response_table)
			self:finish()
			return false
		elseif tonumber(self.query_parameters.top) < 0 then
			self:error_query_parameter_out_of_range("$top", tostring(self.top), "[0, inf)", self.response_table)
			self:write(self.response_table)
			self:finish()
			return false
		end
	end

	if self.query_parameters.count ~= false then
		self.response_table["inlinecount"] = true
	end

	self.current_context = ""
	self.current_type = ""
	return true
end

--- Sets the response data
-- This function can be used or overridden in inherited modules
-- @tparam table chunk Response data to be sent to client
function ODataHandler:set_response(chunk)

	--do the magic only if it is table. If it is string simply set request handler
	if type(chunk) ~= "table" then
		turbo.log.error("Invalid response data")
		return
	end	

	_.extend(self.response_table, chunk)

end

--- Sets the current context of given URL.
-- @param context String
function ODataHandler:set_context(context)

	if context ~= nil and context ~= "" then
		self.current_context = "#" .. context
	end

end

--- Sets the current odata type of given URL.
-- @param collection_type String.
function ODataHandler:set_type(collection_type)

	self.current_type = collection_type

end

--- Sets the header message for given URL.
-- @param header 
-- @return object Message
function ODataHandler:header_message(header)
	local value = self.request.headers:get(header, true)
	local message = {
						["@odata.type"] = "#Message.1.0.0.Message",
						["Message"] = "The header '" .. header .. "' → '" .. value .. "' is invalid or unsupported by the service.",
						["Severity"] = "Critical",
						["Resolution"] = "Check the header name and value for errors and resubmit the request"
					}

	return message
end

--- Handler to set output response to the client.
function ODataHandler:output()
	
	--TODO: OData ID context metadata checks and adds
	--TODO: Check if it is required for POST/PATCH/DELETE operations
	if self.response_table["@odata.id"] == nil and self.request.headers:get_method() == "GET" then
		self.response_table["@odata.id"] = self.request.headers:get_url()
	end


	if self.response_table["@odata.context"] == nil and self.request.headers:get_method() == "GET" then
		self.response_table["@odata.context"] = CONFIG.SERVICE_PREFIX .. "/$metadata" .. self.current_context
	end

	if self.response_table["@odata.etag"] == nil and self.last_modified ~= nil and self.request.headers:get_method() == "GET" then
		self.response_table["@odata.etag"] = "W/\""..self.last_modified.."\""
	end

	-- if self.response_table["@odata.type"] == nil and self.request.headers:get_method() == "GET" and self.current_type ~= nil then
	if self.response_table["@odata.type"] == nil and self.current_type and self.current_type ~= "" then
		self.response_table["@odata.type"] = self.current_type
	end

	if self.request.headers:get_method() == "HEAD" and self:get_status() >= 200 and self:get_status() < 300 then
		self.response_table = nil

	end

	-- If an unsupported query is submitted in the URL, we should return 501 with an error message stating an unsupported query was given
	-- Whenever a new query parameter is implemented, it should be added the the table of supported parameters (self.supported_query_parameters)
	local unsupported = {}
	for query, value in pairs(self.query_parameters) do
		if value and not self.supported_query_parameters[query] then
			table.insert(unsupported, query)
		end
	end
	if #unsupported > 0 then
		local error_body = self:add_error_body({}, 501, self:create_message("Base", "QueryNotSupported", nil, unsupported))
		self:throw_error(501, error_body)
	end

	self:write(self.response_table)

	-- Set all OData headers
	self:set_header("OData-Version", "4.0")

	self:finish()
end

--- Called after the end of a request. Useful for e.g a cleanup routine.
function ODataHandler:on_finish()


end

return ODataHandler
