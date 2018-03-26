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

local EventServiceHandler = class("EventServiceHandler", RedfishHandler)

local yield = coroutine.yield

-- Set the path names for system OEM extensions
local collection_oem_path = "events.subscription-collection"
local instance_oem_path = "events.subscription-instance"
local singleton_oem_path = "events.event-service"
EventServiceHandler:set_all_oem_paths(collection_oem_path, instance_oem_path, singleton_oem_path)

local SEND_TEST_TARGET = CONSTANTS.SEND_TEST_TARGET

-- Following diagram depicts the architecture of Event Service
-- ![Event Service Block Diagram](/images/event-service.png)

--Handles GET requests for Event Service
function EventServiceHandler:get(instance)
	local response = {}
	self.redis = self:get_db()

	if instance == "/redfish/v1/EventService" then
		--GET singleton
		self:get_event_service(response)

	elseif instance == "Subscriptions" then
		--GET collection
		self:get_subscription_collection(response)
	else
		--GET instance
		self:get_subscription_instance(response)
	end

	self:set_response(response)

	self:output()
end

local allowed_subscriptions = {
		"StatusChange",
		"ResourceUpdated",
		"ResourceAdded",
		"ResourceRemoved",
		"Alert"
	} 

-- Handles GET Event Service singleton
function EventServiceHandler:get_event_service(response)
	local url_segments = self:get_url_segments()
	local collection = url_segments[1]
	
	local prefix = "Redfish:" .. collection
	self:set_scope(prefix)

	--Retrieving data from database
	local pl = self.redis:pipeline()
	pl:hget(prefix .. ":Status", "State")
	pl:hget(prefix .. ":Status", "Health")
	pl:get(prefix .. ":ServiceEnabled")
	pl:get(prefix .. ":DeliveryRetryAttempts")
	pl:get(prefix .. ":DeliveryRetryIntervalSeconds")

	--Creating response using data from database
	local result = yield(pl:run())
	response["Id"] = "EventService"
	response["Name"] = "Event Service"
	response["Description"] = "Event Service"
	response["Status"] = {
		State = result[3] == "true" and "Enabled" or "Disabled",
		Health = result[2]
	}
	response["ServiceEnabled"] = utils.bool(result[3])
	response["DeliveryRetryAttempts"] = tonumber(result[4])
	response["DeliveryRetryIntervalSeconds"] = tonumber(result[5])
	response["EventTypesForSubscription"] = allowed_subscriptions
	response["Subscriptions"] = {}
	response["Subscriptions"]["@odata.id"] = CONFIG.SERVICE_PREFIX .. "/" .. collection .. "/Subscriptions"

	-- All actions key starts with # 
	-- Target will be automatically added to server handler
	-- AllowableValues are expected in the actions
	self:add_action({
			["#EventService.SubmitTestEvent"] = {
				target = SEND_TEST_TARGET,
				["EventType@Redfish.AllowableValues"] = allowed_subscriptions
			}
		})

	response = self:oem_extend(response, "query." .. self:get_oem_singleton_path())

	utils.remove_nils(response)

	local keys = _.keys(response)
	if #keys < 7 then
		local select_list = turbo.util.join(",", keys)
		self:set_context(CONSTANTS.EVENTSERVICE_CONTEXT .. "(" .. select_list .. ")")
	else
		self:set_context(CONSTANTS.EVENTSERVICE_CONTEXT)
	end

	self:set_type(CONSTANTS.EVENT_SERVICE_TYPE)

	-- GET requests must respond with the 'Allow' header specifying what methods are available for the given URL
	self:set_allow_header("GET, PATCH")
end


function EventServiceHandler:get_subscription_collection(response)
	local url_segments = self:get_url_segments()
	local collection, secondary_collection = url_segments[1], url_segments[2]

	local subscriptions = yield(self:get_db():keys("Redfish:" .. collection .. ":" .. secondary_collection .. ":*:Destination"))

	local odataIDs = utils.getODataIDArray(subscriptions, 1)

	-- Creating response
	response["Name"] = "Event Subscriptions Collection"
	response["Members@odata.count"] = #odataIDs
	response["Members"] = odataIDs

	-- properties that are Oem extendable comes below
	response = self:oem_extend(response, "query." .. self:get_oem_collection_path())

	self:set_scope("Redfish:"..table.concat(self.url_segments,':'))
	self:set_context(CONSTANTS.EVENTSERVICE_DESTINATION_COLLECTION_CONTEXT)
	self:set_type(CONSTANTS.EVENTDESTINATION_COLLECTION_TYPE)

	-- GET requests must respond with the 'Allow' header specifying what methods are available for the given URL
	self:set_allow_header("GET, POST")
