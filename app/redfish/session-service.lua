-- Import required libraries
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
-- [See "md5.lua"](https://github.com/kikito/md5.lua)
local md5 = require('md5')
-- [See "randbytes.lua"](https://github.com/Okahyphen/randbytes)
local randbytes = require('randbytes')
-- [See "base64.lua"](https://github.com/toastdriven/lua-base64)
local base64 = require('base64')


local SessionHandler = class("SessionHandler", RedfishHandler)

local yield = coroutine.yield

-- Set the path names for session service OEM extensions
local collection_oem_path = "session.session-collection"
local instance_oem_path = "session.session-instance"
local singleton_oem_path = "session.session-service"
SessionHandler:set_all_oem_paths(collection_oem_path, instance_oem_path, singleton_oem_path)

--Handles GET requests for Session Service collection and instance
function SessionHandler:get(id)

	local response = {}
	self.redis = self:get_db()

	if id == "/redfish/v1/SessionService" then
		--GET singleton
		self:get_session_service(response)

	elseif id == "Sessions" then
		--GET collection
		self:get_session_collection(response)
	else
		--GET instance
		self:get_session_instance(response)
	end

	self:set_response(response)

	self:output()
end

-- Handles GET Session Service singleton
function SessionHandler:get_session_service(response)
	local url_segments = self:get_url_segments()
	local collection = url_segments[1]
	
	local prefix = "Redfish:" .. collection
	self:set_scope(prefix)

	--Retrieving data from database
	local pl = self.redis:pipeline()
	pl:hget(prefix .. ":Status", "State")
	pl:hget(prefix .. ":Status", "Health")
	pl:get(prefix .. ":ServiceEnabled")
	pl:get(prefix .. ":SessionTimeout")

	--Creating response using data from database
	local result = yield(pl:run())
	response["Id"] = "SessionService"
	response["Name"] = "Session Service"
	response["Description"] = "Session Service"
	response["Status"] = {
		State = result[3] == "true" and "Enabled" or "Disabled",
		Health = result[2]
	}
	response["ServiceEnabled"] = utils.bool(result[3]) -- TODO change to DB
	response["SessionTimeout"] = tonumber(result[4]) -- TODO change to DB
	response["Sessions"] = {}
	response["Sessions"]["@odata.id"] = CONFIG.SERVICE_PREFIX .. "/" .. collection .. "/Sessions"
	response = self:oem_extend(response, "query." .. self:get_oem_singleton_path())

	utils.remove_nils(response)

	local keys = _.keys(response)
	if #keys < 7 then
		local select_list = turbo.util.join(",", keys)
		self:set_context(CONSTANTS.SESSION_SERVICE_CONTEXT .. "(" .. select_list .. ")")
	else
		self:set_context(CONSTANTS.SESSION_SERVICE_CONTEXT)
	end

	self:set_type(CONSTANTS.SESSION_SERVICE_TYPE)

	-- GET requests must respond with the 'Allow' header specifying what methods are available for the given URL
	self:set_allow_header("GET, PATCH")
end

--Handles GET Session Service collection
function SessionHandler:get_session_collection(response)
	local url_segments = self:get_url_segments()
	local collection, secondary_collection = url_segments[1], url_segments[2]
    local auth_mode = self:get_auth_mode()
	local odataIDs = {}
	local db = self:get_db()
    if auth_mode == self.SESSION_AUTH and self:get_session_id() ~= nil then
		local sess = self:get_session_id()
		local user = yield(db:get("Redfish:" .. collection .. ":" .. secondary_collection .. ":" .. sess .. ":UserName"))
		local user_id = self:get_user_id(user)
		local role = self:get_user_role(user_id)
		local trole = role:split(":")

		--Checking for role; if the role is administrator, then show all the sessions else show only the appropriate session
		if trole[4] == "Administrator" then
	        local sessions = yield(db:keys("Redfish:" .. collection .. ":" .. secondary_collection .. ":*:Token"))
	        odataIDs = utils.getODataIDArray(sessions, 1)
		else
			local odata = {}
			local session = "Redfish:" .. collection .. ":" .. secondary_collection .. ":" .. sess .. ":UserName"
			odata["@odata.id"]= utils.getODataID(session, 1)
			table.insert(odataIDs, odata)
		end
	else
		local sessions = yield(db:keys("Redfish:" .. collection .. ":" .. secondary_collection .. ":*:Token"))
	    odataIDs = utils.getODataIDArray(sessions, 1)
    end
    
	-- Creating response
	response["Name"] = "Session Collection"
	response["Members@odata.count"] = #odataIDs
	response["Members"] = odataIDs

	-- properties that are Oem extendable comes below
	response = self:oem_extend(response, "query." .. self:get_oem_collection_path())

	self:set_scope("Redfish:SessionService:Sessions")
	self:set_context(CONSTANTS.SESSION_COLLECTION_CONTEXT)
	self:set_type(CONSTANTS.SESSION_COLLECTION_TYPE)

	-- GET requests must respond with the 'Allow' header specifying what methods are available for the given URL
	self:set_allow_header("GET, POST")
end

--Handles GET Session Service instance
function SessionHandler:get_session_instance(response)
	local url_segments = self:get_url_segments()
	local collection, secondary_collection, instance = url_segments[1], url_segments[2], url_segments[3]
	local prefix = "Redfish:" .. collection .. ":" .. secondary_collection .. ":" .. instance

	self:set_scope(prefix)

	--Retrieving data from database
	local pl = self.redis:pipeline()
	pl:mget({
			prefix .. ":UserName"
		})

	-- Check that data was found in Redis, if not we throw a 404 NOT FOUND
	local db_result = yield(pl:run())
	self:assert_resource(db_result)

	local general = unpack(db_result)

	--Creating response using data from database
	response["Id"] = instance
	response["Name"] = general[1] .. " Session"
	response["Description"] = "Session for user " .. general[1]
	response["UserName"] = general[1]
	response = self:oem_extend(response, "query." .. self:get_oem_instance_path())

	utils.remove_nils(response)

	local keys = _.keys(response)
	if #keys < 4 then
		local select_list = turbo.util.join(",", keys)
		self:set_context(CONSTANTS.SESSION_INSTANCE_CONTEXT.."(" .. select_list .. ")")
	else
		self:set_context(CONSTANTS.SESSION_INSTANCE_CONTEXT)
	end
	
	self:set_type(CONSTANTS.SESSION_TYPE)

	-- GET requests must respond with the 'Allow' header specifying what methods are available for the given URL
	self:set_allow_header("GET, DELETE")
end

--Handles POST Session Service instance
function SessionHandler:post(id)
    local pl = self.redis:pipeline()
	pl:hget("Redfish:SessionService:Status", "State")
	pl:hget("Redfish:SessionService:Status", "Health")
	pl:get("Redfish:SessionService:ServiceEnabled")
	local result = yield(pl:run())

	-- Deny login if session service is not in good health or state
	local state, health, enabled = result[1], result[2], result[3]
	if(state ~= "Enabled" or health ~= "OK" or enabled ~= "true") then
		self:add_audit_log_entry(self:create_message("Security", "LoginFailure", nil, {"N/A", "the Redfish session handler is unavailable"}))
		
		if health ~= "OK" then
			self:error_service_in_unknown_state()
		else
			self:error_service_disabled()
		end
	end

	local url_segments = self:get_url_segments()
	local collection, secondary_collection = url_segments[1], url_segments[2]
	self.redis = self:get_db()

	local request_data = self:get_json()

	if id == "Sessions" then
		-- Denying login if maximum number of concurrent sessions are running 
		local sessions = yield(self.redis:keys("Redfish:SessionService:Sessions:*:Token"))
		if(#sessions >= CONFIG.MAX_SESSIONS) then
			self:error_session_limit_exceeded()
		end

		if request_data.Password == nil or type(request_data.Password) ~= "string" or request_data.UserName == nil or type(request_data.UserName) ~= "string" then
			self:unauthorized()
		end

		--Verifying login information
		if self:check_login(request_data['UserName'], request_data['Password']) == true then
			self:add_audit_log_entry(self:create_message("Security", "LoginSuccess", nil, {request_data["UserName"], "session"}))
			self:on_login(request_data['UserName'])

			-- login success 
			local sessionID = self:login_user(request_data['UserName'])

			-- The Origin header should be saved in reference to this session creation and compared to subsequent requests using this session to verify the request has been initiated from an authorized client domain.
			-- local origin = self:get_request().headers:get("Origin")
			-- if origin ~= nil then
			--     -- do something
			-- end

			-- The response to the POST request to create a session includes the JSON response body that contains a full representation of the newly created session object
			local response = {}
			response["@odata.id"] = CONFIG.SERVICE_PREFIX .. "/" .. collection .. "/" .. secondary_collection .. "/" .. sessionID
			response["Id"] = sessionID
			response["Name"] = request_data["UserName"] .. " Session"
			response["Description"] = "Session for user " .. request_data["UserName"]
			response["UserName"] = request_data["UserName"]
			
			self.response_table["@odata.context"] = CONFIG.SERVICE_PREFIX .. "/$metadata" .. collection .. "/" .. secondary_collection
			
			self.last_modified = coroutine.yield(self.redis:get(self.scope .. ":LastModified")) or tostring(utils.fileTime('/usr/local/'))
			self.response_table["@odata.etag"] = "W/\""..self.last_modified.."\""

			self:set_type(CONSTANTS.SESSION_TYPE)

			utils.remove_nils(response)

			local keys = _.keys(response)
			if #keys < 4 then
				local select_list = turbo.util.join(",", keys)
				self:set_context(CONSTANTS.SESSION_INSTANCE_CONTEXT.."(" .. select_list .. ")")
			else
				self:set_context(CONSTANTS.SESSION_INSTANCE_CONTEXT)
			end

			-- Send JSON body
			self:set_status(201)
			self:set_response(response)
			self:output()
		else
			--Sending unauthorized request if login fails
			self:unauthorized()
		end

	else
		-- When an HTTP method is rejected with status code 405, we must set an Allow header that lists valid HTTP methods for the URI
	    self:set_header("Allow", "GET")
		-- No PATCH for collections
	    self:error_method_not_allowed()
	end
end

function SessionHandler:login_user(username)
	local sessionID = md5.sumhexa(CONFIG.SALT .. tostring(os.time()) .. CONFIG.SALT)
	local x_auth_token = base64.to_base64(randbytes:uread(32))
	local url_segments = self:get_url_segments()
	local collection, secondary_collection = url_segments[1], url_segments[2]
	local db = self:get_db()
	local timeout = yield(db:get("Redfish:SessionService:SessionTimeout"))
	yield(db:setex("Redfish:" .. collection .. ":" .. secondary_collection .. ":" .. sessionID .. ":UserName", timeout, username))
	if self:get_auth_mode() == self.PAM_AUTH and self.pam_priv ~= nil then
		yield(db:setex("Redfish:" .. collection .. ":" .. secondary_collection .. ":" .. sessionID .. ":PamPriv", timeout, self.pam_priv))
	end
	-- Update last modified so that E-Tag can respond properly
	self:update_lastmodified("Redfish:SessionService:Sessions:" .. sessionID, os.time(), nil, 2)
	yield(db:expire("Redfish:SessionService:Sessions:" .. sessionID .. ":LastModified", timeout))
	-- The response to the POST request to create a session includes:
	-- - An X-Auth-Token header that contains a "session auth token" that the client can use an subsequent requests
	-- - A "Location header that contains a link to the newly created session resource
	
	-- Set location header with session instance
	self:set_header("Location", CONFIG.SERVICE_PREFIX .. "/" .. collection .. "/" .. secondary_collection .. "/" .. sessionID)
	
	-- Set X-Auth-Token. Should not be anywhere else except here
	self:set_header("X-Auth-Token", x_auth_token)

	self:create_session(sessionID, x_auth_token)

	return sessionID
end

function SessionHandler:patch(id)
	local url_segments = self:get_url_segments()
	local collection, instance = url_segments[1], url_segments[2]

	--Throwing error if request is not to SessionService
	if instance ~= nil then
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
	end

	--Making sure current user has permission to modify system settings
	if self:can_user_do("ConfigureUsers") == true then
		local redis = self:get_db()
		local request_data = turbo.escape.json_decode(self:get_request().body)
		local response = {}

		self:set_scope("Redfish:" .. table.concat(url_segments, ":"))
    	if type(request_data) ~= "nil" then

      		local pl = redis:pipeline()
      		local prefix = "Redfish:" .. collection
      		local extended = {}
      		local successful_sets = {}

      		--Validating ServiceEnabled property and adding error if property is incorrect
      		if request_data.ServiceEnabled ~= nil then
        		if type(request_data.ServiceEnabled) ~= "boolean" then
          			self:error_property_value_type("ServiceEnabled", tostring(request_data.ServiceEnabled), extended)
        		else
          			pl:set(prefix..":ServiceEnabled", tostring(request_data.ServiceEnabled))
          			table.insert(successful_sets, "ServiceEnabled")
        		end
        		request_data.ServiceEnabled = nil
      		end

      		--Validating SessionTimeout property and adding error if property is incorrect
      		if request_data.SessionTimeout ~= nil then
        		if type(request_data.SessionTimeout) ~= "number" then
          			self:error_property_value_type("SessionTimeout", tostring(request_data.SessionTimeout), extended)
        		elseif request_data.SessionTimeout < 30 or request_data.SessionTimeout > 86400 then
          			self:error_property_value_not_in_list("SessionTimeout", tostring(request_data.SessionTimeout), extended)
        		else
        			-- Updating TTL of session keys when the SessionTimeout is updated
        			local old_timeout = tonumber(yield(redis:get(prefix..":SessionTimeout")))
        			if old_timeout ~= nil then
	        			local token_keys = yield(redis:keys("Redfish:SessionService:Sessions:*:Token"))
						for _i, token_key in pairs(token_keys) do
							local ttl = yield(redis:ttl(token_key))
							if ttl > 0 then
								local session_id = token_key:match("Redfish:SessionService:Sessions:(.*):Token")
								local time_alive = old_timeout - ttl
								if time_alive >= request_data.SessionTimeout then
									self:destroy_session(session_id)
								else
									local expire_pl = redis:pipeline()
			                        local session_keys = yield(redis:keys("Redfish:SessionService:Sessions:" .. session_id .. ":*"))
			                        for _key_i, sess_key in pairs(session_keys) do
			                        	expire_pl:expire(sess_key, request_data.SessionTimeout - time_alive)
			                        end
			                        yield(expire_pl:run())
								end
							end
						end
					end

          			pl:set(prefix..":SessionTimeout", request_data.SessionTimeout)
          			table.insert(successful_sets, "SessionTimeout")
       			end
        		request_data.SessionTimeout = nil
     		end

	      	if #pl.pending_commands > 0 then
	        	-- Update last modified so that E-Tag can respond properly
	        	self:update_lastmodified("Redfish:SessionService", os.time(), pl, 1)
	        
	        	local result = yield(pl:run())
	        	self:add_audit_log_entry(self:create_message("Security", "ResourceModified", nil, {turbo.util.join(", ", successful_sets), self:get_request().path}))
	      	end
	      	--Checking if there are any additional properties in the request and creating an error to show these properties
	      	local leftover_fields = utils.table_len(request_data)
	      	if leftover_fields ~= 0 then
	        	_.each(_.keys(request_data), function(prop)
	          		self:error_property_unknown(prop, extended)
	        	end)
	      	end

	      	--Checking if there were errors and adding them to the response if there are
	      	if extended.error ~= nil then
	        	self:set_response(extended)
	        	self:output()
	        	return
	      	end

	      	self:get_session_service(response)
	    else
	      	self:error_unrecognized_request_body(response)
	    end
    
		self:set_response(response)
		self:output()
	else
		self:error_insufficient_privilege()
	end
end

-- Delete an existing Session when deleted on SessionService/Sessions/<id>
function SessionHandler:delete(session_id)
  
  	if session_id == "Sessions" or session_id == "/redfish/v1/SessionService" then
    	self:error_method_not_allowed()
  	end
  
	local my_session = self:get_session_id()
  
	if session_id ~= my_session then
		--check if user has privilege to delete other user session
		if self:can_user_do("ConfigureUsers") ~= true then
			self:error_insufficient_privilege()
		end
	end

	local username = self.username
	local db = self:get_db()
	local exists = yield(db:exists("Redfish:SessionService:Sessions:" .. session_id .. ":UserName"))
	-- Destroying session
	if exists == 1 then
		if self:destroy_session(session_id) then
			self:add_audit_log_entry(self:create_message("Security", "UserLogOff", nil, {username}))
			self:update_lastmodified("Redfish:SessionService:Sessions", os.time())
			self:set_status(204)
		else
			self:error_internal()
		end
	else
		self:error_resource_missing_at_uri()
	end

	self:output()
end

return SessionHandler
