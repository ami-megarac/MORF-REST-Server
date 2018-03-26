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