end


function EventServiceHandler:get_subscription_instance(response)
	local url_segments = self:get_url_segments()
	local collection, secondary_collection, instance = url_segments[1], url_segments[2], url_segments[3]
	local prefix = "Redfish:" .. collection .. ":" .. secondary_collection .. ":" .. instance

	self:set_scope(prefix)

	--Retrieving data from database
	local pl = self.redis:pipeline()
	pl:mget({
			prefix .. ":Name",
			prefix .. ":Description",
			prefix .. ":Destination",
			prefix .. ":Context",
			prefix .. ":Protocol",
		})
	pl:smembers(prefix .. ":EventTypes")

	-- Services may terminate a subscription by sending a special "subscription terminated" event as the last message. 
	-- Future requests to the associated subscription resource will respond with HTTP status 404.

	local db_result = yield(pl:run())

	self:assert_resource(db_result)

	local general, event_types = unpack(db_result)

	--Creating response using data from database
	response["Id"] = instance
	response["Name"] = general[1]
	response["Description"] = general[2]
	response["Destination"] = general[3]
	response["Context"] = general[4]
	response["Protocol"] = general[5]
	response["EventTypes"] = event_types
	response = self:oem_extend(response, "query." .. self:get_oem_instance_path())

	utils.remove_nils(response)

	local keys = _.keys(response)
	if #keys < 7 then
		local select_list = turbo.util.join(",", keys)
		self:set_context(CONSTANTS.EVENTDESTINATION_INSTANCE_CONTEXT.."(" .. select_list .. ")")
	else
		self:set_context(CONSTANTS.EVENTDESTINATION_INSTANCE_CONTEXT.."(*)")
	end
	
	self:set_type(CONSTANTS.EVENTDESTINATION_TYPE)

	-- GET requests must respond with the 'Allow' header specifying what methods are available for the given URL
	self:set_allow_header("GET, DELETE")
end

function EventServiceHandler:patch(url)
	local redis = self:get_db()
	local request_data = turbo.escape.json_decode(self:get_request().body)
	local response = {}
	local pl = redis:pipeline()
	local extended = {}
	local successful_sets = {}
	local error = false
	
	if self:can_user_do("ConfigureManager") == false then
		self:error_insufficient_privilege()
	end

	-- Only EventService Resource is PATCHable
	-- All other URIs under EventService is not PATCHable
	if url == "Subscriptions" then
		-- Allow OEM extensions to PATCH the Subscriptions collection
		self:set_allow_header("GET, POST")
		self:set_status(405)

		response = self:oem_extend(response, "patch." .. self:get_oem_collection_path())

		if self:get_status() == 405 then
			self:error_method_not_allowed()
		end
	elseif tonumber(url) ~= nil then
		-- Allow OEM extensions to PATCH a Subscriptions instance
		self:set_allow_header("GET, DELETE")
		self:set_status(405)

		response = self:oem_extend(response, "patch." .. self:get_oem_instance_path())

		if self:get_status() == 405 then
			self:error_method_not_allowed()
		end
	end
	if url == "/redfish/v1/EventService" then
		-- Allow the OEM patch handlers for the event service to have the first chance to handle the request body
		response = self:oem_extend(response, "patch." .. self:get_oem_singleton_path())

		local prefix = "Redfish:EventService:"

		-- TODO: see if we can take it from schema automatically
		local known_properties = {"@odata.context", "@odata.etag", "@odata.id", "@odata.type", "Id", "Name", "Description", "ServiceEnabled", "DeliveryRetryAttempts", "DeliveryRetryIntervalSeconds", 
									"EventTypesForSubscription", "Actions", "Status", "Subscriptions"}

		-- Only PATCH accepted in EventService is ServiceEnabled operation
		local writable_properties = {"ServiceEnabled"}

		--Validating ServiceEnabled property and adding error if property is incorrect
		if not self:assert_patch(response, known_properties, writable_properties) then
			error = true
		end
			
			if request_data.ServiceEnabled ~= nil then
				if type(request_data.ServiceEnabled) ~= "boolean" then
					--self:error_property_value_type("ServiceEnabled", tostring(request_data.ServiceEnabled), extended)
					error = true
					table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/ServiceEnabled"}, {tostring(request_data.ServiceEnabled), "ServiceEnabled"}))
					self:add_error_body(response,400,unpack(extended))
				else
					pl:set(prefix.."ServiceEnabled", tostring(request_data.ServiceEnabled))
					self:update_lastmodified(prefix, os.time())
					table.insert(successful_sets, "ServiceEnabled")
				end
				request_data.ServiceEnabled = nil
			end
			
			if #pl.pending_commands > 0 then
				-- Update last modified so that E-Tag can respond properly
				self:update_lastmodified("Redfish:EventService:", os.time(), pl, 1)
				
				local result = yield(pl:run())
				self:add_audit_log_entry(self:create_message("Security", "ResourceModified", nil, {turbo.util.join(", ", successful_sets), self:get_request().path}))
			end
			

		--Checking if there were errors and adding them to the response if there are
		 if error then
			self:set_response(response)
			self:output()
			return
		else
			self:set_status(204)
			self:output()
			return
		end
		
	end		
