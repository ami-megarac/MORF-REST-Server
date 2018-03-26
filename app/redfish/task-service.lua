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

-- TODO: Copy all images to local docs folder and update links. Make images width max 450px to fit in doc
-- ![Task Service Block Diagram](http://172.16.99.188/diagramo/editor/png.php?diagramId=17)

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

local TaskServiceHandler = class("TaskServiceHandler", RedfishHandler)

local yield = coroutine.yield

-- Set the path names for task service OEM extensions
local collection_oem_path = "tasks.task-collection"
local instance_oem_path = "tasks.task-instance"
local singleton_oem_path = "task-service"
TaskServiceHandler:set_all_oem_paths(collection_oem_path, instance_oem_path, singleton_oem_path)

-- Following diagram depicts the architecture of Task Service
-- ![Task Service Block Diagram](/images/task-service.png)

--Handles GET requests for Task collection and instance
function TaskServiceHandler:get(instance)

	local response = {}

	if instance == "/redfish/v1/TaskService" then
		--GET singleton
		self:get_task_service(response)

	elseif instance == "Tasks" then
		--GET collection
		self:get_task_collection(response)
	else
		--GET instance
		self:get_task_instance(response)
	end

	self:set_response(response)

	self:output()
end


function TaskServiceHandler:get_task_service(response)

	local redis = self:get_db()

	local pl = redis:pipeline()

	local url_segments = self:get_url_segments()

	local singleton = url_segments[1]
	
	local prefix = "Redfish:" .. singleton
	
	-- date/time should be updated whenever it's queried (based on synced date/time setting)
	local sync_date_time = yield(redis:get(prefix .. ":SyncedDateTime"))
	if sync_date_time == "true" then
		local pl = redis:pipeline()
		pl:set("GET:Redfish:TaskService:UpdateDateTime", "update")
		self:doGET({"Redfish:TaskService:DateTime"}, pl, CONFIG.PATCH_TIMEOUT)
	end

	self:set_scope("Redfish:" .. table.concat(url_segments, ":"))

	pl:mget({
		prefix .. ":CompletedTaskOverWritePolicy",
		prefix .. ":LifeCycleEventOnTaskStateChange",
		prefix .. ":ServiceEnabled",
	})

	pl:hmget(prefix .. ":Status", "State", "Health")

	local general, status = unpack(yield(pl:run()))

	-- Creating response
	response["Id"] = "TaskService"
	response["Name"] = "Task Service"
	response["Description"] = "Task Service"
	response["DateTime"] = os.date("!%Y-%m-%dT%TZ") -- TODO, convert Z to timezone diff
	response["CompletedTaskOverWritePolicy"] = general[1]
	response["LifeCycleEventOnTaskStateChange"] = utils.bool(general[2])
	response["ServiceEnabled"] = utils.bool(general[3])
	response["Status"] = {
		State = general[3] == "true" and "Enabled" or "Disabled",
		Health = status[2]
	}
	response["Tasks"] = {
		["@odata.id"] = CONFIG.SERVICE_PREFIX .. "/TaskService/Tasks"
	}

	response = self:oem_extend(response, "query." .. self:get_oem_singleton_path())

	self:set_context(CONSTANTS.TASKSERVICE_CONTEXT)
	self:set_type(CONSTANTS.TASK_SERVICE_TYPE)

	-- GET requests must respond with the 'Allow' header specifying what methods are available for the given URL
	self:set_allow_header("GET, PATCH")

end

--Handles GET Task collection
function TaskServiceHandler:get_task_collection(response)
	local url_segments = self:get_url_segments()
	local collection, secondary_collection = url_segments[1], url_segments[2]

	local tasks = yield(self:get_db():keys("Redfish:" .. collection .. ":" .. secondary_collection .. ":*:TaskState"))

	local odataIDs = utils.getODataIDArray(tasks, 1)

	-- Creating response
	response["Name"] = "Task Collection"
	response["Description"] = "Task Collection"
	response["Members@odata.count"] = #odataIDs
	response["Members"] = odataIDs

	-- properties that are Oem extendable comes below
	response = self:oem_extend(response, "query." .. self:get_oem_collection_path())

	self:set_scope("Redfish:TaskService:Tasks")
	self:set_context(CONSTANTS.TASKSERVICE_COLLECTION_CONTEXT)
	self:set_type(CONSTANTS.TASK_COLLECTION_TYPE)

	-- GET requests must respond with the 'Allow' header specifying what methods are available for the given URL
	self:set_allow_header("GET")
end

function TaskServiceHandler:get_task_instance(response)
	local url_segments = self:get_url_segments()
	local collection, secondary_collection, instance = url_segments[1], url_segments[2], url_segments[3]
	local prefix = "Redfish:" .. collection .. ":" .. secondary_collection .. ":" .. instance

	self:set_scope(prefix)

	--Retrieving data from database
	local pl = self.redis:pipeline()
	pl:mget({
			prefix .. ":Name",
			prefix .. ":Description",
			prefix .. ":TaskState",
			prefix .. ":StartTime",
			prefix .. ":EndTime",
			prefix .. ":TaskStatus",
			prefix .. ":Messages",
			prefix .. ":WaitTime"
		})

	-- Services may terminate a subscription by sending a special "subscription terminated" event as the last message. 
	-- Future requests to the associated subscription resource will respond with HTTP status 404.

	local db_result = yield(pl:run())

	self:assert_resource(db_result)

	local general = unpack(db_result)

	-- As long as the operation is in process, the service shall continue to return a status code of 202 (Accepted) 
	-- when querying the status monitor returned in the location header
	if general[3] ~= CONSTANTS.ENUM.TASK_STATE.COMPLETED then
		--Creating response using data from database
		response["Id"] = tostring(instance)
		response["Name"] = general[1]
		response["Description"] = general[2]
		response["TaskState"] = general[3]
		response["StartTime"] = general[4]
		response["EndTime"] = general[5]
		response["TaskStatus"] = general[6]
		response["Messages"] = general[7] and turbo.escape.json_decode(general[7]) or {}
		response = self:oem_extend(response, "query." .. self:get_oem_instance_path())

		self:set_status(202)
		-- include a wait header specifying the amount of time the client should wait before polling for status
		self:set_header("Prefer", "respond-async; wait=" .. general[8])

		utils.remove_nils(response)

		local keys = _.keys(response)
		if #keys < 8 then
			local select_list = turbo.util.join(",", keys)
			self:set_context(CONSTANTS.TASKSERVICE_INSTANCE_CONTEXT.."(" .. select_list .. ")")
		else
			self:set_context(CONSTANTS.TASKSERVICE_INSTANCE_CONTEXT)
		end
		self:set_type(CONSTANTS.TASK_TYPE)

	-- Once the operation has completed, the status monitor shall return a status code of OK (200) 
	-- and include the headers and response body of the initial operation, as if it had completed synchronously
	else
		-- Overwrite response with the operation result. This may contain odata fields and other required fields
		-- as a stringified JSON data. 
		_.extend(response, turbo.escape.json_decode(general[7]))

		-- TODO: Check if we need separate context/type settings
	end

	-- GET requests must respond with the 'Allow' header specifying what methods are available for the given URL
	self:set_allow_header("GET")
end

function TaskServiceHandler:post()
	local url_segments = self:get_url_segments();
	local collection, secondary_collection, instance = url_segments[1], url_segments[2], url_segments[3]
	if instance ~= nil then
		local redis = self:get_db()
		local task_instance = yield(redis:get("Redfish:" .. collection .. ":" .. secondary_collection .. ":" .. instance .. ":Name"))
		if task_instance == nil then
			self:error_resource_missing_at_uri()
		else
			self:set_header("Allow", "GET")
			self:error_method_not_allowed()
		end
	else	
		-- No PATCH for collections
		self:set_header("Allow", "GET")
		self:error_method_not_allowed()
	end
end

function TaskServiceHandler:put()
	local url_segments = self:get_url_segments();
	local collection, secondary_collection, instance = url_segments[1], url_segments[2], url_segments[3]
	if instance ~= nil then
		local redis = self:get_db()
		local task_instance = yield(redis:get("Redfish:" .. collection .. ":" .. secondary_collection .. ":" .. instance .. ":Name"))
		if task_instance == nil then
			self:error_resource_missing_at_uri()
		else
			self:set_header("Allow", "GET")
			self:error_method_not_allowed()
		end
	else	
		-- No PATCH for collections
		self:set_header("Allow", "GET")
		self:error_method_not_allowed()
	end
end

function TaskServiceHandler:patch(url)
    local url_segments = self:get_url_segments();
	local collection, secondary_collection, instance = url_segments[1], url_segments[2], url_segments[3]
	local response = {}

	if self:can_user_do("ConfigureManager") == false then
		self:error_insufficient_privilege()
	end

	-- Only TaskService Resource is PATCHable
	if url == "/redfish/v1/TaskService" then

		-- Allow the OEM patch handlers for the task service to have the first chance to handle the request body
		response = self:oem_extend(response, "patch." .. self:get_oem_singleton_path())

		local prefix = "Redfish:TaskService:"

		local request_data = self:get_json()

		if type(request_data) == "table" then

			-- TODO: see if we can take it from schema automatically
			local known_properties = {"Id", "Name", "Description", "ServiceEnabled", "CompletedTaskOverWritePolicy", "DateTime",
										"LifeCycleEventOnTaskStateChange", "Status", "Tasks"}

			-- Only PATCH accepted in TaskService is ServiceEnabled operation
			local writable_properties = {"ServiceEnabled"}

			if self:assert_patch(response, known_properties, writable_properties) then

				if request_data["ServiceEnabled"] ~= nil then
					self:add_audit_log_entry(self:create_message("Security", "ResourceModified", nil, {"ServiceEnabled", self:get_request().path}))
					yield(self:get_db():set(prefix .. "ServiceEnabled", request_data.ServiceEnabled == true and "true" or "false"))
				end

			end

		end

		self:get_task_service(response)
	-- All other URIs under TaskService is not PATCHable
	else
		if instance ~= nil then
			local redis = self:get_db()
			local task_instance = yield(redis:get("Redfish:" .. collection .. ":" .. secondary_collection .. ":" .. instance .. ":Name"))
			if task_instance == nil then
				self:error_resource_missing_at_uri()
			else
				self:set_header("Allow", "GET")
				self:error_method_not_allowed()
				--Throwing error if request is to collection
			end
		else	
			-- No PATCH for collections
			self:set_header("Allow", "GET")
			self:error_method_not_allowed()
		end
	end

	self:set_response(response)

	self:output()

end

function TaskServiceHandler:delete(url)
	local url_segments = self:get_url_segments();
	local collection, secondary_collection, instance = url_segments[1], url_segments[2], url_segments[3]
	if instance ~= nil then
		local redis = self:get_db()
		local task_instance = yield(redis:get("Redfish:" .. collection .. ":" .. secondary_collection .. ":" .. instance .. ":Name"))
		if task_instance == nil then
			self:error_resource_missing_at_uri()
		else
			self:set_header("Allow", "GET")
			self:error_method_not_allowed()
		end
	else	
		-- No PATCH for collections
		self:set_header("Allow", "GET")
		self:error_method_not_allowed()
	end
end

return TaskServiceHandler