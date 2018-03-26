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

local VirtualMediaHandler = class("VirtualMediaHandler", RedfishHandler)

local yield = coroutine.yield

-- Set the path names for virtual media OEM extensions
local collection_oem_path = "manager.manager-virtualmedia-collection"
local instance_oem_path = "manager.manager-virtualmedia-instance"
VirtualMediaHandler:set_all_oem_paths(collection_oem_path, instance_oem_path)

-- ### GET request handler for Manager/VirtualMedia
function VirtualMediaHandler:get(_manager_id, id)

	local response = {}

	-- Create the GET response for Virtual Media collection or instance, based on what 'id' was given.
	if id == nil then
		self:get_collection(response)
	else
        self:get_instance(response)
	end

	-- After the response is created, we register it with the handler and then output it to the client.
	self:set_allow_header("GET")
	self:set_response(response)

	self:output()
end

-- #### GET handler for Virtual Media collection
function VirtualMediaHandler:get_collection(response)
	-- Before proceeding with the handler, we'll make sure the collection request is valid
	local collection_exists = self:parent_exists()
	self:assertTrue_404(collection_exists)

	-- Set up the local space: get a connection with Redis DB, gather url segment, establish redis prefix, and set scope
	local redis = self:get_db()

	local collection, instance, secondary_collection = 
		self.url_segments[1], self.url_segments[2], self.url_segments[3];

	local prefix = "Redfish:Managers:"..instance..":VirtualMedia:"

	self:set_scope("Redfish:"..table.concat(self.url_segments,':'))
	-- Fill in Name and Description fields
	response["Name"] = "Virtual Media Collection"
	response["Description"] = "Collection of Virtual Media redirected to host via this Manager"
	-- Search Redis for any Virtual Media, and pack the results into an array
	local odataIDs = utils.getODataIDArray(yield(redis:keys(prefix.."*:Image")), 1)
	-- Set Members fields based on results from Redis
	response["Members@odata.count"] = #odataIDs
	response["Members"] = odataIDs
	-- Add OEM extension properties to the response
	response = self:oem_extend(response, "query." .. self:get_oem_collection_path())
	-- Set the OData context and type for the response
	self:set_context(CONSTANTS.VIRTUAL_MEDIA_COLLECTION_CONTEXT)
	self:set_type(CONSTANTS.VIRTUAL_MEDIA_COLLECTION_TYPE)
end

-- #### GET handler for Virtual Media instance
function VirtualMediaHandler:get_instance(response)
	-- Set up the local space: get a connection with Redis DB, gather url segment, establish redis prefix, and set scope
	local redis = self:get_db()

	local collection, instance, secondary_collection, id = 
		self.url_segments[1], self.url_segments[2], self.url_segments[3], self.url_segments[4];

	local prefix = "Redfish:Managers:"..instance..":VirtualMedia:"..id
	
	self:set_scope("Redfish:"..table.concat(self.url_segments,':'))
	-- Create a Redis pipeline and add commands for all Virtual Media properties
	local pl = redis:pipeline()

	pl:mget({
			prefix..":Name",
			prefix..":Description",
			prefix..":ImageName",
			prefix..":Image",
			prefix..":ConnectedVia",
			prefix..":Inserted",
			prefix..":WriteProtected"
			})
	pl:smembers(prefix..":MediaTypes")
	-- Run the Redis pipeline, and unpack the results
    local db_result = yield(pl:run())

    -- Check that data was found in Redis, if not we throw a 404 NOT FOUND
    self:assert_resource(db_result)

	local general, mediatypes = unpack(db_result)
	-- Add the data from Redis into the response, converting types where necessary
	response["Id"] = id
	response["Name"] = id
	response["Description"] = general[2]
	response["ImageName"] = general[3]
	response["Image"] = general[4]
	response["ConnectedVia"] = general[5]
	if type(general[6]) ~= "nil" then
    	response["Inserted"] = utils.bool(general[6])
	end
	if type(general[7]) ~= "nil" then
    	response["WriteProtected"] = utils.bool(general[7])
	end
	if mediatypes[1] then
    	response["MediaTypes"] = mediatypes
	end

	-- Add OEM extension properties to the response
	response = self:oem_extend(response, "query." .. self:get_oem_instance_path())
	-- Set the OData context and type for the response
	local sL_table = _.keys(response)
	if #sL_table < 9 then
        local selectList = turbo.util.join(',', sL_table)
		self:set_context(CONSTANTS.VIRTUAL_MEDIA_INSTANCE_CONTEXT.."("..selectList..")")
	else
		self:set_context(CONSTANTS.VIRTUAL_MEDIA_INSTANCE_CONTEXT)
	end
	self:set_type(CONSTANTS.VIRTUAL_MEDIA_TYPE)
	-- Remove extraneous fields from the response
	utils.remove_nils(response)
end

return VirtualMediaHandler