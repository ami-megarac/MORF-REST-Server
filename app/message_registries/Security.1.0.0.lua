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

local Lua_table_Security = {
    ["@Redfish.Copyright"] = "Copyright AMI 2015",
    ["@odata.type"] = "#MessageRegistry.1.0.0.MessageRegistry",
    ["Id"] = "Security.1.0.0",
    ["Name"] = "Security Message Registry",
    ["Language"] = "en",
    ["Description"] = "This registry defines the Security messages for Redfish",
    ["RegistryPrefix"] = "Security",
    ["RegistryVersion"] = "1.0.0",
    ["OwningEntity"] = "AMI",
    ["Messages"] = {
        ["LoginFailure"] = {
            ["Description"] = "Indicates that there was an error while attempting to login",
            ["Message"] = "Login for user %1 was a failure because %2",
            ["Severity"] = "Critical",
            ["NumberOfArgs"] = 2,
            ["ParamTypes"] = { "string", "string" },
            ["Resolution"] = "Verify that the login credentials are correct"
        },
        ["LoginSuccess"] = {
            ["Description"] = "Indicates that the login attempt was successful.",
            ["Message"] = "Login for user %1 using %2 authentication was a success.",
            ["Severity"] = "OK",
            ["NumberOfArgs"] = 2,
            ["ParamTypes"] = { "string", "string" },
            ["Resolution"] = "None"
        },
        ["UserLogOff"] = {
            ["Description"] = "Indicates that the log-off attempt was successful.",
            ["Message"] = "User %1 is now logged off.",
            ["Severity"] = "OK",
            ["NumberOfArgs"] = 1,
            ["ParamTypes"] = { "string" },
            ["Resolution"] = "None"
        },
        ["SessionExpired"] = {
            ["Description"] = "Indicates that a session has been inactive for a period and will now be invalidated.",
            ["Message"] = "Invalidating session for user %1.",
            ["Severity"] = "OK",
            ["NumberOfArgs"] = 1,
            ["ParamTypes"] = { "string" },
            ["Resolution"] = "None"
        },
        ["AccessAllowed"] = {
            ["Description"] = "Indicates that the service has allowed access, connection to or transfer to/from another resource.",
            ["Message"] = "Access to the resource located at %1 was allowed.",
            ["Severity"] = "OK",
            ["NumberOfArgs"] = 1,
            ["ParamTypes"] = { "string" },
            ["Resolution"] = "None"
        },
        ["AccessDenied"] = {
            ["Description"] = "Indicates that while attempting to access, connect to or transfer to/from another resource, the service was denied access.",
            ["Message"] = "While attempting to establish a connection to %1, the service was denied access.",
            ["Severity"] = "Critical",
            ["NumberOfArgs"] = 1,
            ["ParamTypes"] = { "string" },
            ["Resolution"] = "Attempt to ensure that the URI is correct and that the service has the appropriate credentials."
        },
        ["ResourceModified"] = {
            ["Description"] = "Indicates that the resource at a given URI was successfully modified.",
            ["Message"] = "%1 fields of the resource located at %2 were successfully modifed.",
            ["Severity"] = "OK",
            ["NumberOfArgs"] = 2,
            ["ParamTypes"] = { "string", "string" },
            ["Resolution"] = "None"
        },
        ["ResourceCreated"] = {
            ["Description"] = "Indicates that the resource was successfully created at a given URI.",
            ["Message"] = "The resource at %1 has been successfully created.",
            ["Severity"] = "OK",
            ["NumberOfArgs"] = 1,
            ["ParamTypes"] = { "string" },
            ["Resolution"] = "None"
        },
        ["ResourceDeleted"] = {
            ["Description"] = "Indicates that the resource at a given URI was successfully deleted.",
            ["Message"] = "The resource at %1 has been successfully deleted.",
            ["Severity"] = "OK",
            ["NumberOfArgs"] = 1,
            ["ParamTypes"] = { "string" },
            ["Resolution"] = "None"
        },
        ["InsufficientPrivilege"] = {
            ["Description"] = "Indicates that the credentials associated with the established session do not have sufficient privileges for the requested operation",
            ["Message"] = "There are insufficient privileges for the account or credentials associated with the current session to perform the requested %1 operation at %2.",
            ["Severity"] = "Critical",
            ["NumberOfArgs"] = 2,
            ["ParamTypes"] = { "string", "string" },
            ["Resolution"] = "Either abandon the operation or change the associated access rights and resubmit the request if the operation failed."
        },
        ["ResourceNotWritable"] = {
            ["Description"] = "Indicates that a request is trying to modify a resource, but the resource cannot be modified.",
            ["Message"] = "The resource at %1 cannot be modified.",
            ["Severity"] = "Warning",
            ["NumberOfArgs"] = 1,
            ["ParamTypes"] = { "string" },
            ["Resolution"] = "Do not try to modify this resource"
        },
        ["InsufficientPrivilegeForProperty"] = {
            ["Description"] = "Indicates that the credentials associated with the established session do not have sufficient privileges to modify this property",
            ["Message"] = "There are insufficient privileges for the account or credentials associated with the current session to modify the property %1",
            ["Severity"] = "Critical",
            ["NumberOfArgs"] = 1,
            ["ParamTypes"] = { "string" },
            ["Resolution"] = "Either abandon the operation or change the associated access rights and resubmit the request if the operation failed."
        }
    }
}

return Lua_table_Security