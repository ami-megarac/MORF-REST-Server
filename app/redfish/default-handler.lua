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

local RedfishHandler = require("redfish-handler")


-- The default handler that reports as missing resource
local DefaultHandler = class("DefaultHandler", RedfishHandler)

-- Default GET resource missing handler function
function DefaultHandler:get(url)
    self:error_resource_missing_at_uri()
end

-- Default POST resource missing handler function
function DefaultHandler:post()
    self:error_resource_missing_at_uri()
end

-- Default PUT resource missing handler function
function DefaultHandler:put()
    self:error_resource_missing_at_uri()
end

-- Default PATCH resource missing handler function
function DefaultHandler:patch()
    self:error_resource_missing_at_uri()
end

-- Default DELETE resource missing handler function
function DefaultHandler:delete()
    self:error_resource_missing_at_uri()
end

return DefaultHandler