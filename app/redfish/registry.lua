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

-- [See "lfs.lua"](https://keplerproject.github.io/luafilesystem/)
local lfs = require("lfs")
local posix = require("posix")

local RegistryHandler = class("RegistryHandler", RedfishHandler)

local yield = coroutine.yield

-- Set the path names for registry OEM extensions
local collection_oem_path = "registry-collection"
local instance_oem_path = "registry-instance"
RegistryHandler:set_all_oem_paths(collection_oem_path, instance_oem_path)

--Handles GET requests for Registry collection and instance
function RegistryHandler:get(instance)
	local response = {}

	if instance == "/redfish/v1/Registries" then
		--GET collection
		self:get_collection(response)
		self:set_response(response)
		-- GET requests must respond with the 'Allow' header specifying what methods are available for the given URL
		self:set_allow_header("GET")
		self:output()
	elseif string.find(instance, ".json$") ~= nil then
		--GET file
		self:get_file(response)
	else
		--GET instance
		self:get_instance(response)
		self:set_response(response)
		-- GET requests must respond with the 'Allow' header specifying what methods are available for the given URL
		self:set_allow_header("GET")
		self:output()
	end	
end

-- Handles GET System collection
function RegistryHandler:get_collection(response)
	-- Before proceeding with the handler, we'll make sure the collection request is valid
	local collection_exists = self:parent_exists()
	self:assertTrue_404(collection_exists)

	local url_segments = self:get_url_segments()

	local collection = url_segments[1]
	
	local prefix = "Redfish:" .. collection

	self:set_scope("Redfish:" .. table.concat(url_segments, ":"))

	-- Creating response
	response["Name"] = "Registry Repository"
	response["Description"] = "Registry Repository"
	response["Members"] = {}

	local members_set = {}
	local exists = posix.stat("message_registries")
	
	if exists then
		for file in lfs.dir("message_registries") do
			if file ~= "." and file ~= ".." then
				members_set[file:sub(1, -5)] = 1
			end
		end
	end

	exists = posix.stat(CONFIG.BIOS_CONF_PATH)
	if exists then
		for file in lfs.dir(CONFIG.BIOS_CONF_PATH) do
			if file:match("^BiosAttributeRegistry.+%.%d+%.%d+%.%d+%.json$") then
				members_set[file:sub(1, -6)] = 1
			end
		end
	end

	local members = {}
	for member, _unused in pairs(members_set) do
		local entry = {}
		entry["@odata.id"] = CONFIG.SERVICE_PREFIX .. "/Registries/" .. member
		table.insert(members, entry)
	end

	_.extend(response["Members"], members)
	response["Members@odata.count"] = #members

	response = self:oem_extend(response, "query." .. self:get_oem_collection_path())

	self:set_context(CONSTANTS.MESSAGE_REGISTRY_FILE_COLLECTION_CONTEXT)
	self:set_type(CONSTANTS.MESSAGE_REGISTRY_FILE_COLLECTION_TYPE)
end

-- Handles GET Registry instance
function RegistryHandler:get_instance(response)
	local url_segments = self:get_url_segments();

	local collection, id = url_segments[1], url_segments[2];

	self:set_scope("Redfish:" .. table.concat(url_segments, ":"))

	local location = {}
	local languages = {}

	local exists = posix.stat("message_registries")

	if exists then
		for file in lfs.dir("message_registries") do
			if file ~= "." and file ~= ".." then
				local reg = dofile("message_registries/" .. file)
				
				if reg.Id == id then
					local entry = {}

					entry["Language"] = reg.Language
					entry["Uri"] = CONFIG.SERVICE_PREFIX .. "/Registries/" .. string.gsub(file, ".lua", "") .. ".json"
					table.insert(location, entry)

					table.insert(languages, reg.Language)
				end
			end
		end
	end

	exists = posix.stat(CONFIG.BIOS_CONF_PATH)
	if exists then
		for file in lfs.dir(CONFIG.BIOS_CONF_PATH) do
			if file:match("^BiosAttributeRegistry.+%.%d+%.%d+%.%d+%.json$") then
				-- local data_file = io.open(CONFIG.BIOS_CONF_PATH .. file, "r")
				-- success, reg = pcall(turbo.escape.json_decode, data_file:read("*all"))
				-- data_file:close()
				-- if not success then
				-- 	self:error_resource_at_uri_in_unknown_format()
		  --       end
				local reg_id = file:sub(1, -6)
				if reg_id == id then
					local entry = {}

					entry["Language"] = "en"
					entry["Uri"] = CONFIG.SERVICE_PREFIX .. "/Registries/" .. file
					table.insert(location, entry)

					table.insert(languages, "en")
				end
			end
		end
	end

	if #location == 0 then
		self:error_resource_missing_at_uri()
	end

	response["Id"] = id
	response["Name"] = tostring(id) .. " Registry" 
	response["Registry"] = id
	response["Languages"] = {}
	_.extend(response["Languages"], languages)
	response["Location"] = {}
	_.extend(response["Location"], location)

	response = self:oem_extend(response, "query." .. self:get_oem_instance_path())

	self:set_context(CONSTANTS.MESSAGE_REGISTRY_FILE_INSTANCE_CONTEXT)
	self:set_type(CONSTANTS.MESSAGE_REGISTRY_FILE_TYPE)
end

--Handles Post Registry 
function RegistryHandler:post()

	local url_segments = self:get_url_segments();

	local collection, id = url_segments[1], url_segments[2];
	
	self:set_scope("Redfish:" .. table.concat(url_segments, ":"))

	local flag = false

	local exists = posix.stat("message_registries")

	if exists then
		for file in lfs.dir("message_registries") do
			if file ~= "." and file ~= ".." then
				local reg = dofile("message_registries/" .. file)
				if reg.Id == id or id == nil then
					flag = true
				end
			end
		end
	end

	if flag == true then 
		self:set_allow_header("GET")
		self:error_method_not_allowed()
	else	
		self:error_resource_missing_at_uri()
	end
		
end

--Handles put Registry 
function RegistryHandler:put()
	local url_segments = self:get_url_segments();

	local collection, id = url_segments[1], url_segments[2];

	self:set_scope("Redfish:" .. table.concat(url_segments, ":"))

	local flag = false

	local exists = posix.stat("message_registries")

	if exists then
		for file in lfs.dir("message_registries") do
			if file ~= "." and file ~= ".." then
				local reg = dofile("message_registries/" .. file)
				
				if reg.Id == id or id == nil then
					flag = true
				end
			end
		end
	end

	if flag == true then 
		self:set_allow_header("GET")
		self:error_method_not_allowed()
	else
		self:error_resource_missing_at_uri()
	end
end

--Handles Patch Registry 
function RegistryHandler:patch()
	local url_segments = self:get_url_segments();

	local collection, id = url_segments[1], url_segments[2];

	self:set_scope("Redfish:" .. table.concat(url_segments, ":"))

	local flag = false

	local exists = posix.stat("message_registries")

	if exists then
		for file in lfs.dir("message_registries") do
			if file ~= "." and file ~= ".." then
				local reg = dofile("message_registries/" .. file)
				
				if reg.Id == id or id == nil then
					flag = true
				end
			end
		end
	end

	if flag == true then 
		self:set_allow_header("GET")
		self:error_method_not_allowed()
	else	
		self:error_resource_missing_at_uri()
	end
end

--Handles Delete Registry 
function RegistryHandler:delete()
	local url_segments = self:get_url_segments();

	local collection, id = url_segments[1], url_segments[2];

	self:set_scope("Redfish:" .. table.concat(url_segments, ":"))

	local flag = false

	local exists = posix.stat("message_registries")

	if exists then
		for file in lfs.dir("message_registries") do
			if file ~= "." and file ~= ".." then
				local reg = dofile("message_registries/" .. file)
				
				if reg.Id == id or id == nil then
					flag = true
				end
			end
		end
	end

	if flag == true then 
		self:set_allow_header("GET")
		self:error_method_not_allowed()
	else
		self:error_resource_missing_at_uri()
	end
end

function RegistryHandler:get_file(response)
	local url_segments = self:get_url_segments();

	local collection, id = url_segments[1], url_segments[2]

	local prefix = "Redfish:" .. collection .. ":" .. id

	self:set_scope("Redfish:" .. table.concat(url_segments, ":"))

	local reg_present, reg = pcall(dofile, "message_registries/" .. string.gsub(id, ".json", "") ..".lua")

	if not reg_present then
		--reg_present, reg = pcall(dofile, "/conf/redfish/bios/" .. string.gsub(id, ".json", "") ..".lua")
		local data_file = io.open(CONFIG.BIOS_CONF_PATH .. id, "rb")
		if data_file ~= nil then
			reg = data_file:read("*all")
			data_file:close()
			self:set_allow_header("GET")
	  		self:write(reg);
	  		self:gzip_output()
		else
			self:error_resource_missing_at_uri()
		end
	else
		reg["@odata.type"] = "#" .. CONSTANTS.MESSAGE_REGISTRY_TYPE
		_.extend(response, reg)
		self:set_response(response)
		self:set_allow_header("GET")
		self:output()
	end
end

return RegistryHandler