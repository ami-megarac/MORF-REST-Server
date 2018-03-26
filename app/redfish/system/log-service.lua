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

local SystemLogServiceHandler = class("SystemLogServiceHandler", RedfishHandler)

local yield = coroutine.yield

local allowed_clears = { "ClearAll" }

-- Set the path names for system log service OEM extensions
local collection_oem_path = "system.system-logservice-collection"
local instance_oem_path = "system.system-logservice-instance"
local action_oem_path = "system.system-logservice-instance-actions"
SystemLogServiceHandler:set_all_oem_paths(collection_oem_path, instance_oem_path, nil, action_oem_path)

--Handles GET requests for System Log Service collection and instance
function SystemLogServiceHandler:get(id1, id2)

	local response = {}
	
	if id2 == nil then
		--GET collection
		self:get_collection(response)
	else
		--GET instance
		self:get_instance(response)
	end

	self:set_response(response)

	self:output()
end

-- Handles GET System Log Service collection
function SystemLogServiceHandler:get_collection(response)
	-- Before proceeding with the handler, we'll make sure the collection request is valid
	local collection_exists = self:parent_exists()
	self:assertTrue_404(collection_exists)

	local redis = self:get_db()
	local url_segments = self:get_url_segments();

	local collection, instance, secondary_collection = 
		url_segments[1], url_segments[2], url_segments[3];

	local prefix = "Redfish:" .. collection .. ":" .. instance .. ":LogServices"

	self:set_scope("Redfish:" .. table.concat(url_segments, ":"))

	-- Creating response
	response["Name"] = "Log Services Collection"
	response["Description"] = "Collection of log services for this system"

	local odataIDs = utils.getODataIDArray(yield(redis:keys(prefix .. ":*:MaxNumberOfRecords")), 1)

	response["Members@odata.count"] = #odataIDs
	response["Members"] = odataIDs

	self:set_context(CONSTANTS.LOGSERVICE_COLLECTION_CONTEXT)
	self:set_type(CONSTANTS.LOG_SERVICE_COLLECTION_TYPE)

	response = self:oem_extend(response, "query." .. self:get_oem_collection_path())

	-- GET requests must respond with the 'Allow' header specifying what methods are available for the given URL
	self:set_allow_header("GET")
end

-- Handles GET System Log Service instance
function SystemLogServiceHandler:get_instance(response)
	local redis = self:get_db()
	local url_segments = self:get_url_segments();

	local collection, instance, secondary_collection, id = 
		url_segments[1], url_segments[2], url_segments[3], url_segments[4];

	local prefix = "Redfish:" .. collection .. ":" .. instance .. ":" .. secondary_collection .. ":" .. id

	self:set_scope("Redfish:"..table.concat(url_segments,':'))
	
	-- date/time should be updated whenever it's queried (based on synced date/time setting)
	local sync_date_time = yield(redis:get(prefix .. ":SyncedDateTime"))
	local dt_prefix = prefix
	if sync_date_time == "true" then
		dt_prefix = "Redfish:Systems:"..instance
		local pl = redis:pipeline()
		pl:set("GET:Redfish:Systems:"..instance..":UpdateDateTime", "update")
		self:doGET({dt_prefix..":DateTime", dt_prefix..":DateTimeLocalOffset"}, pl, CONFIG.PATCH_TIMEOUT)
	end

	local pl = redis:pipeline()

	--Retrieving data from database
	pl:mget({
			prefix .. ":Name",
			prefix .. ":MaxNumberOfRecords",
			prefix .. ":OverWritePolicy",
			prefix .. ":DateTime",
			prefix .. ":DateTimeLocalOffset",
			prefix .. ":ServiceEnabled"
		})
	pl:hmget(prefix .. ":Status", "State", "Health")

    local db_result = yield(pl:run())

    -- Check that data was found in Redis, if not we throw a 404 NOT FOUND
    self:assert_resource(db_result)

	local general, status = unpack(db_result)

	--Creating response using data from database
	response["Id"] = id
	response["Name"] = general[1]
	response["MaxNumberOfRecords"] = tonumber(general[2])
	response["OverWritePolicy"] = general[3]
	response["DateTime"] = general[4]
	response["DateTimeLocalOffset"] = general[5]
	response["ServiceEnabled"] = utils.bool(general[6])
	response["Status"] = {
		State = general[5] == "true" and "Enabled" or "Disabled",
		Health = status[2],
	}
	response["Entries"] = {}
	response["Entries"]["@odata.id"] = CONFIG.SERVICE_PREFIX.."/"..collection.."/"..instance.."/"..secondary_collection.."/"..id..'/Entries'
	self:add_action({
			["#LogService.ClearLog"] = {
				target = CONFIG.SERVICE_PREFIX..'/'..collection..'/'..instance..'/'..secondary_collection..'/'..id..'/Actions/LogService.ClearLog',
				["ClearType@Redfish.AllowableValues"] = allowed_clears
			}
		})

	if response["OverWritePolicy"] ~= nil then
		response["OverWritePolicy@Redfish.AllowableValues"] = {"Unknown", "WrapsWhenFull", "NeverOverWrites"}
	end

	-- Add OEM extension properties to the response
	response["Actions"] = self:oem_extend(response["Actions"], "query." .. self:get_oem_instance_action_path())
	response = self:oem_extend(response, "query." .. self:get_oem_instance_path())

	utils.remove_nils(response)

	local keys = _.keys(response)
	if #keys < 10 then
		local select_list = turbo.util.join(",", keys)
		self:set_context(CONSTANTS.LOGSERVICE_INSTANCE_CONTEXT .. "(" .. select_list .. ")")
	else
		self:set_context(CONSTANTS.LOGSERVICE_INSTANCE_CONTEXT)
	end

	self:set_type(CONSTANTS.LOG_SERVICE_TYPE)

	-- GET requests must respond with the 'Allow' header specifying what methods are available for the given URL
	self:set_allow_header("GET, PATCH")
