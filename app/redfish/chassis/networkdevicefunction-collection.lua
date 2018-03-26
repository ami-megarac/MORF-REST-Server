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
local NetworkDeviceFunctionCollectionHandler = class("NetworkDeviceFunctionCollectionHandler", RedfishHandler)

function NetworkDeviceFunctionCollectionHandler:get()
	local response = {}
	local collection_exists = self:parent_exists()
	self:assertTrue_404(collection_exists)
	local redis = self:get_db()
	local url_segments = self:get_url_segments()
	local prefix = "Redfish:" .. table.concat(url_segments, ":")
	response["Name"] = "NetworkDeviceFunction Collection"
	local odataIDs = utils.getODataIDArray(yield(redis:keys(prefix .. ":*:Id")), 1)
	response["Members@odata.count"] = #odataIDs
	response["Members"] = odataIDs
	response = self:oem_extend(response, "query.networkdevicefunction-collection")
	self:set_context("NetworkDeviceFunctionCollection.NetworkDeviceFunctionCollection")
	self:set_type(CONSTANTS.NETWORKDEVICEFUNCTION_COLLECTION_TYPE)
	self:set_allow_header("GET")
	self:set_response(response)
	self:output()
end

return NetworkDeviceFunctionCollectionHandler
