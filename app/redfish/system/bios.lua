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

local turbo = require("turbo")
local RedfishHandler = require("redfish-handler")
local CONSTANTS = require("constants")
local CONFIG = require("config")
local utils = require("utils")
local _ = require("underscore")
local posix = require('posix')

local BiosHandler = class("BiosHandler", RedfishHandler)

-- This function helps with handling the dependencies
-- function BiosHandler:evaluate_dependency_condition(left_side, condition, right_side)
-- 	if condition == "EQU" then
-- 		return left_side == right_side
-- 	elseif condition == "NEQ" then
-- 		return left_side ~= right_side
-- 	elseif condition == "GTR" then
-- 		return left_side > right_side
-- 	elseif condition == "GEQ" then
-- 		return left_side >= right_side
-- 	elseif condition == "LSS" then
-- 		return left_side < right_side
-- 	elseif condition == "LEQ" then
-- 		return left_side <= right_side
-- 	end
-- end

local bios_reg = nil

local function read_bios_reg(reg_file_name)                                                                                                   
    local reg_file = io.open(CONFIG.BIOS_CONF_PATH .. reg_file_name .. ".json_stripped", "r")
    if reg_file ~= nil then
            -- Verifying that the contents of the attribute registry file associated with the BIOS settings is valid JSON
            local success
            success, bios_reg = pcall(turbo.escape.json_decode, reg_file:read("*all"))
            reg_file:close()
    end                   
end  

-- GET BIOS
function BiosHandler:get(id, sd)
	local url_segments = self:get_url_segments()
	local collection, instance, inner_instance, settings = url_segments[1], url_segments[2], url_segments[3], url_segments[4]
	local response = {}

	if sd == "SD" then
		-- Getting future BIOS settings
		self:get_future_settings(response)
		self:set_context(CONSTANTS.BIOS_INSTANCE_CONTEXT)
		self:set_allow_header("GET, PUT, PATCH, POST")
	elseif sd == nil then
		-- Getting current BIOS settings
		self:get_current_settings(response)
		self:add_action({
			["#Bios.ResetBios"] = {
				target = CONFIG.SERVICE_PREFIX..'/'..collection..'/'..instance..'/'..inner_instance..'/Actions/Bios.ResetBios',
				["ResetType@Redfish.AllowableValues"] = {"Reset"}
			},
			["#Bios.ChangePassword"] = {
				target = CONFIG.SERVICE_PREFIX..'/'..collection..'/'..instance..'/'..inner_instance..'/Actions/Bios.ChangePassword'
			}
		})

		response["@Redfish.Settings"] = {
			["@odata.type"] = CONSTANTS.SETTINGS_TYPE,
			["SettingsObject"] = {
		    	["@odata.id"] = CONFIG.SERVICE_PREFIX..'/'..collection..'/'..instance..'/'..inner_instance..'/SD'
		    }
		}

		self:set_context(CONSTANTS.BIOS_INSTANCE_CONTEXT)
		self:set_allow_header("GET")
	else
		self:error_resource_missing_at_uri()
	end

	self:set_type(CONSTANTS.BIOS_TYPE)
	self:set_response(response)
	self:output()
end

-- Helper function to read the given BIOS settings file
function BiosHandler:get_file(response, file_name)
	local data_file = io.open(file_name,"r")
	-- Checking if file exists
	if data_file ~= nil then
		-- Reading file and checking if file is valid JSON
		local success, data_file_contents = pcall(turbo.escape.json_decode, data_file:read("*all"))
		data_file:close()

		-- Throwing error if file is not valid JSON
		if not success then
			self:error_resource_at_uri_in_unknown_format()
        end

        -- Adding file contents to the response
		_.extend(response, data_file_contents)

		if response and response.Attributes and _.is_empty(response.Attributes) then
			response.Attributes = nil
		end
	else
		-- Throwing error if file does not exist
		self:error_resource_missing_at_uri()
	end
end

