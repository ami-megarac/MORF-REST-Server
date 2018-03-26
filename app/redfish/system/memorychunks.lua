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
-- [See "utils.lua"](/utils.html)
local utils = require("utils")
-- [See "turbo library"](http://turbolua.org)
local turbo = require("turbo")
-- [See "underscore.lua"](https://mirven.github.io/underscore.lua/)
local _ = require("underscore")

local SystemMemoryChunksHandler = class("SystemMemoryChunksHandler", RedfishHandler)


local yield = coroutine.yield

-- Set the path names for system OEM extensions
local collection_oem_path = "system.system-memorychunks-collection"
local instance_oem_path = "system.system-memorychunks-instance"
SystemMemoryChunksHandler:set_all_oem_paths(collection_oem_path, instance_oem_path)

--Handles GET requests for System MemoryChunks collection and instance
function SystemMemoryChunksHandler:get(id1, id2)

	local response = {}
	
	if id2 == nil then
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

-- Handles GET System MemoryChunks collection
function SystemMemoryChunksHandler:get_collection(response)
	-- Before proceeding with the handler, we'll make sure the collection request is valid
	local collection_exists = self:parent_exists()
	self:assertTrue_404(collection_exists)

	local redis = self:get_db()
	local url_segments = self:get_url_segments();

	local collection, instance, secondary_collection = 
		url_segments[1], url_segments[2], url_segments[3]

	local prefix = "Redfish:" .. collection .. ":" .. instance .. ":" .. secondary_collection

	self:set_scope("Redfish:" .. table.concat(url_segments, ":"))

	-- Creating response
	response["Name"] = "MemoryChunks Collection"
	response["Description"] = "Collection of memory chunks for this system"

	local odataIDs = utils.getODataIDArray(yield(redis:keys(prefix .. ":*:Name")), 1)

	response["Members@odata.count"] = #odataIDs
	response["Members"] = odataIDs

	response = self:oem_extend(response, "query." .. self:get_oem_collection_path())

	self:set_context(CONSTANTS.MEMORYCHUNKS_COLLECTION_CONTEXT)
	self:set_type(CONSTANTS.MEMORYCHUNKS_COLLECTION_TYPE)
end

-- Handles GET System MemoryChunks instance
function SystemMemoryChunksHandler:get_instance(response)
	local redis = self:get_db()
	local url_segments = self:get_url_segments();

	local collection, instance, secondary_collection, id = 
		url_segments[1], url_segments[2], url_segments[3], url_segments[4];

	local prefix = "Redfish:" .. collection .. ":" .. instance .. ":" .. secondary_collection .. ":" .. id

	self:set_scope("Redfish:"..table.concat(url_segments,':'))

	--Retrieving data from database
	local pl = redis:pipeline()
	pl:mget({
			prefix .. ":MemoryChunkName",
			prefix .. ":MemoryChunkUID",
			prefix .. ":MemoryChunkSizeMiB",
			prefix .. ":AddressRangeType",
			prefix .. ":IsMirrorEnabled",
			prefix .. ":IsSpare",
			prefix .. ":InterleaveSets"
		})
	pl:hmget(prefix .. ":Status", "State", "Health")
	

    local db_result = yield(pl:run())

    -- Check that data was found in Redis, if not we throw a 404 NOT FOUND
    self:assert_resource(db_result)

	local general, status = unpack(db_result)

	--Creating response using data from database
	response["Id"] = id
	response["Name"] = "Memory Chunk "..id
	response["Description"] = "Memory Chunk "..id.." <details>"
	response["MemoryChunkName"] = general[1]
	response["MemoryChunkUID"] = tonumber(general[2])
	response["MemoryChunkSizeMiB"] = tonumber(general[3])
	response["AddressRangeType"] = general[4]
	response["IsMirrorEnabled"] = utils.bool(general[5])
	response["IsSpare"] = utils.bool(general[6])
	response["InterleaveSets"] = turbo.escape.json_decode(general[7])
	
	response["Status"] = {
		State = status[1],
		Health = status[2]
	}

	response = self:oem_extend(response, "query." .. self:get_oem_instance_path())

	utils.remove_nils(response)

	local keys = _.keys(response)
	if #keys < 11 then
		local select_list = turbo.util.join(",", keys)
		self:set_context(CONSTANTS.MEMORYCHUNKS_INSTANCE_CONTEXT .. "(" .. select_list .. ")")
	else
		self:set_context(CONSTANTS.MEMORYCHUNKS_INSTANCE_CONTEXT)
	end

	self:set_type(CONSTANTS.MEMORYCHUNKS_TYPE)
end

return SystemMemoryChunksHandler