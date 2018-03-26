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
-- [See "turboredis.lua"](https://github.com/enotodden/turboredis)
local db_utils = require("turboredis.util")

local ThermalHandler = class("ThermalHandler", RedfishHandler)
local yield = coroutine.yield

-- Set the path names for thermal OEM extensions
local singleton_oem_path = "chassis.chassis-thermal"
ThermalHandler:set_all_oem_paths(nil, nil, singleton_oem_path)

function ThermalHandler:get(id1)

  local response = {}
  -- Get thermal instance
  self:get_thermal_entity(response)

  -- After the response is created, we register it with the handler and then output it to the client.
  self:set_response(response)

  -- GET requests must respond with the 'Allow' header specifying what methods are available for the given URL
  self:set_allow_header("GET")

  self:output()
end

function ThermalHandler:get_thermal_entity(response)
  -- Get URL segmant
  local url_segments = self:get_url_segments();
  local collection, instance, secondary_collection = 
  url_segments[1], url_segments[2], url_segments[3];
  -- Set the Scope
  self:set_scope("Redfish:"..table.concat(url_segments, ":"))

  -- Get the redis db connection
  local redis = self:get_db()
  -- Create pipeline object
  local pl = redis:pipeline()

  local exists = yield(redis:get("Redfish:Chassis:" .. instance .. ":ResourceExists"))
  if not exists then
    self:error_resource_missing_at_uri()
  end

  pl:set("Redfish:Chassis:" .. instance .. ":UpdateSensors", "update")
  self:doGET({"Redfish:Chassis:" .. instance .. ":UpdateSensorsDone"}, pl, CONFIG.PATCH_TIMEOUT)

  pl = redis:pipeline()

  -- Function to get the thermal property instance
  local get_data = function(pipe, response)
    local prefixT = "Redfish:Chassis:"..instance..":Thermal:Temperatures"
    local odataIDsT = yield(redis:keys(prefixT.."*:Name"))
    local tempData = {}
    -- If Thermal:Temperature exist in redis, create pipeline cmd for all the Temperture properties
    if #odataIDsT > 0 then
      for index,value in ipairs(odataIDsT) do
        local i = string.sub(value, (string.len(prefixT..":"))+1, -(string.len(":Name")+1))

        local tempPrefix = prefixT..":"..i

        pipe:mget({
            tempPrefix .. ":Name",
            tempPrefix .. ":SensorNumber",  --int
            tempPrefix .. ":ReadingCelsius",  --
            tempPrefix .. ":UpperThresholdNonCritical",
            tempPrefix .. ":UpperThresholdCritical",
            tempPrefix .. ":UpperThresholdFatal",
            tempPrefix .. ":LowerThresholdNonCritical",
            tempPrefix .. ":LowerThresholdCritical",
            tempPrefix .. ":LowerThresholdFatal",
            tempPrefix .. ":MinReadingRange",
            tempPrefix .. ":MaxReadingRange",
            tempPrefix .. ":PhysicalContext",
          })
        pipe:hmget(tempPrefix .. ":Status", "State","Health")
        pipe:smembers(tempPrefix..":RelatedItem") 
      end
    end

    local prefixF = "Redfish:Chassis:"..instance..":Thermal:Fans"
    local odataIDsF = yield(redis:keys(prefixF.."*:FanName"))
    local fansData = {}
    -- If Thermal:Fan exist in redis, create pipeline cmd for all the Fans properties
    if #odataIDsF > 0 then
      for index,value in ipairs(odataIDsF) do
        local i = string.sub(value, (string.len(prefixF..":"))+1, -(string.len(":FanName")+1))

        local fanPrefix = prefixF..":"..i

        pipe:mget({
            fanPrefix .. ":FanName",
            fanPrefix .. ":PhysicalContext",
            fanPrefix .. ":ReadingRPM",
            fanPrefix .. ":UpperThresholdNonCritical",
            fanPrefix .. ":UpperThresholdCritical",
            fanPrefix .. ":UpperThresholdFatal",
            fanPrefix .. ":LowerThresholdNonCritical",
            fanPrefix .. ":LowerThresholdCritical",
            fanPrefix .. ":LowerThresholdFatal",
            fanPrefix .. ":MinReadingRange",
            fanPrefix .. ":MaxReadingRange",
          })
        pipe:hmget(fanPrefix .. ":Status", "State","Health")
        pipe:smembers(fanPrefix..":RelatedItem")
        pipe:smembers(fanPrefix..":Redundancy")
      end
    end

    local prefixR = "Redfish:Chassis:"..instance..":Thermal:Redundancy"
    local odataIDsR = yield(redis:keys(prefixR.."*:Name"))
    local redundancyData = {}
    -- If Thermal:Redundancy exist in redis, create pipeline cmd for all the redundancy properties
    if #odataIDsR > 0 then
      for index,value in ipairs(odataIDsR) do
        local i = string.sub(value, (string.len(prefixR..":"))+1, -(string.len(":Name")+1))

        local redundancyPrefix = prefixR..":"..i
        pipe:mget({
            redundancyPrefix .. ":Name",
            redundancyPrefix .. ":Mode",
            redundancyPrefix .. ":MaxNumSupported",
            redundancyPrefix .. ":MinNumNeeded",
          })
        pipe:hmget(redundancyPrefix .. ":Status", "State","Health")
        pipe:smembers(redundancyPrefix..":RedundancySet") 
      end
    end
    -- Run the pipeline commands
    local results
    
    if #pipe.pending_commands > 0 then
      results = yield(pipe:run())
    end

    self:assert_resource(results)
    
    response["Name"] = "Thermal"
    response["Id"] = "Thermal"

    local j = 0
    -- If temperature properties exist then fill the properties in response table
    if #odataIDsT > 0 then
      for index,value in ipairs(odataIDsT) do
        local data = {}
        local i = string.sub(value, (string.len(prefixT..":"))+1, -(string.len(":Name")+1))
        local general, status, relateditems = results[j+1], results[j+2], results[j+3]
        data["@odata.id"] = CONFIG.SERVICE_PREFIX .. "/Chassis/" .. instance .. "/Thermal#/Temperatures/"..i
        data["Name"] = general[1]
        data["SensorNumber"] = tonumber(general[2])
        data["ReadingCelsius"] = tonumber(general[3])
        data["UpperThresholdNonCritical"] = tonumber(general[4])
        data["UpperThresholdCritical"] = tonumber(general[5])
        data["UpperThresholdFatal"] = tonumber(general[6])

        data["LowerThresholdNonCritical"] = tonumber(general[7])
        data["LowerThresholdCritical"] = tonumber(general[8])
        data["LowerThresholdFatal"] = tonumber(general[9])

        data["MinReadingRangeTemp"] = tonumber(general[10])
        data["MaxReadingRangeTemp"] = tonumber(general[11])
        data["PhysicalContext"] = general[12]

        data["Status"] = {
          State = status[1],
          Health = status[2],
        }

        data["RelatedItem"] = utils.getODataIDArray(relateditems)
        j = j+3
        table.insert(tempData, data)
        response["Temperatures"] = tempData
      end
    end
    -- If Fans properties exist then fill the properties in response table
    if #odataIDsF > 0 then
      for index,value in ipairs(odataIDsF) do
        local data = {}
        local i = string.sub(value, (string.len(prefixF..":"))+1, -(string.len(":FanName")+1))
        local general, status, relateditems, redundancy = results[j+1], results[j+2], results[j+3], results[j+4]
        data["@odata.id"] = CONFIG.SERVICE_PREFIX .. "/Chassis/" .. instance .. "/Thermal#/Fans/"..i
        data["MemberId"] = tostring(i)
        data["FanName"] = general[1]
        data["PhysicalContext"] = general[2]
        data["Reading"] = tonumber(general[3])

        data["UpperThresholdNonCritical"] = tonumber(general[4])
        data["UpperThresholdCritical"] = tonumber(general[5])
        data["UpperThresholdFatal"] = tonumber(general[6])

        data["LowerThresholdNonCritical"] = tonumber(general[7])
        data["LowerThresholdCritical"] = tonumber(general[8])
        data["LowerThresholdFatal"] = tonumber(general[9])

        data["MinReadingRange"] = tonumber(general[10])
        data["MaxReadingRange"] = tonumber(general[11])

        data["Status"] = {
          State = status[1],
          Health = status[2],
        }
        data["RelatedItem"] = utils.getODataIDArray(relateditems)
        data["Redundancy"] = utils.getODataIDArray(redundancy)

        table.insert(fansData, data)
        response["Fans"] = fansData
        j = j+4
      end
    end
    -- If Redundancy properties exist then fill the properties in response table
    if #odataIDsR > 0 then
      for index, value in ipairs(odataIDsR) do
        local data = {}
        local general, status, redundancyset = results[j+1], results[j+2], results[j+3]
        local i = string.sub(value, (string.len(prefixR..":"))+1, -(string.len(":Name")+1))
        data["@odata.id"] = CONFIG.SERVICE_PREFIX .. "/Chassis/" .. instance .. "/Thermal#/Redundancy/"..i
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
      end
    end
    pipe:clear()
  end

  get_data(pl,response)
  -- Add OEM extension properties to the response
	response = self:oem_extend(response, "query." .. self:get_oem_singleton_path())
  -- removes nill value fields from the response
  utils.remove_nils(response)
  -- Set the OData context and type for the response
  local keys = _.keys(response)
  if #keys < 7 then
    local select_list = turbo.util.join(",", keys)
    self:set_context(CONSTANTS.THERMAL_INSTANCE_CONTEXT .. "(" .. select_list .. ")")
  else
    self:set_context(CONSTANTS.THERMAL_INSTANCE_CONTEXT .. "(*)")
  end
  self:set_type(CONSTANTS.THERMAL_TYPE)
end

return ThermalHandler