function BiosHandler:get_current_settings(response)
	self:get_file(response, CONFIG.BIOS_CURRENT_PATH)
	response["Id"] = "Bios"
	response["Name"] = "Current BIOS Settings"
	response["Description"] = "Current BIOS Settings"
	response["@odata.type"] = nil
	response["@odata.context"] = nil
	response["@odata.id"] = nil
	response["@odata.etag"] = nil
end

function BiosHandler:get_future_settings(response)
	self:get_file(response, CONFIG.BIOS_FUTURE_PATH)
	response["Id"] = "SD"
	response["Name"] = "Future BIOS Settings"
	response["Description"] = "Future BIOS Settings"
	response["@odata.type"] = nil
	response["@odata.context"] = nil
	response["@odata.id"] = nil
	response["@odata.etag"] = nil
end

-- PUT BIOS future settings
function BiosHandler:put(id, sd)
	self:handle_write_operation(id, sd)
end

-- PATCH BIOS future settings
function BiosHandler:patch(id, sd)
	self:handle_write_operation(id, sd)
end

-- POST BIOS future settings
function BiosHandler:post(id, sd)
	self:handle_write_operation(id, sd)
end

function BiosHandler:handle_write_operation(id, sd)
	if sd == nil then
		-- When an HTTP method is rejected with status code 405, we must set an Allow header that lists valid HTTP methods for the URI
	    self:set_header("Allow", "GET")
		-- Normal instance shouldn't be PATCHed directly, use settings object
	    self:error_method_not_allowed()
	end

    local prefix = "Redfish:Systems:Self:" .. id .. ":" ..sd
	if self:can_user_do("ConfigureComponents") == true then
		-- Checking that the request is valid JSON
		local success, request_data = pcall(turbo.escape.json_decode, self:get_request().body)

		-- Throwing error if the request is not valid JSON
		if not success or not request_data or not request_data.Attributes then
			self:error_unrecognized_request_body()
		end

		local extended = {}

		-- Opening current BIOS settings file 
		local current_file = io.open(CONFIG.BIOS_CURRENT_PATH,"r")
		local current_data = {}
		if current_file ~= nil then
			-- Verifying that the contents of the current BIOS settings file is valid JSON
			success, current_data = pcall(turbo.escape.json_decode, current_file:read("*all"))
			current_file:close()

			-- Throwing an error if the current BIOS file is not valid JSON
			if not success then
				self:error_resource_at_uri_in_unknown_format()
	        end
		else
			-- Throwing an error if the current BIOS settings file cannot be read
			self:error_resource_missing_at_uri()
		end

		-- Opening future BIOS settings file 
		local future_file = io.open(CONFIG.BIOS_FUTURE_PATH,"r")
		local future_data = {}
		if future_file ~= nil then
			-- Verifying that the contents of the future BIOS settings file is valid JSON
			success, future_data = pcall(turbo.escape.json_decode, future_file:read("*all"))
			future_file:close()

			-- Throwing an error if the future BIOS file is not valid JSON
			if not success then
				self:error_resource_at_uri_in_unknown_format()
	        end
		end

		local overwrite_resource = self:get_request().method == "POST" or self:get_request().method == "PUT"

		if not future_data["Attributes"] or overwrite_resource then
			future_data["Attributes"] = {}
		end

		if not bios_reg then
			read_bios_reg(current_data.AttributeRegistry)
		end

		if bios_reg then
			-- Throwing an error if the contents of the attribute registry file associated with the BIOS settings is not valid JSON
			if not success then
				self:error_resource_at_uri_in_unknown_format()
	        end

	        -- Looping through attributes in attribute registry file
			for attr, attr_value in pairs(request_data.Attributes) do
				-- Checking if the attribute is part of the request
				if bios_reg[attr] ~= nil then
					if bios_reg[attr].ReadOnly then
						self:error_property_not_writable(attr, extended)
					else
						-- Handling an enumeration attribute
						if bios_reg[attr].Type == "Enumeration" then
							local valid = false
							local temp = attr_value

							if type(temp) ~= "string" then
								self:error_property_value_type(attr, tostring(attr_value), extended)
							else
								-- Verifying that the value from the request is one of the values specified in the attribute registry
								for val_i, val in pairs(bios_reg[attr].Value) do
									if temp == val then
										attr_value = temp
										valid = true
										break
									end
								end

								-- Throwing error if the value from the request is not one of the values specified in the attribute registry
								if not valid then
									self:error_property_value_not_in_list(attr, tostring(attr_value), extended)
								end
							end
						-- Handling an string attribute
						elseif bios_reg[attr].Type == "String" then
							local temp = attr_value
							-- Checking if string meets any requirements specified in the attribute registry
							if type(temp) ~= "string" then
								self:error_property_value_type(attr, tostring(attr_value), extended)
							elseif (bios_reg[attr].MaxLength and temp:len() > tonumber(bios_reg[attr].MaxLength)) or (bios_reg[attr].MinLength and temp:len() < tonumber(bios_reg[attr].MinLength)) or (bios_reg[attr].ValueExpression and temp:match(bios_reg[attr].ValueExpression) ~= temp) then
								self:error_property_value_format(attr, tostring(attr_value), extended)
							end
						-- Handling an integer attribute
						elseif bios_reg[attr].Type == "Integer" then
							local temp = attr_value
							local attr_str = tostring(attr_value)

							-- Verifying the data in the request is a valid integer
							if type(temp) ~= "number" then
								self:error_property_value_type(attr, attr_str, extended)
							-- Checking if string meets any requirements specified in the attribute registry
							elseif (bios_reg[attr].LowerBound and temp < tonumber(bios_reg[attr].LowerBound)) or (bios_reg[attr].UpperBound and temp > tonumber(bios_reg[attr].UpperBound)) or (bios_reg[attr].ValueExpression and attr_str:match(bios_reg[attr].ValueExpression) ~= attr_str) then
								self:error_property_value_not_in_list(attr, tostring(attr_value), extended)
							end
						-- Handling an boolean attribute
						elseif bios_reg[attr].Type == "Boolean" then
							local temp = attr_value
							-- Verifying the data in the request is a valid boolean
							if type(temp) ~= "boolean" then
								self:error_property_value_type(attr, tostring(attr_value), extended)
							end
						end

						-- Only adding field to future BIOS settings if its value in the request is different than its current value
						if tostring(attr_value) ~= tostring(current_data.Attributes[attr]) then
							future_data.Attributes[attr] = attr_value
						elseif not overwrite_resource then
							future_data.Attributes[attr] = nil
						end
					end

					attr_value = nil
				else
					self:error_property_unknown(attr, extended)
				end
			end

			-- Sending error response if error are found
			if extended.error ~= nil then
				self:set_response(extended)
				self:output()
				return
			end

			if _.is_empty(future_data.Attributes) then
				future_data.Attributes = nil
			end

			-- Opening future BIOS settings file for writing
			future_file = io.open(CONFIG.BIOS_FUTURE_PATH, "w")
			if future_file ~= nil then
				-- Verifying that the fields from the request are valid JSON
				local success, future_str = pcall(turbo.escape.json_encode, future_data)
				-- Throwing error if it is not valid JSON
				if not success then
					future_file:close()
					self:error_resource_at_uri_in_unknown_format()
		        end

		        -- Writing data to future BIOS file
		        future_file:write(future_str)
				future_file:close()
			else
				-- Throwing error if future BIOS settings file could not be written to
				self:error_resource_missing_at_uri()
			end
		else
			-- Throwing error if attribute registry file cannot be opened
			self:error_resource_missing_at_uri()
		end
	else
		--Throwing error if user is not authorized
		self:error_insufficient_privilege()
	end

	local url_segments = self:get_url_segments()
	local collection = url_segments[1]

	self:update_lastmodified(prefix, os.time())
	--self:get_future_settings(response)
	self:set_status(204)

	self:set_context(CONSTANTS.BIOS_INSTANCE_CONTEXT)
	self:set_type(CONSTANTS.BIOS_TYPE)
end

return BiosHandler