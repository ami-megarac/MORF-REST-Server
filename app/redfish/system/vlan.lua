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

local SystemVlanHandler = class("SystemVlanHandler", RedfishHandler)

local yield = coroutine.yield

-- Set the path names for system vlan OEM extensions
local collection_oem_path = "system.system-vlan-collection"
local instance_oem_path = "system.system-vlan-instance"
SystemVlanHandler:set_all_oem_paths(collection_oem_path, instance_oem_path)

--Handles GET requests for System VLANs collection and instance
function SystemVlanHandler:get(id1, id2, id3)

	local response = {}
	
	if id3 == nil then
		--GET collection
		self:get_collection(response)
	else
		--GET instance
		self:get_instance(response)
	end

	self:set_response(response)

	self:output()
end

-- Handles GET System VLANs collection
function SystemVlanHandler:get_collection(response)
	-- Before proceeding with the handler, we'll make sure the collection request is valid
	local collection_exists = self:parent_exists()
	self:assertTrue_404(collection_exists)

	local redis = self:get_db()
	local url_segments = self:get_url_segments();

	local collection, instance, secondary_collection, secondary_instance, inner_collection = 
		url_segments[1], url_segments[2], url_segments[3], url_segments[4], url_segments[5];

	local prefix = "Redfish:" .. collection .. ":" .. instance .. ":" .. secondary_collection .. ":" .. secondary_instance .. ":VLANs"

	self:set_scope("Redfish:" .. table.concat(url_segments, ':'))

	-- Creating response
	response["Name"] = "VLAN Network Interface Collection"
	response["Description"] = "Collection of VLANs for this system"

	local odataIDs = utils.getODataIDArray(yield(redis:keys(prefix .. ":*:VLANId")), 1)

	response["Members@odata.count"] = #odataIDs
	response["Members"] = odataIDs

	response = self:oem_extend(response, "query." .. self:get_oem_collection_path())

	self:set_context(CONSTANTS.VLAN_COLLECTION_CONTEXT)
	self:set_type(CONSTANTS.VLAN_COLLECTION_TYPE)

	-- GET requests must respond with the 'Allow' header specifying what methods are available for the given URL
	self:set_allow_header("GET")
end

-- Handles GET System VLANs instance
function SystemVlanHandler:get_instance(response)
	local redis = self:get_db()
	local url_segments = self:get_url_segments();

	local collection, instance, secondary_collection, secondary_instance, inner_collection, inner_instance = 
		url_segments[1], url_segments[2], url_segments[3], url_segments[4], url_segments[5], url_segments[6];

	local prefix = "Redfish:" .. collection .. ":" .. instance .. ":" .. secondary_collection .. ":" .. secondary_instance .. ":VLANs:" .. inner_instance

	self:set_scope("Redfish:"..table.concat(url_segments,':'))

	--Retrieving data from database
	local pl = redis:pipeline()
	pl:mget({
			prefix .. ":Name",
			prefix .. ":Description",
			prefix .. ":VLANEnable",
			prefix .. ":VLANId"
		})

    local db_result = yield(pl:run())

    -- Check that data was found in Redis, if not we throw a 404 NOT FOUND
    self:assert_resource(db_result)

	local general = unpack(db_result)

	--Creating response using data from database
	response["Id"] = inner_instance
	response["Name"] = general[1]
	response["Description"] = general[2]
	response["VLANEnable"] = utils.bool(general[3])
	response["VLANId"] = tonumber(general[4])

	response = self:oem_extend(response, "query." .. self:get_oem_instance_path())

	utils.remove_nils(response)

	local keys = _.keys(response)
	if #keys < 5 then
		local select_list = turbo.util.join(",", keys)
		self:set_context(CONSTANTS.VLAN_INSTANCE_CONTEXT.."(" .. select_list .. ")")
	else
		self:set_context(CONSTANTS.VLAN_INSTANCE_CONTEXT)
	end

	self:set_type(CONSTANTS.VLAN_TYPE)

	-- GET requests must respond with the 'Allow' header specifying what methods are available for the given URL
	self:set_allow_header("GET, PATCH")
