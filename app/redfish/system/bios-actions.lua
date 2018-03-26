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

local BiosActionsHandler = class("BiosActionsHandler", RedfishHandler)

function BiosActionsHandler:get(id, action)    
    if action == "Bios.ChangePassword" or action == "Bios.ResetBios" then
        -- When an HTTP method is rejected with status code 405, we must set an Allow header that lists valid HTTP methods for the URI
        self:set_header("Allow", "POST")
        -- Normal instance shouldn't be PATCHed directly, use settings object
        self:error_method_not_allowed()
    else
        self:error_resource_missing_at_uri()
    end
end

-- PUT BIOS future settings
function BiosActionsHandler:put(id, action)
    if action == "Bios.ChangePassword" or action == "Bios.ResetBios" then
        -- When an HTTP method is rejected with status code 405, we must set an Allow header that lists valid HTTP methods for the URI
        self:set_header("Allow", "POST")
        -- Normal instance shouldn't be PATCHed directly, use settings object
        self:error_method_not_allowed()
    else
        self:error_resource_missing_at_uri()
    end
end

-- PATCH BIOS future settings
function BiosActionsHandler:patch(id, action)
    if action == "Bios.ChangePassword" or action == "Bios.ResetBios" then
        -- When an HTTP method is rejected with status code 405, we must set an Allow header that lists valid HTTP methods for the URI
        self:set_header("Allow", "POST")
        -- Normal instance shouldn't be PATCHed directly, use settings object
        self:error_method_not_allowed()
    else
        self:error_resource_missing_at_uri()
    end
end

function BiosActionsHandler:post(id, action)
    local request_data = self:get_json()
    local prefix = "Redfish:Systems:Self:" .. id

    if action == "Bios.ChangePassword" then
        -- Verifying all the necessary fields are in the request
        if request_data["PasswordName"] == nil then
            self:error_action_parameter_missing("PasswordName")
        elseif type(request_data["PasswordName"]) ~= "string" then
            self:error_action_parameter_type("PasswordName", tostring(request_data["PasswordName"]))
        end

        if request_data["OldPassword"] == nil then
            self:error_action_parameter_missing("OldPassword")
        elseif type(request_data["OldPassword"]) ~= "string" then
            self:error_action_parameter_type("OldPassword", tostring(request_data["OldPassword"]))
        end

        if request_data["NewPassword"] == nil then
            self:error_action_parameter_missing("NewPassword")
        elseif type(request_data["NewPassword"]) ~= "string" then
            self:error_action_parameter_type("NewPassword", tostring(request_data["NewPassword"]))
        end

        -- Opening current BIOS settings file 
        local current_file = io.open(CONFIG.BIOS_CURRENT_PATH,"r")
        local current_data = {}
        if current_file ~= nil then
            -- Verifying that the contents of the current BIOS settings file is valid JSON
            success, current_data = pcall(turbo.escape.json_decode, current_file:read("*all"))
            current_file:close()

            -- Throwing an error if the current BIOS file is not valid JSON
            if not success or current_data.AttributeRegistry == nil then
                self:error_resource_at_uri_in_unknown_format()
            end
        else
            -- Throwing an error if the current BIOS settings file cannot be read
            self:error_resource_missing_at_uri()
        end

        local reg_file_name = current_data.AttributeRegistry

        -- Opening attribute registry file associated with the BIOS settings
        local reg_file = io.open(CONFIG.BIOS_CONF_PATH .. reg_file_name .. ".json_stripped", "r")
        if reg_file ~= nil then
            -- Verifying that the contents of the attribute registry file associated with the BIOS settings is valid JSON
            success, reg = pcall(turbo.escape.json_decode, reg_file:read("*all"))
            reg_file:close()

            -- Throwing an error if the contents of the attribute registry file associated with the BIOS settings is not valid JSON
            if not success then
                self:error_resource_at_uri_in_unknown_format()
            end

            -- Looping through attribute registry looking for cirrect password field
            local attr_found = false
             for attr, val in pairs(reg) do
                if attr == request_data["PasswordName"] and val.Type == "Password" then
                    attr_found = true
                    if val.MinLength ~= nil and request_data["NewPassword"]:len() < tonumber(val.MinLength) then
                        self:error_action_parameter_format("NewPassword", tostring(request_data["NewPassword"]))
                    end

                    if val.MaxLength ~= nil and request_data["NewPassword"]:len() > tonumber(val.MaxLength) then
                        self:error_action_parameter_format("NewPassword", tostring(request_data["NewPassword"]))
                    end

                    break
                end
            end

            -- Throwing error if correct password field is not found
            if not attr_found then
                self:error_action_parameter_unknown("PasswordName")
            end

            if current_data["Attributes"][request_data["PasswordName"]] ~= nil and current_data["Attributes"][request_data["PasswordName"]] ~= "" and current_data["Attributes"][request_data["PasswordName"]] ~= request_data["OldPassword"] then
                self:error_action_parameter_format("OldPassword", request_data["OldPassword"])
            end

            -- Opening password file to read
            local pass = {}
            local pass_file = io.open(CONFIG.BIOS_PASS_PATH, "r")
            if pass_file then
                -- Verifying that the file contents is valid JSON
                success, pass = pcall(turbo.escape.json_decode, pass_file:read("*all"))
                pass_file:close()

                -- Throwing error if the file contents is not valid JSON
                if not success then
                    self:error_resource_at_uri_in_unknown_format()
                end
            end

            -- Creating data to write to add to the password file
            pass[request_data["PasswordName"]] = {
                OldPassword = request_data["OldPassword"],
                NewPassword = request_data["NewPassword"]
            }

            -- Verifying that the password data is valid
            local success, pass_str = pcall(turbo.escape.json_encode, pass)
            
            -- Throwinf error if password data is not valid
            if not success then
                self:error_resource_at_uri_in_unknown_format()
            end

            -- Writing password data to file
            pass_file = io.open(CONFIG.BIOS_PASS_PATH, "w")
            pass_file:write(pass_str)
            pass_file:close()
			self:update_lastmodified(prefix, os.time())
            self:set_status(204)
            return
        else
            -- Throwing error if attribute registry file cannot be opened
            self:error_resource_missing_at_uri()
        end
    elseif action == "Bios.ResetBios" then
        if not request_data.ResetType then
            self:error_action_parameter_missing("ResetType")
        elseif request_data.ResetType ~= "Reset" then
            self:error_property_value_not_in_list("ResetType", request_data.ResetType)
        end

        reset_file = io.open(CONFIG.BIOS_RESET_PATH, "w")
        reset_file:write()
        reset_file:close()
		self:update_lastmodified(prefix, os.time())
        self:set_status(204)
    elseif self:get_request().path:find("Actions") then
        self:error_action_not_supported()
    else 
        self:error_resource_missing_at_uri()
    end

end

return BiosActionsHandler