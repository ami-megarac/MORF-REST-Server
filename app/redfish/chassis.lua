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

local ChassisHandler = class("ChassisHandler", RedfishHandler)
local smbios_prefix = "SMBIOS"
local yield = coroutine.yield    

-- The 'property_access' table specifies read/write permission for all properties.
local property_access = require("property-access.Chassis")["Chassis"]

local led = {"Lit", "Blinking", "Off"}

-- Set the path names for chassis OEM extensions
local collection_oem_path = "chassis.chassis-collection"
local instance_oem_path = "chassis.chassis-instance"
local link_oem_path = "chassis.chassis-instance-links"
ChassisHandler:set_all_oem_paths(collection_oem_path, instance_oem_path, nil, nil, link_oem_path)

--GET Request Handler for Chassis collection and instance
function ChassisHandler:get(id)
  -- Create the GET response for Manager collection or instance, based on what 'id' was given.
  local response = {}
  --Get the URL segmant
  local url_segments = self:get_url_segments()
  local collection = url_segments[1]
  local page = url_segments[2]
  local ref = url_segments[3]

  if id == "/redfish/v1/Chassis" or ref =="$ref" then
    --GET Chassis Collection
    self:get_collection(response)
  else
    if ref == "Actions" then
      -- GET requests must respond with the 'Allow' header specifying what methods are available for the given URL
      self:set_allow_header("POST")
      self:error_method_not_allowed()
    else
      --GET Chassis Instance
      self:get_instance(response)
    end

  end
  --Register the response with the handler
  self:set_response(response)
  self:output()
end

