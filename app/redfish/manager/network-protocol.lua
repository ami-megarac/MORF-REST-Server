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

local NetworkProtocolHandler = class("NetworkProtocolHandler", RedfishHandler)

local yield = coroutine.yield

-- Set the path names for manager network protocol OEM extensions
local singleton_oem_path = "manager.manager-logentry-collection"
NetworkProtocolHandler:set_oem_singleton_path(singleton_oem_path)

-- The 'property_access' table specifies read/write permission for all properties.
local property_access = require("property-access.NetworkProtocol")["ManagerNetworkProtocol"]

-- ### GET request handler for Manager/NetworkProtocol
function NetworkProtocolHandler:get(_manager_id)

	local response = {}
    
    self:get_instance(response)

    -- After the response is created, we register it with the handler and then output it to the client.
	self:set_response(response)

    -- GET requests must respond with the 'Allow' header specifying what methods are available for the given URL
    self:set_allow_header("GET, PATCH")

	self:output()
end

-- ### PATCH request handler for Manager/NetworkProtocol
function NetworkProtocolHandler:patch(_manager_id)

    local response = {}

    -- Allow the OEM patch handlers for network protocol singleton to have the first chance to handle the request body
    response = self:oem_extend(response, "patch." .. self:get_oem_singleton_path())

    -- Check if user is authorized to make changes.
    if self:can_user_do("ConfigureManager") == true then
        -- If so, patch the resource and respond with the updated version. 
        -- Check Redis for the presence of the resource in question. If it isn't found, throw a 404
        local redis = self:get_db()
        local np_exists = yield(redis:exists("Redfish:Managers:".._manager_id..":NetworkProtocol:Name"))
        if np_exists == 1 then
            self:patch_instance(response)
        else
            self:assert_resource(nil)
        end
    else
        --Throw an error if the user is not authorized.         
        self:error_insufficient_privilege()
    end

    -- After the response is created, we register it with the handler and then output it to the client.
    self:set_response(response)

    self:output()
end