end

local protocol_allowable_vals = {"Redfish"}

-- Handle subscription events and Test alert action
function EventServiceHandler:post(url, url_property)

    local prefix = "Redfish:EventService:"
    local response = {}
	local request_data = self:get_json()

	if self:can_user_do("ConfigureManager") == false then
		self:error_insufficient_privilege()
	end
    
	--print("typeof(request_data)")	
	--print(typeOf(request_data))
	
	-- TODO: see if we can take it from schema automatically
	local known_properties = {"@odata.context","@odata.id","@odata.type","Oem","Id", "Name", "Description","Destination", "EventTypes","Context","Protocol",  
									"HttpHeaders"}

	-- Only PATCH accepted in EventService is ServiceEnabled operation
	local writable_properties = {"Name","Description","Destination", "EventTypes","Context","Protocol"}
	
	local missing = {}

	-- Handles action here
	if url == SEND_TEST_TARGET then

		-- Push the target to the SubmitTestEvent list, so that EventService can take care of it
		-- Send events to all subscribers - https://github.com/DMTF/spmf/issues/883
		-- self:get_db():rpush(prefix .. "SubmitTestEvent", request_data.EventType)
		
		local eventtype = request_data.EventType

		if not turbo.util.is_in(eventtype, allowed_subscriptions) then
			self:error_action_parameter_format("EventType", eventtype)
		else
			utils.add_event_entry(self:get_db(), "Redfish:Managers:Self:LogServices:SEL", "Base.1.0.0", "PropertyValueTypeError", {"string", "AssetTag"}, "Event", nil, "Redfish:Systems:System1:Name", nil, 1, os.time(), eventtype)
			-- Update last modified so that E-Tag can respond properly
			self:update_lastmodified("Redfish:EventService:Events:" .. eventtype, os.time())
			self:set_status(204)
			self:output()
		end

