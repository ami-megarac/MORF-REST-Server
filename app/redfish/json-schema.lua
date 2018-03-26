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

local JsonSchemaHandler = class("JsonSchemaHandler", RedfishHandler)

local yield = coroutine.yield

-- Set the path names for json-schema OEM extensions
local collection_oem_path = "json-schema-collection"
local instance_oem_path = "json-schema-instance"
JsonSchemaHandler:set_all_oem_paths(collection_oem_path, instance_oem_path)

--Handles GET requests for Json Schema collection and instance
function JsonSchemaHandler:get(instance)
	local response = {}

	if instance == "/redfish/v1/JsonSchemas" then
		--GET collection
		self:get_collection(response)
	else
		--GET instance
		self:get_instance(response)
	end

	self:set_response(response)

	-- GET requests must respond with the 'Allow' header specifying what methods are available for the given URL
	self:set_allow_header("GET")

	self:output()
end

-- Handles GET Json Schema collection
function JsonSchemaHandler:get_collection(response)
	-- Before proceeding with the handler, we'll make sure the collection request is valid
	local collection_exists = self:parent_exists()
	self:assertTrue_404(collection_exists)

	local url_segments = self:get_url_segments()

	local collection = url_segments[1]
	
	local prefix = "Redfish:" .. collection

	self:set_scope("Redfish:" .. table.concat(url_segments, ":"))

	-- Creating response
	response["Name"] = "Schema Repository"
	response["Members"] = {}

	response = self:oem_extend(response, "query." .. self:get_oem_collection_path())

	self:set_context(CONSTANTS.JSONSCHEMA_COLLECTION_CONTEXT)
	self:set_type(CONSTANTS.JSON_SCHEMA_COLLECTION_TYPE)
end

-- Handles GET Json Schema instance
function JsonSchemaHandler:get_instance(response)
	local url_segments = self:get_url_segments();

	local collection, id = url_segments[1], url_segments[2];

	if id:match("(.-)%.") == nil then
		self:error_resource_missing_at_uri()
	end

	self:set_scope("Redfish:" .. table.concat(url_segments, ":"))

	response = self:oem_extend(response, "query." .. self:get_oem_instance_path())
  
  	if next(response) == nil then
   		self:error_resource_missing_at_uri()
  	end
  self:set_context(CONSTANTS.JSONSCHEMA_INSTANCE_CONTEXT)
	self:set_type(CONSTANTS.JSON_SCHEMA_TYPE)

end

return JsonSchemaHandler