-- #### GET handler for Network Protocol instance
function NetworkProtocolHandler:get_instance(response)
    -- Set up the local space: get a connection with Redis DB, gather url segment, establish redis prefix, and set scope
	local redis = self:get_db()

	local collection, instance, secondary_collection = 
		self.url_segments[1], self.url_segments[2], self.url_segments[3];

	local prefix = "Redfish:Managers:"..instance..":NetworkProtocol"
	
	self:set_scope("Redfish:"..table.concat(self.url_segments,':'))
    -- Create a Redis pipeline and add commands for all Network Protocol properties
	local pl = redis:pipeline()

	pl:mget({
			prefix..":Description",
			prefix..":Name",
			prefix..":HostName",
			prefix..":FQDN"
			})
	pl:hmget(prefix..":HTTP", "ProtocolEnabled", "Port")
	pl:hmget(prefix..":HTTPS", "ProtocolEnabled", "Port")
	pl:hmget(prefix..":SNMP", "ProtocolEnabled", "Port")
	pl:hmget(prefix..":VirtualMedia", "ProtocolEnabled", "Port")
	pl:hmget(prefix..":Telnet", "ProtocolEnabled", "Port")
	pl:hmget(prefix..":SSDP", "ProtocolEnabled", "Port", "NotifyMulticastIntervalSeconds", "NotifyTTL", "NotifyIPv6Scope")
	pl:hmget(prefix..":IPMI", "Port")
	pl:hmget(prefix..":SSH", "ProtocolEnabled", "Port")
	pl:hmget(prefix..":KVMIP", "ProtocolEnabled", "Port")
	pl:hmget(prefix..":Status", "State", "Health")
    -- Run the Redis pipeline, and unpack the results  
    local db_result = yield(pl:run())

    -- Check that data was found in Redis, if not we throw a 404 NOT FOUND
    self:assert_resource(db_result)

	local general, HTTP, HTTPS, snmp, vmedia, telnet, ssdp, ipmi, ssh, kvmip, status = unpack(db_result)
    -- Add the data from Redis into the response, converting types and creating sub-objects where necessary
	response["Id"] = "NetworkProtocol"
    response["Description"] = general[1]
    response["Name"] = general[2]
    response["HostName"] = general[3]
    response["FQDN"] = general[4]
    if status[1] or status[2] then
        response["Status"] = {
    		State = status[1],
    		Health = status[2]
    	}
    end

    if type(HTTPS[1]) ~= "nil" then
        response["HTTPS"] = {
            ProtocolEnabled = utils.bool(HTTPS[1]),
            Port = tonumber(HTTPS[2]) 
        }
    end
    if type(snmp[1]) ~= "nil" then
        response["SNMP"] = {
            ProtocolEnabled = utils.bool(snmp[1]),
            Port = tonumber(snmp[2]) 
        }
    end
    if type(vmedia[1]) ~= "nil" then
        response["VirtualMedia"] = {
            ProtocolEnabled = utils.bool(vmedia[1]),
            Port = tonumber(vmedia[2]) 
        }
    end
    if type(telnet[1]) ~= "nil" then
        response["Telnet"] = {
            ProtocolEnabled = utils.bool(telnet[1]),
            Port = tonumber(telnet[2]) 
        }
    end
    if type(ssdp[1]) ~= "nil" then
        response["SSDP"] = {
            ProtocolEnabled = utils.bool(ssdp[1]),
            Port = tonumber(ssdp[2]),
            NotifyMulticastIntervalSeconds = tonumber(ssdp[3]),
            NotifyTTL = tonumber(ssdp[4]),
            NotifyIPv6Scope = ssdp[5] 
        }
    end
    if type(ipmi[1]) ~= "nil" then
        response["IPMI"] = {
            Port = tonumber(ipmi[1])
        }
    end
    if type(ssh[1]) ~= "nil" then
        response["SSH"] = {
            ProtocolEnabled = utils.bool(ssh[1]),
            Port = tonumber(ssh[2])
        }
    end
    if type(kvmip[1]) ~= "nil" then
        response["KVMIP"] = {
            ProtocolEnabled = utils.bool(kvmip[1]),
            Port = tonumber(kvmip[2])
        }
    end
    -- Add OEM extension properties to the response
    response = self:oem_extend(response, "query." .. self:get_oem_singleton_path())
    -- Set the OData context and type for the response
    local sL_table = _.keys(response)
    if #sL_table < 15 then
        local selectList = turbo.util.join(',', sL_table)
        self:set_context(CONSTANTS.NETWORK_PROTOCOL_INSTANCE_CONTEXT.."("..selectList..")")
    else
        self:set_context(CONSTANTS.NETWORK_PROTOCOL_INSTANCE_CONTEXT)
    end
	self:set_type(CONSTANTS.NETWORK_PROTOCOL_TYPE)
    -- Remove extraneous fields from the response
    utils.remove_nils(response)
end

