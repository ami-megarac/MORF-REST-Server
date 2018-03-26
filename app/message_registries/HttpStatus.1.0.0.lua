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

local Lua_table_Http = {
    ["@Redfish.Copyright"] = "Copyright AMI 2015",
    ["@odata.type"] = "#MessageRegistry.1.0.0.MessageRegistry",
    ["Id"] = "HttpStatus.1.0.0",
    ["Name"] = "HTTP Statuses Message Registry",
    ["Language"] = "en",
    ["Description"] = "This registry defines HTTP status messages that are not covered by the Base Message Registry",
    ["RegistryPrefix"] = "HttpStatus",
    ["RegistryVersion"] = "1.0.0",
    ["OwningEntity"] = "AMI",
    ["Messages"] = {
        ["MethodNotAllowed"] = {
            ["Description"] = "Indicates that the HTTP method for the request is not supported for this request URI",
            ["Message"] = "The method %1 is not allowed for the URI %2",
            ["Severity"] = "Critical",
            ["NumberOfArgs"] = 2,
            ["ParamTypes"] = { "string", "string" },
            ["Resolution"] = "Use a method listed in the Allow header"
        },
        ["NotAcceptable"] = {
            ["Description"] = "Indicates that the resource identified by this request is not capable of generating a representation corresponding to one of the media types in the Accept header",
            ["Message"] = "The resource at %1 cannot be represented as any of the media types in the request Accept header",
            ["Severity"] = "Critical",
            ["NumberOfArgs"] = 1,
            ["ParamTypes"] = { "string" },
            ["Resolution"] = "Verify that Accept header in request is correct"
        },
        ["Conflict"] = {
            ["Description"] = "Indicates that the request could not be completed because it would cause a conflict in the current state of the resources supported by the platform",
            ["Message"] = "The request to %1 cannot be completed because it would cause a conflict in the current state of the resources supported by the platform",
            ["Severity"] = "Critical",
            ["NumberOfArgs"] = 1,
            ["ParamTypes"] = { "string" },
            ["Resolution"] = "Resolve conflict and try request again"
        },
        ["LengthRequired"] = {
            ["Description"] = "Indicates that request did not specify the length of its content using the Content-Length header and the resource requires the Content-Length header",
            ["Message"] = "The request to %1 cannot be completed because the requested resource requires the Content-Length header be present",
            ["Severity"] = "Critical",
            ["NumberOfArgs"] = 1,
            ["ParamTypes"] = { "string" },
            ["Resolution"] = "Include Content-Length header in request"
        },
        ["PreconditionFailed"] = {
            ["Description"] = "Indicates that the one or more of the precondition(s) in the request-header failed",
            ["Message"] = "The request to %1 cannot be completed because the %2 precondition failed",
            ["Severity"] = "Critical",
            ["NumberOfArgs"] = 2,
            ["ParamTypes"] = { "string", "string" },
            ["Resolution"] = "None"
        },
        ["UnsupportedMediaType"] = {
            ["Description"] = "Indicates that the request specifies a Content-Type for the body that is not supported",
            ["Message"] = "The request to %1 cannot be completed because the Content-Type %2 is not supported",
            ["Severity"] = "Critical",
            ["NumberOfArgs"] = 2,
            ["ParamTypes"] = { "string", "string" },
            ["Resolution"] = "Verify Content-Type header is correct and send request in a supported format"
        },
        ["NotImplemented"] = {
            ["Description"] = "Indicates that the server does not recognize the request method and is not capable of supporting the method for any resource",
            ["Message"] = "The request to %1 cannot be completed because the server does not support the %2 method for any resource",
            ["Severity"] = "Critical",
            ["NumberOfArgs"] = 2,
            ["ParamTypes"] = { "string", "string" },
            ["Resolution"] = "Use a method listed in the Allow header"
        }
    }
}

return Lua_table_Http