end

--Handles PATCH request for System VLANs Interface
function SystemVlanHandler:patch()

	local url_segments = self:get_url_segments()
	local collection, instance, secondary_collection, secondary_instance, inner_collection, inner_instance = 
		url_segments[1], url_segments[2], url_segments[3], url_segments[4], url_segments[5], url_segments[6];

	--Throwing error if request is to collection
	if inner_instance == nil then
		-- Allow an OEM patch handler for system vlan collections, if none exists, return with the normal 405 response
		self:set_header("Allow", "GET")
		self:set_status(405)

		response = self:oem_extend(response, "patch." .. self:get_oem_collection_path())

		if self:get_status() == 405 then
			self:error_method_not_allowed()
		end
	else
		-- Allow the OEM patch handlers for system vlan instances to have the first chance to handle the request body
		response = self:oem_extend(response, "patch." .. self:get_oem_instance_path())
	end

	--Making sure current user has permission to modify VLANs settings
	if self:can_user_do("ConfigureComponents") == true then
		local redis = self:get_db()
		local prefix = "Redfish:" .. collection .. ":" .. instance .. ":" .. secondary_collection .. ":" .. secondary_instance .. ":" .. inner_collection .. ":" .. inner_instance
		local response = {}

		local vlan_exists = yield(redis:exists(prefix .. ":VLANId"))
		if vlan_exists ~= 1 then
			self:error_resource_missing_at_uri()
		else
			local request_data = turbo.escape.json_decode(self:get_request().body)

			self:set_scope("Redfish:" .. table.concat(url_segments, ":"))

			local pl = redis:pipeline()
			local extended = {}
			local successful_sets = {}

			--Validating VLANEnable property and adding error if property is incorrect
			if request_data.VLANEnable ~= nil then
				if type(request_data.VLANEnable) ~= "boolean" then
					table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/VLANEnable"}, {request_data.VLANEnable, "VLANEnable"}))
				else
					--VLANEnable is valid and will be added to database
					pl:set(prefix .. ":VLANEnable", tostring(request_data.VLANEnable))
					table.insert(successful_sets, "VLANEnable")
				end
				request_data.VLANEnable = nil
			end

			--Validating VLANId and adding property or adding error if property is incorrect
			if request_data.VLANId ~= nil then
				if tonumber(request_data.VLANId) == nil then
					table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/VLANId"}, {request_data.VLANId, "VLANId"}))
				elseif tonumber(request_data.VLANId) <= 0 or tonumber(request_data.VLANId) >= 4095 then
					table.insert(extended, self:create_message("Base", "PropertyValueFormatError", {"#/VLANId"}, {request_data.VLANId, "VLANId"}))
				else
					--VLANId is valid and will be added to database
					pl:set(prefix .. ":VLANId", request_data.VLANId)
					table.insert(successful_sets, "VLANId")
				end
				request_data.VLANId = nil
			end

			local result = yield(pl:run())
			self:add_audit_log_entry(self:create_message("Security", "ResourceModified", nil, {turbo.util.join(", ", successful_sets), self:get_request().path}))
			local leftover_fields = utils.table_len(request_data)

			--Checking if there are any additional properties in the request and creating an error to show these properties
			if leftover_fields ~= 0 then
				local keys = _.keys(request_data)
				table.insert(extended, self:create_message("Base", "PropertyNotWritable", keys, turbo.util.join(",", keys)))
			end

			--Checking if there were errors and adding them to the response if there are
			if #extended ~= 0 then
				response["@Message.ExtendedInfo"] = extended
			end

			self:get_instance(response)
		end

		self:set_response(response)
		self:output()
	else
		--Throwing error if user is not authorized
		self:error_insufficient_privilege()
	end
end


return SystemVlanHandler