-- #### PATCH handler for Network Protocol instance
function NetworkProtocolHandler:patch_instance(response)
    -- Set up the local space: get a connection with Redis DB, gather url segment, establish redis prefix, and set scope
    local redis = self:get_db()

    local collection, instance, secondary_collection = 
        self.url_segments[1], self.url_segments[2], self.url_segments[3];

    local prefix = "Redfish:Managers:"..instance..":NetworkProtocol"
    
    self:set_scope("Redfish:"..table.concat(self.url_segments,':'))
    local pl = redis:pipeline()
    pl:hget(prefix..":HTTPS", "ProtocolEnabled")
    pl:hget(prefix..":SNMP", "ProtocolEnabled")
    pl:hget(prefix..":VirtualMedia", "ProtocolEnabled")
    pl:hget(prefix..":Telnet", "ProtocolEnabled")
    pl:hget(prefix..":SSDP", "ProtocolEnabled")
    pl:hget(prefix..":IPMI", "ProtocolEnabled")
    pl:hget(prefix..":SSH", "ProtocolEnabled")
    pl:hget(prefix..":KVMIP", "ProtocolEnabled")

    -- Run the Redis pipeline, and unpack the results  
    local db_result = yield(pl:run())
    local HTTPS_enabled, snmp_enabled, vmedia_enabled,
         telnet_enabled, ssdp_enabled, ipmi_enabled, ssh_enabled, kvmip_enabled = unpack(db_result)

    -- Get the request body.
    local request_data = turbo.escape.json_decode(self:get_request().body)

    -- The 'extended' table will hold all of our "@Message.ExtendedInfo" errors that accumulate while making changes.
    local extended = {}
    local successful_sets = {}
    local keys_to_watch = {}
    -- The 'patch_operations' table holds functions that know how to PATCH each property.
    -- For each property, validate the value, then create an error message or add appropriate Redis command based on outcome.
    -- TODO: allow SSDP configuration (once it is implemented)
    
    local pl = redis:pipeline()

    local patch_operations = {

        ["HTTPS.ProtocolEnabled"] = function(pipe, value)
            if not (type(value) == "boolean") then
                self:error_property_value_type("#/HTTPS/ProtocolEnabled", tostring(value), extended)
            else
                pipe:hset("PATCH:" .. prefix .. ":HTTPS", "ProtocolEnabled", tostring(value))
                table.insert(successful_sets, "HTTPS:ProtocolEnabled")
                table.insert(keys_to_watch, prefix .. ":HTTPS")
            end
        end,
        ["HTTPS.Port"] = function(pipe, value)
            if not (type(value) == "number") then
                self:error_property_value_type("#/HTTPS/Port", tostring(value), extended)
            elseif value < 1 or value > 65535 then
                self:error_property_value_type("#/HTTPS/Port", tostring(value), extended)
            else
                if HTTPS_enabled == "true" then
                    pipe:hset("PATCH:" .. prefix .. ":HTTPS", "Port", value)
                    table.insert(successful_sets, "HTTPS:Port")
                    table.insert(keys_to_watch, prefix .. ":HTTPS")
                else           
                    self:error_service_disabled(extended)
                end
            end
        end,
        ["KVMIP.ProtocolEnabled"] = function(pipe, value)
            if not (type(value) == "boolean") then
                self:error_property_value_type("#/KVMIP/ProtocolEnabled", tostring(value), extended)
            else
                pipe:hset("PATCH:" .. prefix .. ":KVMIP", "ProtocolEnabled", tostring(value))
                table.insert(successful_sets, "KVMIP:ProtocolEnabled")
                table.insert(keys_to_watch, prefix .. ":KVMIP")
            end
        end,
        ["KVMIP.Port"] = function(pipe, value)
            if not (type(value) == "number") then
                self:error_property_value_type("#/KVMIP/Port", tostring(value), extended)
            elseif value < 1 or value > 65535 then
                self:error_property_value_type("#/KVMIP/Port", tostring(value), extended)
            else
                if kvmip_enabled == "true" then
                    pipe:hset("PATCH:" .. prefix .. ":KVMIP", "Port", value)
                    table.insert(successful_sets, "KVMIP:Port")
                    table.insert(keys_to_watch, prefix .. ":KVMIP")
                else
                    self:error_service_disabled(extended)
                end
            end
        end,
        ["VirtualMedia.ProtocolEnabled"] = function(pipe, value)
            if not (type(value) == "boolean") then
                self:error_property_value_type("#/VirtualMedia/ProtocolEnabled", tostring(value), extended)
            else
                pipe:hset("PATCH:" .. prefix .. ":VirtualMedia", "ProtocolEnabled", tostring(value))
                table.insert(successful_sets, "VirtualMedia:ProtocolEnabled")
                table.insert(keys_to_watch, prefix .. ":VirtualMedia")
            end
        end,
        ["VirtualMedia.Port"] = function(pipe, value)
            if not (type(value) == "number") then
                self:error_property_value_type("#/VirtualMedia/Port", tostring(value), extended)
            elseif value < 1 or value > 65535 then
                self:error_property_value_type("#/VirtualMedia/Port", tostring(value), extended)
            else
                if vmedia_enabled == "true" then
                    pipe:hset("PATCH:" .. prefix .. ":VirtualMedia", "Port", value)
                    table.insert(successful_sets, "VirtualMedia:Port")
                    table.insert(keys_to_watch, prefix .. ":VirtualMedia")
                else
                    self:error_service_disabled(extended)
                end
            end
        end,
        ["SSH.ProtocolEnabled"] = function(pipe, value)
            if not (type(value) == "boolean") then
                self:error_property_value_type("#/SSH/ProtocolEnabled", tostring(value), extended)
            else
                pipe:hset("PATCH:" .. prefix .. ":SSH", "ProtocolEnabled", tostring(value))
                table.insert(successful_sets, "SSH:ProtocolEnabled")
                table.insert(keys_to_watch, prefix .. ":SSH")
            end
        end,
        ["SSH.Port"] = function(pipe, value)
            if not (type(value) == "number") then
                self:error_property_value_type("#/SSH/Port", tostring(value), extended)
            elseif value < 1 or value > 65535 then
                self:error_property_value_type("#/SSH/Port", tostring(value), extended)
            else
                if ssh_enabled == "true" then
                    pipe:hset("PATCH:" .. prefix .. ":SSH", "Port", value)
                    table.insert(successful_sets, "SSH:Port")
                    table.insert(keys_to_watch, prefix .. ":SSH")
                else
                    self:error_service_disabled(extended)
                end
            end
        end,
        ["Telnet.ProtocolEnabled"] = function(pipe, value)
            if not (type(value) == "boolean") then
                self:error_property_value_type("#/Telnet/ProtocolEnabled", tostring(value), extended)
            else
                pipe:hset("PATCH:" .. prefix .. ":Telnet", "ProtocolEnabled", tostring(value))
                table.insert(successful_sets, "Telnet:ProtocolEnabled")
                table.insert(keys_to_watch, prefix .. ":Telnet")
            end
        end,
        ["Telnet.Port"] = function(pipe, value)
            if not (type(value) == "number") then
                self:error_property_value_type("#/Telnet/Port", tostring(value), extended)
            elseif value < 1 or value > 65535 then
                self:error_property_value_type("#/Telnet/Port", tostring(value), extended)
            else
                if telnet_enabled == "true" then
                    pipe:hset("PATCH:" .. prefix .. ":Telnet", "Port", value)
                    table.insert(successful_sets, "Telnet:Port")
                    table.insert(keys_to_watch, prefix .. ":Telnet")
                else
                    self:error_service_disabled(extended)
                end
            end
        end,
        ["IPMI.ProtocolEnabled"] = function(pipe, value)
            if not (type(value) == "boolean") then
                self:error_property_value_type("#/IPMI/ProtocolEnabled", tostring(value), extended)
            else
                pipe:hset("PATCH:" .. prefix .. ":IPMI", "ProtocolEnabled", tostring(value))
                table.insert(successful_sets, "IPMI:ProtocolEnabled")
                table.insert(keys_to_watch, prefix .. ":IPMI")
            end
        end,
    }

    -- Split the request body into read-only and writable properties.
    local readonly_body
    local writable_body
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
            if type(value) == "table" then
                for prop2, val2 in pairs(value) do
                    self:error_property_not_writable(tostring(property.."/"..prop2), extended)
                end
            else
                self:error_property_not_writable(tostring(property), extended)
            end
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
            local property_key = to_key:split("NetworkProtocol:", nil, true)[2]
            local key_segments = property_key:split(":")
            local property_name = "#/" .. table.concat(key_segments, "/")
            table.insert(extended, self:create_message("SyncAgent", "PatchTimeout", property_name, {CONFIG.PATCH_TIMEOUT/1000, property_name}))
        end
        self:add_audit_log_entry(self:create_message("Security", "ResourceModified", nil, {turbo.util.join(", ", successful_sets), self:get_request().path}))
    end

    -- If we caught any errors along the way, add them to the response.
    if extended.error ~= nil then
        response["error"] = extended["error"]
	return
    end
    
    self:set_status(204)

end

return NetworkProtocolHandler