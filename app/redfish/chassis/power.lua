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
-- [See "turboredis.lua"](https://github.com/enotodden/turboredis)
local db_utils = require("turboredis.util")

local PowerHandler = class("PowerHandler", RedfishHandler)
local yield = coroutine.yield
-- The 'property_access' table specifies read/write permission for all properties.
local power_control_property_access = require("property-access.Power")["powerControl"]
local power_property_access = require("property-access.Power")["Power"]
local voltage_property_access = require("property-access.Power")["Voltage"]
local power_supply_property_access = require("property-access.Power")["PowerSupply"]

-- Set the path names for power OEM extensions
local singleton_oem_path = "chassis.chassis-power"
PowerHandler:set_all_oem_paths(nil, nil, singleton_oem_path)

function PowerHandler:get(id)

  local response = {}
  self:get_power_entity(response)
  -- After the response is created, we register it with the handler and then output it to the client.
  self:set_response(response)

  -- GET requests must respond with the 'Allow' header specifying what methods are available for the given URL
  self:set_allow_header("GET, PATCH")
  
  self:output()
end

function PowerHandler:get_power_entity(response)
  --get url segment
  local url_segments = self:get_url_segments();
  local collection, instance, secondary_collection = 
  url_segments[1], url_segments[2], url_segments[3];
  --set the scope
  self:set_scope("Redfish:"..table.concat(url_segments, ":"))

  -- Get the redis db connection
  local redis = self:get_db()
  -- Create a pipeline object
  local pl = redis:pipeline()

  local exists = yield(redis:get("Redfish:Chassis:" .. instance .. ":ResourceExists"))
  if not exists then
    self:error_resource_missing_at_uri()
  end

  pl:set("Redfish:Chassis:" .. instance .. ":UpdateSensors", "update")
  self:doGET({"Redfish:Chassis:" .. instance .. ":UpdateSensorsDone"}, pl, CONFIG.PATCH_TIMEOUT)

  pl = redis:pipeline()

  --Voltages Collectionz
  local voltagePrefix = "Redfish:Chassis:"..instance..":Power:Voltages"
  local vodataIDs = yield(redis:keys(voltagePrefix.."*:Name"))
  local voltageData = {}
  --loop for Voltages array
  if #vodataIDs > 0 then
    for i,v in ipairs(vodataIDs) do 
      local vindex = string.sub(v, (string.len(voltagePrefix..":"))+1, -(string.len(":Name")+1))
      --adding voltage properties
      local prefix = "Redfish:Chassis:"..instance..":Power:Voltages:"..vindex
      pl:mget({
          prefix .. ":Name",
          prefix .. ":SensorNumber",
          prefix .. ":ReadingVolts",
          prefix .. ":UpperThresholdNonCritical",
          prefix .. ":UpperThresholdCritical",
          prefix .. ":LowerThresholdNonCritical",
          prefix .. ":LowerThresholdCritical",
          prefix .. ":MinReadingRange",
          prefix .. ":MaxReadingRange",
          prefix .. ":PhysicalContext",
        })
      pl:hmget(prefix .. ":Status", "State","Health")
      pl:smembers(prefix..":RelatedItem") 
    end
  end
  --Redundancy Collection
  local redundancyPrefix = "Redfish:Chassis:"..instance..":Power:Redundancy"
  local rdodataIDs = yield(redis:keys(redundancyPrefix.."*:Name"))
  local redundancyData = {}
  if #rdodataIDs > 0 then
    for i,v in ipairs(rdodataIDs) do 
      local rindex = string.sub(v, (string.len(redundancyPrefix..":"))+1, -(string.len(":Name")+1))
      --adding redundancy properties
      local prefix = "Redfish:Chassis:"..instance..":Power:Redundancy:"..rindex

      pl:mget({
          prefix .. ":Name",
          prefix .. ":Mode",
          prefix .. ":MaxNumSupported",
          prefix .. ":MinNumNeeded",
        })
      pl:hmget(prefix .. ":Status", "State","Health")
      pl:smembers(prefix..":RedundancySet") 
    end
  end
  --PowerControl Collection
  local pcPrefix = "Redfish:Chassis:"..instance..":Power:PowerControl"
  local pcodataIDs= yield(redis:keys(pcPrefix.."*:Name"))
  local pcData = {}
  --loop for Power Control array
  if #pcodataIDs > 0 then
    for i,v in ipairs(pcodataIDs) do 
      local pcindex = string.sub(v, (string.len(pcPrefix..":"))+1, -(string.len(":Name")+1))
      --adding voltage properties
      local prefix = "Redfish:Chassis:"..instance..":Power:PowerControl:"..pcindex

      pl:mget({
          prefix .. ":Name",
          prefix .. ":PowerConsumedWatts",
          prefix .. ":PowerRequestedWatts",
          prefix .. ":PowerAvailableWatts",
          prefix .. ":PowerCapacityWatts",
          prefix .. ":PowerAllocatedWatts",
        })
      pl:hmget(prefix .. ":PowerMetrics", "IntervalInMinutes","MinConsumedWatts","MaxConsumedWatts","AverageConsumedWatts")
      pl:hmget(prefix .. ":PowerLimit", "LimitInWatts","LimitException","CorrectionInMs")
      pl:hmget(prefix .. ":Status", "State","Health")
      pl:smembers(prefix..":RelatedItem")

    end
  end
  --Power Supplies Collection
  local psPrefix = "Redfish:Chassis:"..instance..":Power:PowerSupplies"
  local psodataIDs = yield(redis:keys(psPrefix.."*:Name"))
  local psData = {}
  --loop for power supply array
  if #psodataIDs > 0 then
    for i,v in ipairs(psodataIDs) do 
      local psindex = string.sub(v, (string.len(psPrefix..":"))+1, -(string.len(":Name")+1))
      --adding power supply properties
      local prefix = "Redfish:Chassis:"..instance..":Power:PowerSupplies:"..psindex

      pl:mget({
          prefix .. ":Name",
          prefix .. ":PowerSupplyType",
          prefix .. ":LineInputVoltageType",
          prefix .. ":LineInputVoltage",
          prefix .. ":PowerCapacityWatts",
          prefix .. ":LastPowerOutputWatts",
          prefix .. ":Model",
          prefix .. ":FirmwareVersion",
          prefix .. ":SerialNumber",
          prefix .. ":PartNumber",
          prefix .. ":SparePartNumber",
        })
      pl:hmget(prefix .. ":Status", "State","Health")
      pl:smembers(prefix..":RelatedItem") 
      pl:smembers(prefix..":Redundancy") 
    end
  end
  --local startTime = os.time()
  --turbo.log.debug("start time is "..startTime)
  local results
  if #pl.pending_commands > 0 then
    results = yield(pl:run())
  end
  self:assert_resource(results)
  --local endTime = os.time()
  --turbo.log.debug("end time is "..endTime)
  --turbo.log.debug("time taken by run is "..(endTime-startTime))

  response["Name"] = "Power"
  response["Id"] = "Power"

  local j = 0
  if #vodataIDs > 0 then
    for i,v in ipairs(vodataIDs) do 
      local vindex = string.sub(v, (string.len(voltagePrefix..":"))+1, -(string.len(":Name")+1))
      local data = {}
      local general, status, relateditems = results[j+1], results[j+2], results[j+3]
      data["@odata.id"] = CONFIG.SERVICE_PREFIX .. "/Chassis/" .. instance .. "/Power#/Voltages/" .. vindex
      data["Name"] = general[1]
      data["SensorNumber"] = tonumber(general[2])
      data["ReadingVolts"] = tonumber(general[3])
      data["UpperThresholdNonCritical"] = tonumber(general[4])
      data["UpperThresholdCritical"] = tonumber(general[5])
      data["LowerThresholdNonCritical"] = tonumber(general[6])
      data["LowerThresholdCritical"] = tonumber(general[7])
      data["MinReadingRange"] = tonumber(general[8])
      data["MaxReadingRange"] = tonumber(general[9])

      data["Status"] = {
        State = status[1],
        Health = status[2],
      }

      data["RelatedItem"] = utils.getODataIDArray(relateditems)

      j = j+3

      table.insert(voltageData, data)
      response["Voltages"] = voltageData
      --pl:clear()
    end
  end
  if #rdodataIDs > 0 then
    for i,v in ipairs(rdodataIDs) do 
      local rindex = string.sub(v, (string.len(redundancyPrefix..":"))+1, -(string.len(":Name")+1))
      local data = {}
      data["@odata.id"] = CONFIG.SERVICE_PREFIX .. "/Chassis/" .. instance .. "/Power#/Redundancy/" .. rindex

      local general, status, redundancyset = results[j+1], results[j+2], results[j+3]

      data["Name"] = general[1]
      data["Mode"] = general[2]
      data["MaxNumSupported"] = tonumber(general[3])
      data["MinNumNeeded"] = tonumber(general[4])

      data["Status"] = {
        State = status[1],
        Health = status[2],
      }

      data["RedundancySet"] = utils.getODataIDArray(redundancyset)

      table.insert(redundancyData, data)
      response["Redundancy"] = redundancyData
      j=j+3
    end
  end
  --loop for Power Control array
  if #pcodataIDs > 0 then
    for i,v in ipairs(pcodataIDs) do 
      local pcindex = string.sub(v, (string.len(pcPrefix..":"))+1, -(string.len(":Name")+1))
      local data = {}
      data["@odata.id"] = CONFIG.SERVICE_PREFIX .. "/Chassis/" .. instance .. "/Power#/PowerControl/" .. pcindex

      local general, pmetrics, plimit, status, relateditems = results[j+1], results[j+2], results[j+3],results[j+4],results[j+5]

      data["Name"] = general[1]
      data["PowerConsumedWatts"] = tonumber(general[2])
      data["PowerRequestedWatts"] = tonumber(general[3])
      data["PowerAvailableWatts"] = tonumber(general[4])
      data["PowerCapacityWatts"] = tonumber(general[5])
      data["PowerAllocatedWatts"] = tonumber(general[6])

      data["Status"] = {
        State = status[1],
        Health = status[2],
      }
      if instance ~= "Enc1" then
        data["PowerMetrics"] = {
          IntervalInMin = tonumber(pmetrics[1]),
          MinConsumedWatts = tonumber(pmetrics[2]),
          MaxConsumedWatts = tonumber(pmetrics[3]),
          AverageConsumedWatts = tonumber(pmetrics[4]),
        }
      end
      data["PowerLimit"] = {
        LimitInWatts = tonumber(plimit[1]),
        LimitException = plimit[2],
        CorrectionInMs = tonumber(plimit[3]),
      }
      data["RelatedItem"] = utils.getODataIDArray(relateditems)

      table.insert(pcData, data)
      response["PowerControl"] = pcData
      j=j+5
    end
  end
  --loop for power supply array
  if #psodataIDs > 0 then
    for i,v in ipairs(psodataIDs) do 
      local psindex = string.sub(v, (string.len(psPrefix..":"))+1, -(string.len(":Name")+1))
      local data = {}
      data["@odata.id"] = CONFIG.SERVICE_PREFIX .. "/Chassis/" .. instance .. "/Power#/PowerSupplies/" .. psindex

      local general, status, relateditems, redundancy = results[j+1], results[j+2], results[j+3],results[j+4]

      data["Name"] = general[1]
      data["PowerSupplyType"] = general[2]
      data["LineInputVoltageType"] = "ACMidLine"
      data["LineInputVoltage"] = tonumber(general[4])
      data["PowerCapacityWatts"] = tonumber(general[5])
      data["LastPowerOutputWatts"] = tonumber(general[6])
      data["Model"] = general[7]
      data["FirmwareVersion"] = general[8]
      data["SerialNumber"] = general[9]
      data["PartNumber"] = general[10]
      data["SparePartNumber"] = general[11]

      data["Status"] = {
        State = status[1],
        Health = status[2],
      }

      data["RelatedItem"] = utils.getODataIDArray(relateditems)
      data["Redundancy"] = utils.getODataIDArray(redundancy)

      table.insert(psData, data)
      response["PowerSupplies"] = psData
      j=j+4
    end
  end
  pl:clear()
  -- Add OEM extension properties to the response
  response = self:oem_extend(response, "query." .. self:get_oem_singleton_path())
  -- removes nill value fields from the response
  utils.remove_nils(response)
  -- Set the OData context and type for the response
  local keys = _.keys(response)
  if #keys < 7 then
    local select_list = turbo.util.join(",", keys)
    self:set_context(CONSTANTS.POWER_INSTANCE_CONTEXT .. "(" .. select_list .. ")")
  else
    self:set_context(CONSTANTS.POWER_INSTANCE_CONTEXT .. "(*)")
  end
  self:set_type(CONSTANTS.POWER_TYPE)
end

-- ### PATCH request handler for Chassis/*/Power
function PowerHandler:patch(id)

  local response = {}

  if id == nil then
    -- When an HTTP method is rejected with status code 405, we must set an Allow header that lists valid HTTP methods for the URI
    self:set_header("Allow", "GET")
    -- No PATCH for collections
    self:error_method_not_allowed()
  else
    -- Allow the OEM patch handlers for system instances to have the first chance to handle the request body
    response = self:oem_extend(response, "patch." .. self:get_oem_singleton_path())

    if self:can_user_do("ConfigureManager") == true then
      local redis = self:get_db()
      local _exists = yield(redis:exists("Redfish:Chassis:"..id..":ChassisType"))
      if _exists == 1 then
        self:patch_instance(response)
        self:get_power_entity(response)
        -- set @odata.context explicitely
        response["@odata.context"] = CONFIG.SERVICE_PREFIX .. "/$metadata" .. self.current_context
        -- set @odata.id explicitely
        response["@odata.id"] = self.request.headers:get_url()
      else
        self:error_resource_missing_at_uri()
      end
    else
      --Throw an error if the user is not authorized.
      self:error_insufficient_privilege()
    end
  end
  -- After the response is created, we register it with the handler and then output it to the client.
  self:set_response(response)
  self:output()
end

function PowerHandler:patch_instance(response)
  --Get the Redis connection and create pipeline connection instance
  local redis = self:get_db()
  local pl = redis:pipeline()
  --Get the URL segment
  local url_segments = self:get_url_segments();
  local collection, instance = url_segments[1], url_segments[2];

  -- Get the request body.
  local request_data = turbo.escape.json_decode(self:get_request().body)
  local pc_req_data = request_data["PowerControl"]
  local ps_req_data = request_data["PowerSupplies"]
  local voltage_req_data = request_data["Voltages"]
  -- Setting the scope
  self:set_scope("Redfish:" .. table.concat(url_segments, ":"))

  local prefix = "Redfish:Chassis:"..instance..":Power:PowerControl:"

  local extended = {}
  local keys_to_watch = {}
  local successful_sets = {}
  
  local powerlimitexception = {"NoAction", "HardPowerOff", "LogEventOnly", "Oem"}

  function patchData(req, propertyAccess)

    local perform_patch_operation = {
      ["PowerLimit"] = function(pipe, value, id) 

        local postPrefix = prefix..id..":PowerLimit" 
		
        if not type(value.LimitInWatts) == "number" then
          table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/PowerLimit/LimitInWatts"}, {tostring(value.LimitInWatts), "PowerLimit/LimitInWatts"}))
        else
          if value.LimitInWatts ~= nil then
            pipe:hset("PATCH:"..postPrefix, "LimitInWatts", tonumber(value.LimitInWatts))
            table.insert(successful_sets, "LimitInWatts")
            table.insert(keys_to_watch, postPrefix)
          end
        end

        if not type(value.CorrectionInMs) == "number" then
          table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/PowerLimit/CorrectionInMs"}, {tostring(value.CorrectionInMs), "PowerLimit/CorrectionInMs"}))
        else
          if value.CorrectionInMs ~= nil then
            pipe:hset("PATCH:"..postPrefix, "CorrectionInMs", tonumber(value.CorrectionInMs))
            table.insert(successful_sets, "CorrectionInMs")
            table.insert(keys_to_watch, postPrefix)
          end
        end

        if value.LimitException ~= nil and turbo.util.is_in(value.LimitException,powerlimitexception) == nil then
          table.insert(extended, self:create_message("Base", "PropertyValueNotInList", {"#/PowerLimit/LimitException"}, {value.LimitException, "LimitException"}))
        else
          if value.LimitException ~= nil then
            pipe:hset("PATCH:"..postPrefix, "LimitException", tostring(value.LimitException))
            table.insert(successful_sets, "LimitException")
            table.insert(keys_to_watch, postPrefix)
          end
          
        end
        
      end
    }

    local readonly_body
    local writable_body
    local t_readonly_body = {}
    local t_writable_body = {}

    for k,v in pairs(req) do
      readonly_body, writable_body = utils.readonlyCheck(v, propertyAccess)
      t_readonly_body[k] = readonly_body
      t_writable_body[k] = writable_body
    end

    local patch_operations = function(writablePropertyTable, odataId) 
      local id = utils.split(odataId,"/")
      for property,value in pairs(writablePropertyTable) do
        if property ~= "@odata.id" then
          perform_patch_operation[property](pl, value, id[#id])
        end
      end
    end

    if t_writable_body then
      for k,v in pairs(t_writable_body) do
        if type(v) == "table" then
          if v["@odata.id"] ~= nil then
            patch_operations(v,v["@odata.id"])
          else
            --Throw appropriate error
          end
        end
      end
    end

    -- If the user attempts to PATCH read-only properties, respond with the proper error messages.
    if t_readonly_body then
      for index,readOnlyBody in pairs(t_readonly_body) do
        for property, value in pairs(readOnlyBody) do
          local rProperty = {}
          if type(value) == "table" then
            for prop2, val2 in pairs(value) do
              table.insert(extended, self:create_message("Base", "PropertyNotWritable", "#/"..property.."/"..prop2, tostring(property.."/"..prop2)))
            end
          else
            table.insert(extended, self:create_message("Base", "PropertyNotWritable", "#/"..property, tostring(property)))
          end
        end
      end
    end

  end

-- Get the PowerControl Collection
  local pcPrefix = "Redfish:Chassis:"..instance..":Power:PowerControl"
  local pcodataIDs= yield(redis:keys(pcPrefix.."*:Name"))
  local pcData = {}

  local response_pc = {}
  local j = 0
  if #pcodataIDs > 0 then
    for i,v in ipairs(pcodataIDs) do 
      local pcindex = string.sub(v, (string.len(pcPrefix..":"))+1, -(string.len(":Name")+1))
      local data = {}
      data["@odata.id"] = CONFIG.SERVICE_PREFIX .. "/Chassis/" .. instance .. "/Power#/PowerControl/" .. pcindex
      table.insert(pcData, data)
      response_pc["PowerControl"] = pcData
    end
  end

  local update_req = function(table_index)
    -- If the requested index is not there in redis server, user is trying to update invalid data
    if type(response_pc["PowerControl"]) == "nil" or type(response_pc["PowerControl"][table_index]) == "nil" then
      --remove invalid data from request object
      pc_req_data[table_index] = nil
      -- return error missing at resource
      table.insert(extended, self:create_message("Base", "ResourceMissingAtURI", nil, "/redfish/v1/Chassis/"..instance.."/Power"))
    else
      -- Add @odata.id property in the request object 
      pc_req_data[table_index]["@odata.id"] = response_pc["PowerControl"][table_index]["@odata.id"]
    end
  end

-- Get the position of the emty table from the request body to get the postion of the array item to be updated.
  local x = 0
  if type(pc_req_data) ~= "nil" then
    for i,v in pairs(pc_req_data) do
      if type(v) == "table" then
        --Get the index of the empty table from the request object
        if next (v) == nil then
          local _index = i
          x = _index
        else
          x = x + 1
          -- Update the request object with @odata.id property
          update_req(x)
        end
      end
    end
  end

  if type(pc_req_data) == "table" then
    patchData(pc_req_data, power_control_property_access)
  end
  if type(ps_req_data) == "table" then
    patchData(ps_req_data, power_supply_property_access)
  end
  if type(voltage_req_data) == "table" then
    patchData(voltage_req_data, voltage_property_access)
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
      local property_key = to_key:split("PowerControl:[^:]*:", nil, true)[2]
      local key_segments = property_key:split(":")
      local property_name = "#/" .. table.concat(key_segments, "/")
      table.insert(extended, self:create_message("SyncAgent", "PatchTimeout", property_name, {CONFIG.PATCH_TIMEOUT/1000, property_name}))
    end
    self:add_audit_log_entry(self:create_message("Security", "ResourceModified", nil, {turbo.util.join(", ", successful_sets), self:get_request().path}))
  end
  -- If we caught any errors along the way, add them to the response.
  if #extended ~= 0 then
    self:add_error_body(response,400,unpack(extended))
  end

end

return PowerHandler