function ChassisHandler:get_collection(response)
	-- Before proceeding with the handler, we'll make sure the collection request is valid
	local collection_exists = self:parent_exists()
	self:assertTrue_404(collection_exists)

  --Maximum members count value to list in Chassis Collection output
  local maxCount = CONFIG.DEFAULT_COLLECTION_LIMIT
  --get redis db connection
  local redis = self:get_db()
  --get URL segment
  local url_segments = self:get_url_segments()
  local collection = url_segments[1]
  local page = url_segments[2]
  local ref = url_segments[3]
  local arr = {}
  self:set_scope("Redfish:" .. collection)
  --Search in Redis for Chassis, and pack the results into an array
  local odataIDs = utils.getODataIDArray(yield(redis:keys("Redfish:Chassis:*:ChassisType")), 1)
  response["Name"] = "Chassis Collection"
  if ref == "$ref" then
    local pageNo = tonumber(string.sub(page, 5))
    -- If no <page{no}> then throw 405 error. 
    if pageNo == nil then
      self:error_resource_missing_at_uri()
    else
      for index, value in pairs(odataIDs) do
        local indexValue = (pageNo - 1)*maxCount + 1
        if (#odataIDs-(maxCount*(pageNo-1))) < maxCount then
          arr = {}
          for i=indexValue, (maxCount+indexValue)-1 do
            table.insert(arr,odataIDs[i])
          end	
        else
          arr = {}
          for i=indexValue, (maxCount+indexValue)-1 do
            table.insert(arr,odataIDs[i])
          end
          response["Members@odata.nextLink"] = CONFIG.SERVICE_PREFIX .. "/"..collection .."/page"..(pageNo+1).."/$ref"
        end
      end
      response["Members@odata.count"] = #odataIDs
      response["Values"] = arr
      -- Add OEM extension properties to the response
      response = self:oem_extend(response, "query." .. self:get_oem_collection_path())
    end
  else
    for index, value in pairs(odataIDs) do
      arr = {}
      if #odataIDs>maxCount then
        for i=0, maxCount do
          table.insert(arr,odataIDs[i])
        end
        response["Members@odata.nextLink"] = CONFIG.SERVICE_PREFIX .. "/"..collection .."/page2/$ref"
      else
        arr = odataIDs
      end
      response["Members@odata.count"] = #odataIDs
      response["Members"] = arr
      -- Add OEM extension properties to the response
      response = self:oem_extend(response, "query." .. self:get_oem_collection_path())
    end
    --set the odata context and type
    self:set_context(CONSTANTS.CHASSIS_COLLECTION_CONTEXT)
    self:set_type(CONSTANTS.CHASSIS_COLLECTION_TYPE)
  end

  -- GET requests must respond with the 'Allow' header specifying what methods are available for the given URL
  self:set_allow_header("GET")
end

local allowed_resets = {"On", "ForceOff", "GracefulShutdown", "GracefulRestart", "ForceRestart"}

function ChassisHandler:get_instance(response)
  --Get the URL segment
  local url_segments = self:get_url_segments();

  local collection, id = url_segments[1], url_segments[2];
  --Set the scope
  self:set_scope("Redfish:Chassis:" .. id)
  --Get the Redis connection and create pipeline to add commands for all Chassis properties
  local redis = self:get_db()

  local pl = redis:pipeline()

  local prefix = "Redfish:Chassis:" .. id

  pl:mget({
      prefix .. ":Name",
      prefix .. ":Model",
      prefix .. ":PartNumber", 
      prefix .. ":AssetTag",
      prefix .. ":IndicatorLED",
      prefix .. ":Description",
      prefix .. ":ChassisType",
      prefix .. ":SKU",
      prefix .. ":SerialNumber",
      prefix .. ":Manufacturer",
      prefix .. ":PowerState"
    })
  pl:hmget(prefix .. ":Status", "State", "Health", "HealthRollup")
  pl:smembers(prefix .. ":ComputerSystems")
  pl:smembers(prefix .. ":ManagedBy")

  pl:get(prefix .. ":ContainedBy")
  pl:smembers(prefix .. ":Contains")

  pl:keys(prefix .. ":Power:*:*:Name")
  pl:keys(prefix .. ":Thermal:*:*:Name")
  pl:keys(prefix .. ":LogServices:*:Name")
  pl:keys(prefix .. ":Drives:*:Name")
  pl:keys(prefix .. ":NetworkAdapters:*:Name")
  -- Check that data was found in Redis, if not we throw a 404 NOT FOUND
  local db_result = yield(pl:run())
  self:assert_resource(db_result)

  local general, status, compsys, chassismanagedby, contBy, contains, power_exist, thermal_exist,
        log_exist, drives, networkadapter_exist = unpack(db_result)
  
  response["Id"] = id
  response["Name"] = general[1]
  response["Model"] = general[2]
  response["PartNumber"] = general[3]
  response["AssetTag"] = general[4]
  response["IndicatorLED"] = general[5]
  response["Description"] = general[6]
  response["ChassisType"] = general[7]
  response["SKU"] = general[8]
  response["SerialNumber"] = general[9]
  response["Manufacturer"] = general[10]

  if response["IndicatorLED"] ~= nil then
    response["IndicatorLED@Redfish.AllowableValues"] = led
  end
  response["PowerState"] = general[11]

  if status[1] or status[2] or status[3] then
    response["Status"] = {
      State = status[1],
      Health = status[2],
      HealthRollup = status[3]
    }
  end

  if #thermal_exist > 0 then
    local thermal = {}
    thermal["@odata.id"] = CONFIG.SERVICE_PREFIX .. "/Chassis/" .. id .. "/Thermal"
    response["Thermal"] = thermal
  end
  if #power_exist > 0 then
    local power = {}
    power["@odata.id"] = CONFIG.SERVICE_PREFIX .. "/Chassis/" .. id .. "/Power"
    response["Power"] = power
  end
  if #log_exist > 0 then
    local logServices = {}
    logServices["@odata.id"] = CONFIG.SERVICE_PREFIX .. "/Chassis/" .. id .. "/LogServices"
    response["LogServices"] = logServices
  end
  if #networkadapter_exist > 0 then
    local networkadapter = {}
    networkadapter["@odata.id"] = CONFIG.SERVICE_PREFIX .. "/Chassis/" .. id .. "/NetworkAdapters"
    response["NetworkAdapters"] = networkadapter
  end

  self:add_action({
      ["#Chassis.Reset"] = {
        target = CONFIG.SERVICE_PREFIX.."/"..collection.."/"..id.."/Actions/Chassis.Reset",
        ["ResetType@Redfish.AllowableValues"] = allowed_resets
      }
    })

  response["Links"] = self:oem_extend({
      ComputerSystems = utils.getODataIDArray(compsys),
      ManagedBy = utils.getODataIDArray(chassismanagedby),
      Contains = utils.getODataIDArray(contains),
      Drives = utils.getODataIDArray(drives, 1)
      },"query." .. self:get_oem_instance_link_path())
  if contBy ~= nil then
    response["Links"]["ContainedBy"] = {["@odata.id"] = utils.getODataID(contBy)}
  end

  response = self:oem_extend(response, "query." .. self:get_oem_instance_path())

  utils.remove_nils(response)
  --Set the OData context and type for the response
  local keys = _.keys(response)
  
  if #keys < 25 then
    local select_list = turbo.util.join(",", keys)
    self:set_context(CONSTANTS.CHASSIS_INSTANCE_CONTEXT .. "(" .. select_list .. ")")
  else
    self:set_context(CONSTANTS.CHASSIS_INSTANCE_CONTEXT .. "(*)")
  end

  self:set_type(CONSTANTS.CHASSIS_TYPE)

  -- GET requests must respond with the 'Allow' header specifying what methods are available for the given URL
  self:set_allow_header("GET, PATCH")

end

function ChassisHandler:patch(id)

  local response = {}
  --Get the URL segment
  local url_segments = self:get_url_segments();
  local collection, instance = url_segments[1], url_segments[2];

  --Throwing error if request is to collection
  if id == "/redfish/v1/Chassis" then
    -- Allow an OEM patch handler for system collections, if none exists, return with the normal 405 response
    self:set_header("Allow", "GET")
    self:set_status(405)

    response = self:oem_extend(response, "patch." .. self:get_oem_collection_path())

    if self:get_status() == 405 then
      self:error_method_not_allowed()
    end
  else
    -- Allow the OEM patch handlers for system instances to have the first chance to handle the request body
    response = self:oem_extend(response, "patch." .. self:get_oem_instance_path())

    if self:can_user_do("ConfigureComponents") == true then
      local redis = self:get_db()
      local successful_sets = {}
      local keys_to_watch = {}
      -- Get the request body.
      local request_data = turbo.escape.json_decode(self:get_request().body)

      self:set_scope("Redfish:" .. table.concat(url_segments, ":"))

      local pl = redis:pipeline()
      local prefix = "Redfish:" .. collection .. ":" .. instance
      local extended = {}

      --Call function to capture the null property from the request body and to frame corresponding error message
      extended = RedfishHandler:validatePatchRequest(self:get_request().body, property_access, extended)
      
      local patch_operations = {
        ["AssetTag"] = function(pipe, value)
          if type(value) ~= "string" then

            table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/AssetTag"}, {tostring(value), "AssetTag"}))

          else
            pipe:set(prefix..":AssetTag", value)
            --table.insert(successful_sets, "AssetTag")
            --table.insert(keys_to_watch, prefix..":AssetTag")
          end
          request_data.AssetTag = nil
        end,
        ["IndicatorLED"] = function(pipe, value)
          if value ~= nil and turbo.util.is_in(value,led) == nil then

            local res = ""
            for k, v in pairs(led) do
              res = res .. v .. ", "
            end

            table.insert(extended, self:create_message("Base", "PropertyValueNotInList", {"#/IndicatorLED"}, {tostring(value), "IndicatorLED"}))

          else
            pipe:set("PATCH:"..prefix..":IndicatorLED", tostring(value))
            table.insert(successful_sets, "IndicatorLED")
            table.insert(keys_to_watch, prefix..":IndicatorLED")
          end
          request_data.IndicatorLED = nil
        end
      }

      local readonly_body
      local writable_body
      local read_only = {}
      readonly_body, writable_body = utils.readonlyCheck(request_data, property_access)

      -- Add commands to pipeline as needed by referencing our 'patch_operations' table.
      if writable_body then
        for property, value in pairs(writable_body) do
          if type(value) == "table" then
            for prop2, val2 in pairs(value) do
              patch_operations[property.."."..prop2](pl, val2)
            end
          else
            patch_operations[property](pl, value)
          end
        end
      end

      -- If the user attempts to PATCH read-only properties, respond with the proper error messages.
      if readonly_body then
        for property, value in pairs(readonly_body) do
          local rProperty = {}
          if type(value) == "table" then
            for prop2, val2 in pairs(value) do
              --table.insert(extended, self:create_message("Base", "PropertyNotWritable", "#/"..property.."/"..prop2, tostring(property.."/"..prop2)))
              table.insert(read_only, property .. "." .. prop2)
            end
          else
            --table.insert(extended, self:create_message("Base", "PropertyNotWritable", "#/"..property, tostring(property)))
            table.insert(read_only, property)
          end
        end
      end
      
      --Adding read-only properties to extended table
	  if #read_only ~= 0 then
		local values = _.values(read_only)
		for k, v in pairs(values) do
			table.insert(extended, self:create_message("Base", "PropertyNotWritable", "#/" .. v, v))
		end
	  end
			
	  --Removing the read-only properties from request_data
	  for k, v in pairs(read_only) do
		request_data[v] = nil
	  end
	  
	  --Checking for unknown properties if any
	  local leftover_fields = utils.table_len(request_data)
	  if leftover_fields ~= 0 then
		local keys = _.keys(request_data)
		for k, v in pairs(keys) do
			table.insert(extended, self:create_message("Base", "PropertyUnknown", "#/" .. v, v))
		end
	  end
      
      -- Run any pending database commands.
      if #pl.pending_commands > 0 then
        
        -- doPATCH will block until it sees that the keys we are PATCHing have been changed, or receives an error response about why the PATCH failed, or until it times out
        -- doPATCH returns a table of any error messages received, and, if a timeout occurs, any keys that had yet to be modified when the timeout happened
        local patch_errors, timedout_keys, result = self:doPATCH(keys_to_watch, pl, CONFIG.PATCH_TIMEOUT)
        for _i, err in pairs(patch_errors) do
            table.insert(extended, self:create_message(err.Registry, err.MessageId, err.RelatedProperties, err.MessageArgs))
        end
        for _i, to_key in pairs(timedout_keys) do
            local property_key = to_key:split("Chassis:[^:]*:", nil, true)[2]
            local key_segments = property_key:split(":")
            local property_name = "#/" .. table.concat(key_segments, "/")
            table.insert(extended, self:create_message("SyncAgent", "PatchTimeout", property_name, {CONFIG.PATCH_TIMEOUT/1000, property_name}))
        end
        self:add_audit_log_entry(self:create_message("Security", "ResourceModified", nil, {turbo.util.join(", ", successful_sets), self:get_request().path}))
      end

      -- If we caught any errors along the way, add them to the response.
      if #extended ~= 0 then
        self:add_error_body(response,400,unpack(extended))
      else
        --Performing GET operation after PATCHing
        --self:get_instance(response)
		self:update_lastmodified(prefix, os.time())
		self:set_status(204)
      end

    else
      --InsufficientPrivilege
      self:error_insufficient_privilege()
    end
  end
  self:set_response(response)
  self:output()
end

-- ### POST request handler for Chassis Actions
function ChassisHandler:post(_chassis_id, action)
    local url = self.request.headers:get_url()
    local request_data = self:get_json()
    local response = {}
    local extended = {}
    local prefix = "Redfish:Chassis:" .. _chassis_id

    if action then
        space, action = string.match(action, "([^/^.]+)%.([^/^.]+)")
    end

    -- Handles action here
    if space == 'Chassis' and action == 'Reset' then

    if type(request_data) == "nil" then
        self:error_malformed_json()
    else
        local resettype = request_data.ResetType
      
        local redis = self:get_db()
        local pl = redis:pipeline()
        local keys_to_watch = {}
        local redis_key = "Redfish:Chassis:" .. _chassis_id .. ":PowerState"
      
        if not turbo.util.is_in(resettype, allowed_resets) then
            
            self:error_action_parameter_unknown("ResetType", resettype)
        else
            
            local redis_action_key = "Redfish:Chassis:" .. _chassis_id .. ":Actions:Reset"

            pl:set(redis_action_key, resettype)
	
            table.insert(keys_to_watch, redis_key)
        end
      
        -- Run any pending database commands.
        if #pl.pending_commands > 0 then

	        local post_errors, timedout_keys, result = self:doPOST(keys_to_watch, pl, CONFIG.PATCH_TIMEOUT)
            for _i, err in pairs(post_errors) do
	            table.insert(extended, self:create_message(err.Registry, err.MessageId, err.RelatedProperties, err.MessageArgs))
	        end
	        for _i, to_key in pairs(timedout_keys) do
	
	            table.insert(extended, self:create_message("IPMI", "Timeout")) 
	        end
        end
    end
    -- Always have the else condition similar to "default" case to respond no other actions or post operations available
    elseif self:get_request().path:find("Actions") then
        self:error_action_not_supported()
    else
        self:error_method_not_allowed()
    end

    if #extended ~= 0 then
        self:add_error_body(response,400,unpack(extended))
    else
		self:update_lastmodified(prefix, os.time())
        self:set_status(204)
    end

    self:set_response(response)
    self:output()
end

return ChassisHandler