elseif url == "Subscriptions" then -- incoming new subscription
        local request_body = turbo.escape.json_decode(self:get_request().body)
		if next(request_body) == nil then
			self:error_request_empty();
		end
		
		--Validating ServiceEnabled property and adding error if property is incorrect
		if self:assert_patch(response, known_properties, writable_properties) then
			-- Required on create : Destination, EventTypes, Context, Protocol
			if request_data["Destination"] == nil then table.insert(missing, "Destination") end
			if request_data["Context"] == nil then table.insert(missing, "Context") end
			if request_data["Protocol"] == nil then table.insert(missing, "Protocol") end
			if request_data["EventTypes"] == nil then table.insert(missing, "EventTypes") end

			if #missing > 0 then
				self:error_create_failed_missing_req_properties(missing)
			else
				local subscription_id = yield(self:get_db():zrange(prefix .. "Subscriptions:SortedIDs", -1 ,-1))
				local id = subscription_id[1]
				
				if(id ~= nil) then
					id=id+1
				 else
					id=1
				end
				
				-- Add the subscription to event service
				local pl = self:get_db():pipeline()
				local nextId = id
				
				if request_data["Name"] ~= nil then
					if type(request_data["Name"]) ~= "string" then
						self:error_property_value_type("Name", tostring(request_data["Name"]))
					else
						pl:set(prefix .. "Subscriptions:" .. nextId .. ":Name", request_data["Name"])
					end
				else
					local Name = "Subscription " .. nextId
					pl:set(prefix .. "Subscriptions:" .. nextId .. ":Name", Name)
				end
				
				if request_data["Description"] ~= nil then
					if type(request_data["Description"]) ~= "string" then
						self:error_property_value_type("Description", tostring(request_data["Description"]))
					else
						pl:set(prefix .. "Subscriptions:" .. nextId .. ":Description", request_data["Description"])
					end
				end
				
				if type(request_data.Destination) ~= "string" then
					self:error_property_value_type("Destination", tostring(request_data.Destination))
				else
					pl:set(prefix .. "Subscriptions:" .. nextId .. ":Destination", request_data.Destination)
				end

				if type(request_data.Context) ~= "string" then
					self:error_property_value_type("Context", tostring(request_data.Context))
				else
					pl:set(prefix .. "Subscriptions:" .. nextId .. ":Context", request_data.Context)
				end

				if type(request_data.Protocol) ~= "string" then
					self:error_property_value_type("Context", tostring(request_data.Context))
				elseif not turbo.util.is_in(request_data.Protocol, protocol_allowable_vals) then
					self:error_action_parameter_format("Protocol", request_data.Protocol)
				else
					pl:set(prefix .. "Subscriptions:" .. nextId .. ":Protocol", request_data.Protocol)
				end

				if request_data.HttpHeaders then
					if type(request_data.HttpHeaders) ~= "table" then
						self:error_property_value_type("HttpHeaders", tostring(request_data.HttpHeaders))
					else
						local success, headers = pcall(turbo.escape.json_encode, request_data.HttpHeaders)
						if not success then
							self:error_property_value_format("HttpHeaders", tostring(request_data.HttpHeaders))
						else
							pl:set(prefix .. "Subscriptions:" .. nextId .. ":HttpHeaders", headers)
						end
					end
				end
				
				pl:set(prefix .. "Subscriptions:" .. nextId .. ":UserName", self.username)

				for eti, etv in ipairs(request_data.EventTypes) do
					if type(etv) ~= "string" then
						self:error_property_value_type("EventTypes[" + eti + "]", tostring(etv))
					elseif not turbo.util.is_in(etv, allowed_subscriptions) then
						self:error_property_value_not_in_list("EventTypes[" + eti + "]", tostring(etv))
					else
						pl:sadd(prefix .. "Subscriptions:" .. nextId .. ":EventTypes", etv)
					end
				end

				-- Update last modified so that E-Tag can respond properly
				self:update_lastmodified(prefix .. "Subscriptions:" .. nextId, os.time(), pl)

				local db_result = yield(pl:run())
				
				local time_stamp = os.time()
				yield(self:get_db():zadd(prefix .. "Subscriptions:SortedIDs",time_stamp,id))
				
				local postprefix = "Redfish:EventService:Subscriptions:".. nextId
				self:set_scope(postprefix)

				--Retrieving data from database
				local pl = self:get_db():pipeline()
				pl:mget({
						postprefix .. ":Name",
						postprefix .. ":Description",
						postprefix .. ":Destination",
						postprefix .. ":Context",
						postprefix .. ":Protocol",
					})
				pl:smembers(postprefix .. ":EventTypes")
			
				local db_result = yield(pl:run())
			
				self:assert_resource(db_result)
			
				local general, event_types = unpack(db_result)
			
				--Creating response using data from database
				response["Id"] = nextId
				response["Name"] = general[1]
				response["Description"] = general[2]
				response["Destination"] = general[3]
				response["Context"] = general[4]
				response["Protocol"] = general[5]
				response["EventTypes"] = event_types
				
				local keys = _.keys(response)
				if #keys < 7 then
					local select_list = turbo.util.join(",", keys)
					self:set_context(CONSTANTS.EVENTDESTINATION_INSTANCE_CONTEXT.."(" .. select_list .. ")")
				else
					self:set_context(CONSTANTS.EVENTDESTINATION_INSTANCE_CONTEXT)
				end
			
				self:set_type(CONSTANTS.EVENTDESTINATION_TYPE)
				
				self.response_table["@odata.id"] = self.request.headers:get_url()
		
				self.response_table["@odata.context"] = CONFIG.SERVICE_PREFIX .. "/$metadata" .. self.current_context
				
				self.last_modified = coroutine.yield(self.redis:get(self.scope .. ":LastModified")) or tostring(utils.fileTime('/usr/local/'))
				self.response_table["@odata.etag"] = "W/\""..self.last_modified.."\""
		
				self.response_table["@odata.type"] = self.current_type
				
				-- Services shall respond to a successful subscription with HTTP status 201 and 
				-- set the HTTP Location header to the address of a new subscription resource. 
				-- Subscriptions are persistent and will remain across event service restarts.
				self:update_lastmodified(prefix .. "Subscriptions", os.time(), pl)
				self:set_status(201)
				self:set_header("Location", CONFIG.SERVICE_PREFIX .. "/EventService/Subscriptions/" .. nextId)
			end
		end	
		
		self:set_response(response)
		self:output()
	-- Always have the else condition similar to "default" case to respond no other actions or post operations available
	else 
		if tonumber(url) ~= nil then
			self:set_allow_header("GET, DELETE")
		elseif url == "/redfish/v1/EventService" then
			self:set_allow_header("GET, PATCH")
		else
			self:set_allow_header("GET")
		end
		self:error_method_not_allowed()
	end
	