end

--Handles PATCH request for System Log Service
function SystemLogServiceHandler:patch(_system_id, id)

	local url_segments = self:get_url_segments()
	local collection, instance, secondary_collection, inner_instance = url_segments[1], url_segments[2], url_segments[3], url_segments[4]

	--Throwing error if request is to collection
	if inner_instance == nil then
		-- Allow an OEM patch handler for system log service collections, if none exists, return with the normal 405 response
		self:set_header("Allow", "GET")
		self:set_status(405)

		response = self:oem_extend(response, "patch." .. self:get_oem_collection_path())

		if self:get_status() == 405 then
			self:error_method_not_allowed()
		end
	else
		-- Allow the OEM patch handlers for system log service instances to have the first chance to handle the request body
		response = self:oem_extend(response, "patch." .. self:get_oem_instance_path())
	end

	--Making sure current user has permission to modify log service settings
	if self:can_user_do("ConfigureComponents") == true then
		local redis = self:get_db()
		local response = {}

		local exists = yield(redis:exists("Redfish:Systems:" .. _system_id .. ":LogServices:" .. id .. ":MaxNumberOfRecords"))
		if exists ~= 1 then
			self:error_resource_missing_at_uri()
		else
			local request_data = turbo.escape.json_decode(self:get_request().body)

			self:set_scope("Redfish:" .. table.concat(url_segments, ":"))

			local pl = redis:pipeline()
			local prefix = "Redfish:" .. collection .. ":" .. instance .. ":" .. secondary_collection .. ":" .. inner_instance
			local extended = {}
			local successful_sets = {}

			--Validating ServiceEnabled property and adding error if property is incorrect
			if request_data.ServiceEnabled ~= nil then
				if type(request_data.ServiceEnabled) ~= "boolean" then
					table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/ServiceEnabled"}, {request_data.ServiceEnabled, "ServiceEnabled"}))
				else
					--ServiceEnabled is valid and will be added to database
					pl:set(prefix .. ":ServiceEnabled", tostring(request_data.ServiceEnabled))
					table.insert(successful_sets, "ServiceEnabled")
				end
				request_data.ServiceEnabled = nil
			end

			--Setting DateTime
			if request_data.DateTime ~= nil then
				if string.match(request_data.DateTime, "^[1-2][0-9][0-9][0-9][-][0-1][0-9][-][0-3][0-9]T[0-1][0-9]:[0-5][0-9]:[0-5][0-9]Z$") == nil and
					string.match(request_data.DateTime, "^[1-2][0-9][0-9][0-9][-][0-1][0-9][-][0-3][0-9]T[0-1][0-9]:[0-5][0-9]:[0-5][0-9][-+][0-1][0-9]:[0-5][0-9]$") == nil then
					table.insert(extended, self:create_message("Base", "PropertyValueFormatError", {"#/DateTime"}, {request_data.DateTime, "DateTime"}))
				else
					pl:set(prefix .. ":DateTime", request_data.DateTime)
					table.insert(successful_sets, "DateTime")
				end
				request_data.DateTime = nil
			end

			--Setting DateTimeLocalOffset
			if request_data.DateTimeLocalOffset ~= nil then
				if string.match(request_data.DateTimeLocalOffset, "^[-+][0-1][0-9]:[0-5][0-9]$") == nil then
					table.insert(extended, self:create_message("Base", "PropertyValueFormatError", {"#/DateTimeLocalOffset"}, {request_data.DateTimeLocalOffset, "DateTimeLocalOffset"}))
				else
					pl:set(prefix .. ":DateTimeLocalOffset", request_data.DateTimeLocalOffset)
					table.insert(successful_sets, "DateTimeLocalOffset")
				end
				request_data.DateTimeLocalOffset = nil
			end

			self:update_lastmodified(self.scope)

			local result = yield(pl:run())
			self:add_audit_log_entry(self:create_message("Security", "ResourceModified", nil, {turbo.util.join(", ", successful_sets), self:get_request().path}))

			--Checking if there are any additional properties in the request and creating an error to show these properties
			local leftover_fields = utils.table_len(request_data)
			if leftover_fields ~= 0 then
				local keys = _.keys(request_data)
				for _i, unknown_val in pairs(keys) do
					table.insert(extended, self:create_message("Base", "PropertyUnknown", unknown_val, unknown_val))
				end
			end

			--Checking if there were errors and adding them to the response if there are
			if #extended ~= 0 then
				self:add_error_body(response,400, unpack(extended))
			else
				self:update_lastmodified(prefix, os.time())
				self:set_status(204)
			end

			self:set_response(response)
			self:output()
		end
	else
		self:error_insufficient_privilege()
	end
end

return SystemLogServiceHandler
