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
local NetworkInterfaceInstanceHandler = class("NetworkInterfaceInstanceHandler", RedfishHandler)


function NetworkInterfaceInstanceHandler:get(url_capture0, url_capture1)
	local response = {}
	local redis = self:get_db()
	local url_segments = self:get_url_segments()
	local prefix = "Redfish:" .. table.concat(url_segments, ":")
	self:set_scope(prefix)
	local pl = redis:pipeline()
	pl:mget({
		prefix .. ":Id",
		prefix .. ":Name",
		prefix .. ":Description",
		prefix .. ":Status:State",
		prefix .. ":Status:HealthRollup",
		prefix .. ":Status:Health",
		prefix .. ":Links:NetworkAdapter"
	})

	local db_result = yield(pl:run())
	self:assert_resource(db_result)
	local general = unpack(db_result)
	response["Id"] = general[1]
	response["Name"] = general[2]
	response["Description"] = general[3]
	response["Status"] = {}
	response["Status"]["State"] = general[4]
	response["Status"]["HealthRollup"] = general[5]
	response["Status"]["Health"] = general[6]
	response["Status"]["Oem"] = {}
	response["Links"] = {}
	response["Links"]["Oem"] = {}
	response["Links"]["NetworkAdapter"] = {["@odata.id"] = utils.getODataID(general[7])}
	response["NetworkPorts"] = {["@odata.id"] = CONFIG.SERVICE_PREFIX .. "/" .. table.concat(url_segments, "/") .. "/NetworkPorts"}
	--response["NetworkDeviceFunctions"] = {["@odata.id"] = CONFIG.SERVICE_PREFIX .. "/" .. table.concat(url_segments, "/") .. "/NetworkDeviceFunctions"}
	response["NetworkDeviceFunctions"] = {["@odata.id"] = utils.getODataID(general[7]) .. "/NetworkDeviceFunctions"}
	response = self:oem_extend(response, "query.networkinterface-instance")
	utils.remove_nils(response)
	-- Set the OData context and type for the response
	local keys = _.keys(response)
	if #keys < 7 then
		local select_list = turbo.util.join(",", keys)
		self:set_context(CONSTANTS.NETWORKINTERFACE_CONTEXT .. "(" .. select_list .. ")")
	else
		self:set_context(CONSTANTS.NETWORKINTERFACE_CONTEXT .. "(*)")
	end
  
	self:set_type(CONSTANTS.NETWORKINTERFACE_TYPE)
	self:set_allow_header("GET")
	self:set_response(response)
	self:output()
end

return NetworkInterfaceInstanceHandler