end


function EventServiceHandler:delete(instance_name)
  local url_segments = self:get_url_segments()
	local collection, secondary_collection, instance = url_segments[1], url_segments[2], url_segments[3]
	local prefix = "Redfish:EventService:"

	if tonumber(instance_name) ~= nil then
		local username, destination = unpack(yield(self:get_db():mget({prefix .. "Subscriptions:" .. instance_name .. ":UserName", 
			prefix .. "Subscriptions:" .. instance_name .. ":Destination"})))

		if destination ~= nil then

			-- Check if user owns it
			-- Or Check if user is privileged to delete it
			if username == self.username or self:can_user_do("ConfigureManager") then
				-- User has rights to delete his subscription 
				local pl = self:get_db():pipeline()
				pl:del(prefix .. "Subscriptions:" .. instance_name .. ":Name")
				pl:del(prefix .. "Subscriptions:" .. instance_name .. ":Destination")
				pl:del(prefix .. "Subscriptions:" .. instance_name .. ":Context")
				pl:del(prefix .. "Subscriptions:" .. instance_name .. ":Protocol")
				pl:del(prefix .. "Subscriptions:" .. instance_name .. ":HttpHeaders")
				pl:del(prefix .. "Subscriptions:" .. instance_name .. ":UserName")
				pl:del(prefix .. "Subscriptions:" .. instance_name .. ":EventTypes")
                
                pl:zrem(prefix .. "Subscriptions:SortedIDs", instance_name)
                
				-- Update last modified so that E-Tag can respond properly
				self:update_lastmodified(prefix .. "Subscriptions", os.time(), pl)

				local db_result = yield(pl:run())
			
				self:add_audit_log_entry(self:create_message("Security", "ResourceDeleted", nil, {self:get_request().path}))
				self:set_status(204)
			-- Or return an error stating it cannot be deleted
			else
				self:error_insufficient_privilege()
			end
		-- Resource does not exists or already deleted
		else
			self:error_resource_missing_at_uri()
		end

	else
    if instance ~= nil then
        local exists = yield(self:get_db():get(prefix .. "Subscriptions:" .. instance_name .. ":Name"))
	  		if not exists then
	    			self:error_resource_missing_at_uri()
		    end
    end
		if instance_name == "Subscriptions" and instance == nil then
			self:set_allow_header("GET, POST")
		elseif instance_name == "/redfish/v1/EventService" and instance == nil then
			self:set_allow_header("GET, PATCH")
		else
			self:set_allow_header("GET")
		end
		self:error_method_not_allowed()
	end

	self:set_type(CONSTANTS.EVENTDESTINATION_TYPE) --TODO: Check if it is applicable

	self:output()

end

return EventServiceHandler
