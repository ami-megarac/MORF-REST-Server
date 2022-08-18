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

-------------
-- RedfishHandler module
-- @module RedfishHandler
-- @author AMI MegaRAC

-- [See "turbo library"](http://turbolua.org)
local turbo = require("turbo")
-- [See "odata-handler.lua"](/odata-handler.html)
local ODataHandler = require("odata-handler")
local _ = require("underscore")
-- [See "config.lua"](/config.html)
local CONFIG = require("config")
-- [See "constants.lua"](/constants.html)
local CONSTANTS = require("constants")
-- [See "turboredis.lua"](/turboredis.html)
local turboredis = require("turboredis")

-- [See "base64.lua"](https://github.com/toastdriven/lua-base64)
local base64 = require("base64")
-- [See "md5.lua"](https://github.com/kikito/md5.lua)
local md5 = require("md5")

-- [See "utils.lua"](/utils.html)
local utils = require("utils")
-- [See "settings.lua"](/settings.html)
local settings = require("settings")
-- [See "turbo-redis-mods.lua"](/turbo-redis-mods.html)
local tr_mods = require("turbo-redis-mods")

turboredis.Connection.initialize = tr_mods._new_connection_with_family
turbo.iostream.IOStream.connect = tr_mods._iostream_connect_with_uds

local ffi = require("ffi")

local user_auth
local user_priv_lib
if CONFIG.USE_SPX_PAM == true then
    require("pam_ffi")
    user_auth = ffi.load("/usr/local/lib/libuserauth.so")
    user_priv_lib = ffi.load("/usr/local/lib/libuserprivilege.so")
end

-- Typedef SSL structs to void as we never access their members and
-- they are massive in ifdef's etc and are best left as blackboxes!
ffi.cdef[[
        typedef void BIO;
        typedef void BIO_METHOD;
        typedef void X509;
        typedef void X509_STORE;
        typedef void X509_STORE_CTX;
        typedef void pem_password_cb;
        typedef void STACK;
        BIO *  BIO_new(const BIO_METHOD *type);
        const BIO_METHOD *     BIO_s_mem(void);
        int    BIO_puts(BIO *b,const char *buf);
        X509 *PEM_read_bio_X509(BIO *bp, X509 **x, pem_password_cb *cb, void *u);
        X509_STORE *X509_STORE_new(void);
        int X509_STORE_add_cert(X509_STORE *ctx, X509 *x);
        X509_STORE_CTX *X509_STORE_CTX_new(void);
        int X509_STORE_CTX_init(X509_STORE_CTX *ctx, X509_STORE *store, X509 *x509, STACK *chain);
        int X509_verify_cert(X509_STORE_CTX *ctx);
        void BIO_free_all(BIO *a);
        void OPENSSL_add_all_algorithms_noconf(void);
        void X509_STORE_CTX_free(X509_STORE_CTX *ctx);
        void X509_STORE_free(X509_STORE *v);
        void X509_free(X509 *a);
]]
local lssl = ffi.load("ssl")

local RedfishHandler = class("RedfishHandler", ODataHandler)

local yield = coroutine.yield
local task = turbo.async.task

local MessageRegistries = {}
-- [See "message_registries/Base.lua"](/message_registries/Base.html)
MessageRegistries.Base = dofile("message_registries/Base.1.0.0.lua")
MessageRegistries.Security = dofile("message_registries/Security.1.0.0.lua")
MessageRegistries.IPMI = dofile("message_registries/IPMI.1.0.0.lua")
MessageRegistries.SyncAgent = dofile("message_registries/SyncAgent.1.0.0.lua")
MessageRegistries.HttpStatus = dofile("message_registries/HttpStatus.1.0.0.lua")

local finished = false
local ca_cert = nil
local ca_cert_mtime = 0
local auth_failure_log_count = 0

--Add patch function required for odata
--Override patch to implement a patch handler
--The implementation may reject the update operation on certain fields based on its own policies and, if so, shall not apply any of the update requested
--If the resource can never be updated, status code 405 shall be returned.
--Services may return a representation of the resource after any server-side transformations in the body of the response
--If a property in the request can never be updated, such as when a property is read only, a status code of 200 shall be returned along with a 
-- representation of the resource containing an annotation specifying the non-updatable property. In this success case, other properties may be updated in the resource
function RedfishHandler:patch(...)
	self:set_header("Allow", "GET")
	self:set_status(405)

	local response = { }

	if self:is_instance() and self.oem_instance_path then

		response = self:oem_extend(response, "patch." .. self.oem_instance_path)

	elseif self:is_collection() and self.oem_collection_path then

		response = self:oem_extend(response, "patch." .. self.oem_collection_path)

	elseif self:is_singleton() and self.oem_singleton_path then

		response = self:oem_extend(response, "patch." .. self.oem_singleton_path)

	end

	if self:get_status() == 405 then
		self:error_method_not_allowed()
	end
end

--- Add Post function required for odata
--The implementation may reject the post operation on certain fields based on its own policies and, if so, shall not apply any of the post requested
--If the resource can never be post, status code 405 shall be returned.
--Services may return a representation of the resource after any server-side transformations in the body of the response
--If a property in the request can never be post, such as when a property is read only, a status code of 200 shall be return.
function RedfishHandler:post(...)
	self:set_header("Allow", "GET")
	self:set_status(405)

	local response = { }

	if self:is_instance() and self.oem_instance_path then

		self:oem_extend(response, "post." .. self.oem_instance_path)

	elseif self:is_collection() and self.oem_collection_path then

		self:oem_extend(response, "post." .. self.oem_collection_path)

	elseif self:is_singleton() and self.oem_singleton_path then

		self:oem_extend(response, "post." .. self.oem_singleton_path)

	end

	if self:get_status() == 405 then
		self:error_method_not_allowed()
	end
end

--- Add Delete function required for odata
--- Add delete function required for odata
--The implementation may reject the delete operation on certain fields based on its own policies and, if so, shall not apply any of the delete requested
--If the resource can never be delete, status code 405 shall be returned.
function RedfishHandler:delete(...)
	self:set_header("Allow", "GET")
	self:set_status(405)

	local response = { }

	if self:is_instance() and self.oem_instance_path then

		self:oem_extend(response, "delete." .. self.oem_instance_path)

	elseif self:is_collection() and self.oem_collection_path then

		self:oem_extend(response, "delete." .. self.oem_collection_path)

	elseif self:is_singleton() and self.oem_singleton_path then

		self:oem_extend(response, "delete." .. self.oem_singleton_path)

	end

	if self:get_status() == 405 then
		self:error_method_not_allowed()
	end
end

--- Add Get function required for odata
function RedfishHandler:get(...)
	local response = {}
	if self.request.headers:get_url() == "/redfish" then
		response.v1 = "/redfish/v1/"
	else
		self:error_method_not_allowed()
	end

	self:write(response)
	self:finish()
end

--- HEAD method should respond with all the valid headers that come with a GET request, but no response body.
-- ODataHandler:output() checks the request method type and won't send the response body if it sees a HEAD request has been made.
function RedfishHandler:head(...)
	self.get(self, ...)
end

--- Initialize a new application class instance.
-- @param application Name of the application
-- @param request Request object
-- @param url_args URL argument
-- @param options Other options
function RedfishHandler:initialize(application, request, url_args, options)

	ODataHandler.initialize(self, application, request, url_args, options)

	self.request = request

	self.url_args = url_args

	self.options = options

	self.application = application

	self.collection_property = "Members"
	
	self.response_table = {}

    self.BASIC_AUTH = "Basic"
    self.SESSION_AUTH = "Session"
    self.CERT_AUTH = "Certificate"
    self.PAM_AUTH = "PAM"


	-- This flag determines whether $skip/$top need to be processed by RedfishHandler
	-- Used to prevent $skip/$top from being processed twice in special cases (such as Log Entry Collection)
	self.skip_top_flag = true

end

--- Override this method to do something straight after the class has been initialized.
function RedfishHandler:on_create()
	if CONFIG.PROFILING_ENABLED then
		print("Started profiling requests")
		ProFi:start()
	end
	if CONFIG.DBG_HANDLER_MEMORY then
		self.firstcount = collectgarbage("count")
	end
end

--- Inherited modules can use this function to get application reference
-- @treturn application Instance of turbo application
function RedfishHandler:get_application()

	return self.application

end

--- Inherited modules can use this function to get incoming request handler
-- @treturn HTTPRequest Turbo HTTPRequest reference
function RedfishHandler:get_request()

	return self.request

end

--- Inherited modules can use this function to check if the incoming request is targetting a Redfish instance
--- This check is done by looking at the pattern used to route the request and seeing if it ends in a regex capture for the instance id
--- If this functin returns false, the target resource may be a collection, singleton, settings object, OR action URL
-- @return boolean is_instance
function RedfishHandler:is_instance()

	local path = self.request.path

	local handlers_sz = #self.application.handlers
	for i = 1, handlers_sz do
		local handler = self.application.handlers[i]
		local pattern = handler[1]
		local match = {path:match(pattern)}
		if #match > 0 then
			return pattern:find("Actions/([^/]+)$", 0, 1) == nil and pattern:find("([^/]+)$", 0, 1) ~= nil
		end
	end

end

--- Inherited modules can use this function to check if the incoming request is targetting a Redfish collection
--- This check is done by looking at the pattern used to route the request and seeing if there is a matching instance route
--- If this function returns false, the target resource may be an instance, singleton, settings object, OR action URL
-- @return boolean is_collection
function RedfishHandler:is_collection()

	local path = self.request.path

	local pattern

	local handlers_sz = #self.application.handlers
	for i = 1, handlers_sz do
		local handler = self.application.handlers[i]
		pattern = handler[1]
		local match = {path:match(pattern)}
		if #match > 0 then
			if pattern:find(")$", 0, 1) then
				return false
			else
				break
			end
		end
	end

	local instance_pattern = pattern:sub(1,-2) .. "/([^/]+)$"

	local handlers_sz = #self.application.handlers
	for i = 1, handlers_sz do
		local handler = self.application.handlers[i]
		local pattern = handler[1]

		if pattern == instance_pattern then
			return true
		end

	end

	return false
end

--- Inherited modules can use this function to check if the incoming request is targetting a Redfish singleton
--- This check is done by looking at the pattern used to route the request and making sure it does follow a collection or instance URL pattern
--- If this function returns false, the target resource may be an instance, singleton, settings object, OR action URL
-- @return boolean is_singleton
function RedfishHandler:is_singleton()

	local path = self.request.path

	local pattern

	local handlers_sz = #self.application.handlers
	for i = 1, handlers_sz do
		local handler = self.application.handlers[i]
		pattern = handler[1]
		local match = {path:match(pattern)}
		if #match > 0 then
			if pattern:find(")$", 0, 1) then
				return false
			else
				break
			end
		end
	end

	local instance_pattern = pattern:sub(1,-2) .. "/([^/]+)$"

	local handlers_sz = #self.application.handlers
	for i = 1, handlers_sz do
		local handler = self.application.handlers[i]
		local pattern = handler[1]

		if pattern == instance_pattern then
			return false
		end

	end

	return true
end

--- Inherited modules can use this function to set all oem extension paths for an incoming request
-- @param collection_path The Collection OEM extension path
-- @param instance_path The Instance OEM extension path
-- @param singleton_path Singleton OEM extension path
-- @param instance_action_path The Action OEM extension path
-- @param instance_link_path The Links OEM extension path
function RedfishHandler:set_all_oem_paths(collection_path, instance_path, singleton_path, instance_action_path, instance_link_path)

	self.oem_collection_path = collection_path
	self.oem_instance_path = instance_path
	self.oem_singleton_path = singleton_path
	self.oem_instance_action_path = instance_action_path
	self.oem_instance_link_path = instance_link_path

end

--- Inherited modules can use this function to get all oem extension paths for an incoming request
-- @return collection_path The Collection OEM extension path
-- @return instance_path The Instance OEM extension path
-- @return singleton_path Singleton OEM extension path
-- @return instance_action_path The Action OEM extension path
-- @return instance_link_path The Links OEM extension path
function RedfishHandler:get_all_oem_paths()

	return self.oem_collection_path, self.oem_instance_path, self.oem_singleton_path, self.oem_instance_action_path, self.oem_instance_link_path

end

--- Inherited modules can use this function to set the oem collection extension path for an incoming request
--- An oem collection extension is a file used to add oem properties to a Redfish collection object
-- @param collection_path The Collection OEM extension path
function RedfishHandler:set_oem_collection_path(collection_path)

	self.oem_collection_path = collection_path

end

--- Inherited modules can use this function to set the oem instance extension path for an incoming request
--- An oem instance extension is a file used to add oem properties to a Redfish instance object
-- @param instance_path The Instance OEM extension path
function RedfishHandler:set_oem_instance_path(instance_path)

	self.oem_instance_path = instance_path

end

--- Inherited modules can use this function to get the oem singleton extension path for an incoming request
--- An oem singleton extension is a file used to add oem properties to a Redfish singleton object
-- @param singleton_path Singleton OEM extension path
function RedfishHandler:set_oem_singleton_path(singleton_path)

	self.oem_singleton_path = singleton_path

end

--- Inherited modules can use this function to set the oem action extension path for an incoming request
--- An oem instance action extension is a file used to extend the "Actions" property of a given Redfish instance
-- @param instance_action_path The Action OEM extension path
function RedfishHandler:set_oem_instance_action_path(instance_action_path)

	self.oem_instance_action_path = instance_action_path

end

--- Inherited modules can use this function to set the oem link extension path for an incoming request
--- An oem instance link extension is a file used to extend the "Links" property of a given Redfish instance
-- @param instance_link_path The Links OEM extension path
function RedfishHandler:set_oem_instance_link_path(instance_link_path)

	self.oem_instance_link_path = instance_link_path

end

--- Inherited modules can use this function to set the oem collection extension path for an incoming request
--- An oem collection extension is a file used to add oem properties to a Redfish collection object
-- @return string Collection OEM extension path
function RedfishHandler:get_oem_collection_path()

	return self.oem_collection_path

end

--- Inherited modules can use this function to set the oem instance extension path for an incoming request
--- An oem instance extension is a file used to add oem properties to a Redfish instance object
-- @return string Instance OEM extension path
function RedfishHandler:get_oem_instance_path()

	return self.oem_instance_path

end

--- Inherited modules can use this function to get the oem singleton extension path for an incoming request
--- An oem singleton extension is a file used to add oem properties to a Redfish singleton object
-- @return string Instance OEM extension path
function RedfishHandler:get_oem_singleton_path()

	return self.oem_singleton_path

end

--- Inherited modules can use this function to get the oem instance action extension path for an incoming request
--- An oem instance action extension is a file used to extend the "Actions" property of a given Redfish instance
-- @return string Action OEM extension path
function RedfishHandler:get_oem_instance_action_path()

	return self.oem_instance_action_path

end

--- Inherited modules can use this function to get the oem instace links extension path for an incoming request
--- An oem instance links extension is a file used to extend the "Links" property of a given Redfish instance
-- @return string Links OEM extension path
function RedfishHandler:get_oem_instance_link_path()

	return self.oem_instance_link_path

end

-- This provides a safer version of turbo.web.RequestHandler:get_json()
-- @treturn request_body decoded JSON body of the incoming HTTP request (or nil if there is none)
local _get_json = RedfishHandler.get_json
function RedfishHandler:get_json()
	if self:get_request() then
		return _get_json(self)
	end
end

--- Inherited modules can use this function to mark the session as unauthorized
-- @param msg optional Sets an optional message
function RedfishHandler:unauthorized(msg)
	--[[if finished then
		return
	end--]]

	self:add_header("WWW-Authenticate", 'Basic realm="AMI_Redfish_Server"') --TODO make the realm unique
	self:add_header("WWW-Authenticate", 'X-Auth-Token realm="AMI_Redfish_Server"') --TODO make the realm unique

	self:error_access_denied()
end

--- Inherited modules can use this function to create a Redfish compatible Message for ExtendedInfo
-- @param Registry MessageRegistry to use
-- @param MessageId MessageId from the MessageRegistry
-- @tparam table RelatedProperties To be added to the RelatedProperties
-- @tparam table MessageArgs To be added to the MessageArgs property
-- @return Message Compatible with Redfish Message
function RedfishHandler:create_message(Registry, MessageId, RelatedProperties, MessageArgs)
	local MsgReg = MessageRegistries[Registry]
	if MsgReg == nil then
        local success
        success, MsgReg = pcall(dofile, "message_registries/" .. Registry .. ".lua")
		if not success then
            turbo.log.error("In create_message(): Message Registry: '" .. Registry .. "' not found!")
    		return nil
        end
	end
	local MsgTemplate = MsgReg.Messages[MessageId]
	
	if type(RelatedProperties) == "string" then
		RelatedProperties = RelatedProperties:split(",")
	end

	if type(MessageArgs) == "string" then
		MessageArgs = MessageArgs:split(",")
	elseif type(MessageArgs) == "number" then
		MessageArgs = {MessageArgs}
	end

	local MessageArgsCount = MessageArgs and #MessageArgs or 0
	if MessageArgsCount ~= MsgTemplate.NumberOfArgs then
		turbo.log.warning("In create_message(): Wrong number of MessageArgs provided")
	end

	for i=1,MsgTemplate.NumberOfArgs do
		if type(MessageArgs[i]) ~= MsgTemplate.ParamTypes[i] then
			turbo.log.error("In create_message(): MessageArg #"..i..
							" - Expected '"..MsgTemplate.ParamTypes[i]..
							"', but found '"..type(MessageArgs[i]).."'")
		end
	end

	local replacer = function(arg) 
						local i = tonumber(arg:sub(2))
						return MessageArgs and MessageArgs[i] or whole 
					 end

	local message = string.gsub(MsgTemplate.Message, "(%%%d+)", replacer)

    local reg_id = MsgReg.Id:match("(.-%.%d+%.%d+)")
	return {
		["@odata.type"] = "/redfish/v1/$metadata#" .. CONSTANTS.MESSAGE_TYPE,
		MessageId = reg_id ..".".. MessageId,
		Message = message,
		RelatedProperties = RelatedProperties,
		MessageArgs = MessageArgs,
		Severity = MsgTemplate.Severity,
		Resolution = MsgTemplate.Resolution
	}
end

function RedfishHandler:add_error_body(res, status, ...)
	-- Set response's status code
	self:set_status(status)

	
	local msg = {}
	if select("#",...) > 1 or (res.error and res.error and #res.error["@Message.ExtendedInfo"] > 0) then
		msg = RedfishHandler:create_message("Base", "GeneralError")
	else
		msg = ...
	end

	res.error = res.error or {}
	res.error.code = msg.MessageId
	res.error.message = msg.Message

	-- Create the ExtendedInfo array, add any Messages passed by caller
	res.error["@Message.ExtendedInfo"] = res.error["@Message.ExtendedInfo"] or {}
	utils.array_merge(res.error["@Message.ExtendedInfo"], {...})
	-- Add the odata type for ExtendedInfo
	-- res["@odata.type"] = "#ExtendedInfo.1.0.0.ExtendedInfo"
	-- Include OData-Version header with response
	self:set_header("OData-Version", "4.0")

	return res
end

--- must be used on all POST/PUT/PATCH handling
-- database access can be done on an existing redis pipeline passed as an arg
-- or a newly created pipeline will be used by default
-- depth argument can be used to limit how far the update will propagate, by default
-- all LastModified entries will be updated all the way up to the Service Root
function RedfishHandler:update_lastmodified(scope, timestamp, pipeline, depth)
	if timestamp == nil then
		timestamp = os.time()
	end
	local tscope = scope:split(":")
	local pl = pipeline or self.redis:pipeline()
    local limit = #tscope - (depth or #tscope)
    while #tscope > limit do
		pl:set(table.concat(tscope, ":") .. ":LastModified", timestamp)
		table.remove(tscope)
	end
	if not pipeline then
		yield(pl:run())
	end
end

--- Function to set the scope the resource.
-- @param scope Redis namespaced key property that the current handler is handling
function RedfishHandler:set_scope(scope)
	self.scope = scope
end

--- Function to get the Scope of the resouces.
-- @return scope Redis namespaced key property
function RedfishHandler:get_scope()
	return self.scope
end

--- Function to get the redis database.
-- @return Redis Database
function RedfishHandler:get_db()
	return self.redis
end

--- Function to add oem extension properties to the response.
-- @param table Response table.
-- @param oem_path 
-- @return utils.recursive_table_merge Response table after mergind oem extensionproperties.
function RedfishHandler:oem_extend(table, oem_path)

	-- if oem file does not exist return same table
	-- if not os.rename(oem_path .. ".lua", oem_path .. ".lua") then
	local oem_dirs = utils.get_oem_dirs()

	local oem_table = {}

	for oi, on in ipairs(oem_dirs) do
		local oem_exists, oem_file = pcall(require, on .. '.' .. oem_path)
		local temp_table
		if not oem_exists then
			turbo.log.notice("No OEM extension found " .. oem_path)
		else 
			local oem_req_time = os.time()

			if type(oem_file) == "table" then
				temp_table = oem_file
			elseif type(oem_file) == "function" then
				-- oem_table = oem_file(self.application, self.request)
				temp_table = oem_file(self)
			end

			if type(temp_table) == "table" then
				oem_table = utils.recursive_table_merge(oem_table, temp_table)
			end
			
			turbo.log.notice("OEM response time for ".. oem_path .." : " .. tostring(os.time() - oem_req_time) .. "s")
		end

	end


	return utils.recursive_table_merge(table, oem_table)

end

--- Function to set the Authentication mode.
-- @param mode Mode of Authentication
function RedfishHandler:set_auth_mode(mode)
	self.auth_mode = mode
end

--- Function to get the Authentication mode.
-- @return auth_mode Mode of Authentication.
function RedfishHandler:get_auth_mode()
	return self.auth_mode
end

--- Function that provides a generic mechanism for asserting the incoming properties during HTTP PATCH
--It creates the error message according to Redfish Error/ExtendedError schema and add it to response, if there is an error
--If not the assertion succeeded
function RedfishHandler:assert_patch(response, known_properties, writable_properties)

	local request_data = self:get_json()

	local incoming_known, incoming_unknown = utils.intersect_and_diff(request_data, known_properties)

	local error_msgs = {}

	local assertion = nil

	for ikk, ikv in pairs(incoming_known) do
		if not turbo.util.is_in(ikv, writable_properties) then
			table.insert(error_msgs, self:create_message("Base", "PropertyNotWritable", {'#/'..ikv}, {ikv}))
		end
	end

	for iuk, iuv in pairs(incoming_unknown) do
		table.insert(error_msgs, self:create_message("Base", "PropertyUnknown", {'#/'..iuv}, {iuv}))
	end


	if #error_msgs > 0 then

		self:add_error_body(response, 400, unpack(error_msgs))

		assertion = false

	else

		assertion = true

	end

	return assertion

end

local resp = turboredis.resp

--- This function is a modified version of turboredis.pipeline._run that adds a redis transaction (MULTI/EXEC)
--block around the pipeline commands to ensure database access is atomic
-- @param self Self object
-- @param callback Callback function
-- @param callback_arg Callback Arguments.
local _run_with_transaction = function(self, callback, callback_arg)
    self.running = true
    -- Don't re-create the buffer if the user is reusing
    -- this pipeline
    if self.buf == nil then
        -- FIXME: This should probably be tweaked/configurable
        self.buf = turbo.structs.buffer(128*#self.pending_commands)
    end
    -- surround pipeline commands with MULTI/EXEC to make it a transaction block
    self.buf:append_luastr_right(resp.pack({"MULTI"}))
    for i, cmdt in ipairs(self.pending_commands) do
        local cmdstr = resp.pack(cmdt)
        self.buf:append_luastr_right(cmdstr)
    end
    self.buf:append_luastr_right(resp.pack({"EXEC"}))
    self.con.stream:write_buffer(self.buf, function ()
        local replies = {}
        local multi_res = yield(task(resp.read_resp_reply, self.con.stream, false))
        if not multi_res[1] then
            turbo.log.notice(turbo.log.stringify(multi_res, "MULTI"))
        end
        for i, v in ipairs(self.pending_commands) do
            local res = yield(task(resp.read_resp_reply,
                self.con.stream, false))
            if not res[1] then
                turbo.log.error("Error while adding command to redis transaction:")
                turbo.log.error(res[2])
                turbo.log.error(turbo.log.stringify(v, "Command"))
            end
        end
        local replies = yield(task(resp.read_resp_reply, self.con.stream, false))
        self.running = false
        if callback_arg then
            callback(callback_arg, replies)
        else
            callback(replies)
        end
    end)
end

--- Function to check the client certificate.
-- @param client_cert Path of the client certificate.
function RedfishHandler:check_client_cert(client_cert)
    local stat = posix.stat or posix.sys.stat.stat
	local ca_stat = stat(CONFIG.CA_CERT_PATH)
	if ca_stat and ca_stat.mtime ~= ca_cert_mtime then
    	ca_cert = nil
    	ca_cert_mtime = ca_stat.mtime
	end

    if not ca_cert then
        local ca_file_contents = utils.read_from_file(CONFIG.CA_CERT_PATH)
        if ca_file_contents then
            local bio
			
			bio = lssl.BIO_new(lssl.BIO_s_mem())
            lssl.BIO_puts(bio, ffi.cast("char*", ca_file_contents))
            ca_cert = lssl.PEM_read_bio_X509(bio, nil, nil, nil)

            lssl.BIO_free_all(bio)
        end
    end

    if ca_cert then
        lssl.OPENSSL_add_all_algorithms_noconf()
        local bio
        local x509_client_cert

        bio = lssl.BIO_new(lssl.BIO_s_mem())
        lssl.BIO_puts(bio, ffi.cast("char*", client_cert))
        x509_client_cert = lssl.PEM_read_bio_X509(bio, nil, nil, nil)

        if x509_client_cert then
            local store
            local ctx

            store = lssl.X509_STORE_new();
            lssl.X509_STORE_add_cert(store, ca_cert)

            ctx = lssl.X509_STORE_CTX_new()
            lssl.X509_STORE_CTX_init(ctx, store, x509_client_cert, nil)

            local ret = lssl.X509_verify_cert(ctx)

            lssl.BIO_free_all(bio)
            lssl.X509_STORE_CTX_free(ctx);
            lssl.X509_STORE_free(store);
            lssl.X509_free(x509_client_cert);
            collectgarbage()
            if tonumber(ret) ~= 1 then
            	self:unauthorized()
            end

            --print("cert results", tonumber(ret))
        else
            lssl.BIO_free_all(bio);
            self:unauthorized()
            collectgarbage()
        end
    else
        self:unauthorized()
    end
end

---- Redefine this method if you want to do something after the class has been initialized.
-- This method unlike on_create, is only called if the method has been found to be supported.
function RedfishHandler:prepare()
	if not ODataHandler.prepare(self) then
		return
	end
	
	finished = false

	local content_type = self.request.headers:get("Content-Type", true)
	local content_length = self.request.headers:get("Content-Length", true)
	
	if(self.request.method == "POST" or  self.request.method == "PATCH" or  self.request.method == "PUT") then
		if(content_type ~= nil and string.find(content_type,"application/json")) then
			local success, request_body

			-- if body less than 1 MB
			if content_length and tonumber(content_length) < 1048576 then
				success, request_body = pcall(turbo.escape.json_decode, self:get_request().body)
			else 
			-- if greater than 1 MB
				request_body = {}
				success = utils.jsonc_validate(self:get_request().body)
			end
	
			if not success or type(request_body) ~= "table" then
				self:error_unrecognized_request_body()
				return
			end
		else
		   print("Content Type is other than application/json")
		   self:error_unsupported_media_type(content_type or "missing")
		end 
	end

	-- Validate the incoming URL
	if(string.find(self:get_request().path, ":")) then
		self:assertTrue_404(false)
	end
	print("create turboredis")
	self.redis = turboredis.Connection:new(CONFIG.redis_sock, 0, {family=turbo.socket.AF_UNIX}); print("got redis connect", self.redis)
	if not yield(self.redis:connect()) then
		error(turbo.web.HTTPError:new(500, "DB is busy"))
	end

	if CONFIG.TRANSACTIONS_ENFORCED then
		-- To make sure database get/set is atomic, we extend turboredis to always use MULTI/EXEC transaction blocks within pipelines
		local _init_pipeline = self.redis.pipeline
		self.redis.pipeline = function(self)
			local PipeLine = _init_pipeline(self)

			PipeLine._runNoTransaction = PipeLine._run
			PipeLine.runNoTransaction = function(self, callback, callback_arg)
			    if self.running then
			        error("Pipeline already running")
			    end
			    if callback then
			        return self:_runNoTransaction(callback, callback_arg)
			    else
			        return task(self._runNoTransaction, self)
			    end
			end

			PipeLine._run = tr_mods._pipeline_run_with_transaction

			return PipeLine
		end
	end

	-- TODO: Session Handling
	-- Support both basic and Redfish Session Login Authentication
	-- Must NOT use Cookies for authentication

	-- Basic auth must be validated using Authorization token. And this must not require client to create a session using SessionService
	-- Can happen at any URL
	-- Refer RFC2617

	self.request.headers.http_parser_url = nil
	local path = self.request.headers:get_url_field(turbo.httputil.UF.PATH)
	path = string.gsub(path, CONFIG.SERVICE_PREFIX, "")

    if path ~= "" and path ~= "/redfish" and path ~=  "/" and string.find(path, "$metadata") == nil and path ~= "/SessionService/Sessions" or (path == "/SessionService/Sessions" and self:get_request().method ~= "POST") then

    	-- All external requests will have the X-Forwarded-For header. Because of this, the Redfish service can check for the presence of
    	-- the X-Forwarded-For header and only do the authentication if it is present. This will allow the Redfish service to authenticate
    	-- external requests and not authenticate in-band requests.
    	local ip_header = self:get_request().headers:get("X-Forwarded-For")
    	
    	if ip_header then
	    	local full_header = self:get_request().headers.hdr_str;
	    	local cert_header = string.match(full_header,"-----BEGIN CERTIFICATE-----.*-----END CERTIFICATE-----")
	    	local client_cert = nil
	    	if cert_header then
	    		client_cert = string.gsub(cert_header, "\t","") .. "E-----"
	    	end
    		--local client_cert = self:get_request().headers:get("X-Client-Certificate")
    		--print(client_cert)
            if client_cert then
            	local cert_user = self:get_request().headers:get("X-Username")
            	if string.find(cert_user,"/CN=") then
            		cert_user = string.match(cert_user, "([a-zA-Z0-9_]+)/")
            	end
    			
            	if not cert_user then
            		self:unauthorized()
            	end

            	client_cert = client_cert:gsub("\\", "\n")
            	self:check_client_cert(client_cert)
            	self:set_auth_mode(self.CERT_AUTH)
            	if self:check_login(cert_user) == true then
    				self.user_id = self:get_user_id(cert_user)
    				self.username = cert_user
    				self.role = self:get_user_role(self.user_id)
    				self:add_audit_log_entry(self:create_message("Security", "AccessAllowed", nil, {path}))
    			else
    				self:unauthorized()
    			end

            else
                local auth = self.request.headers:get("Authorization")
                local username
                if auth ~= nil then
                    if string.upper(string.sub(auth, 1, 5)) == string.upper(self.BASIC_AUTH) then
                        local token = string.sub(auth, 7)
                        local user, pass = unpack(base64.from_base64(token):split(":"))

                        self:set_auth_mode(self.BASIC_AUTH)
                        if self:check_login(user, pass) == true then
                            self.user_id = self:get_user_id(user)
                            local session_id = self:get_session_id()
							local Is_Enabled = yield(self:get_db():get("Redfish:AccountService:Accounts:" .. self.user_id .. ":Enabled"))
							if Is_Enabled == "false" then 
								self:error_access_denied()
							else
								self.username = user
								self.role = self:get_user_role(self.user_id)
							end
						else
                            self:unauthorized()
                        end
                    end
                -- Must block all unauthorized GET operations except
                    -- -- Root Object
                    -- -- $metadata
                    -- -- OData Root Object
                    -- -- Version object at /redfish
                elseif(self.request.headers:get("X-Auth-Token") == nil) then
                    self:unauthorized()
                    return
                else
                    self:set_auth_mode(self.SESSION_AUTH)
                end

                -- Tracking time of last request
                local session_id = nil
                local auth_type = self:get_auth_mode()
                if auth_type == self.SESSION_AUTH or (auth_type == self.PAM_AUTH and self.request.headers:get("X-Auth-Token") ~= nil) then
                    session_id = self:get_session_id()
                    if session_id ~= nil then
                        local db = self:get_db()
                        local session_timeout = yield(db:get("Redfish:SessionService:SessionTimeout"))
                        local pl = db:pipeline()
                        local session_keys = yield(db:keys("Redfish:SessionService:Sessions:" .. session_id .. ":*"))
                        for _key_i, sess_key in pairs(session_keys) do
                        	pl:expire(sess_key, session_timeout)
                        end
                        yield(pl:run())

                        self.username = yield(db:get("Redfish:SessionService:Sessions:" .. session_id .. ":UserName"))
                        local user_id = self:get_user_id(self.username)
                        if user_id == nil then
                        	self.role = yield(db:get("Redfish:SessionService:Sessions:" .. session_id .. ":PamPriv"))
                        else
							self.role = self:get_user_role(user_id)
						end

						if self.role == nil then
							self:unauthorized()
						end
                    else
                        self:unauthorized()
                        return
                    end
                end

                -- Must work on TLS 1.1+ connections only

                -- Redfish Session Login must enforce Session creation using session service
                -- POST /redfish/v1/SessionService/Sessions HTTP/1.1
                -- POST body must be { "UserName": "", "Password": "" }
                -- Save Origin header. Compare it to further requests from same session
                -- Response to Session 
                -- -- X-Auth-Token
                -- -- Location: /redfish/v1/SessionService/Sessions/<new-session> (Client Logout must use this)
                -- -- JSON body of the new session object

                -- Validate Accept: application/json
                -- Validate OData-version: 4.0
                -- Validate X-Auth-Token

                -- Process authorization before sending E-Tag

                -- TODO: ETag Handling
                -- If client sent If-Modified-Since or If-Modified Tag does not differ from current last modified for the scope, send a 304

                -- Create URL Segments for later use
            end
        else
            self:set_auth_mode(self.BASIC_AUTH)
            self.user_id = 0
            self.username = "in-band-user"
            self.role = "Administrator"
            self:add_audit_log_entry(self:create_message("Security", "AccessAllowed", nil, {path}))
        end
    end
  

    -- split the url segments

    self.url_segments = {}

    for segment in string.gmatch(path, "([^/?]+)") do
        table.insert(self.url_segments, segment)
    end

    -- Auto generate redis scope from URL
    self:set_scope("Redfish:" .. table.concat(self.url_segments, ":"))

end

--- Function to check whether resource has been modified or not  and to set the HTTP status to 304 if resource is not modified.
function RedfishHandler:If_Modified()
	if(self.request.headers:get("IF-None-Match")) == ('W/"'..coroutine.yield(self.redis:get(self.scope .. ":LastModified"))..'"') then
		self:set_status(304)
	end
end

--- Function to perform Pam authentication.
-- @param user Username.
-- @param pass Password
function RedfishHandler:check_pam_login(user, pass)
    if not user or not pass then
        return false
    end

    local db = self:get_db()
    local pam = yield(db:get("Redfish:AccountService:PAMEnabled"))
    if not utils.bool(pam) then
        return false
    end

    local wRet
    local priv_map = {
        [1] = "Redfish:AccountService:Roles:ReadOnly", --Callback
        [2] = "Redfish:AccountService:Roles:ReadOnly",   -- User
        [3] = "Redfish:AccountService:Roles:Operator",
        [4] = "Redfish:AccountService:Roles:Administrator"
        --[5] = "Oem",
    }

    if CONFIG.USE_SPX_PAM then
        local pamh = ffi.new("pam_handle_t")
        local usrpriv = ffi.new("usrpriv_t")
        wRet = user_auth.DoPAMAuthentication(ffi.cast("pam_handle_t**", pamh), ffi.cast("char*", user), ffi.cast("char*", pass), usrpriv, ffi.cast("char*", "HTTP"), ffi.cast("char*", self:get_request().headers:get("X-Forwarded-For")), ffi.cast("char*", ""))
        if wRet == 0 then
            local ip_str = self:get_request().host
            local server_in6 = ffi.new("struct in6_addr")
            local ip = ffi.new("char[32]", ip_str)
            local ret = ffi.C.inet_pton(10, ip, server_in6)
            local  BMCIPAddr = ffi.new("unsigned char[16]")

            if ret == 0 then
                ret = ffi.C.inet_pton(2, ip, BMCIPAddr)
                if ret == 0 then
                    return -1
                end
            else
                if ip_str:match("^::[fF][fF][fF][fF]:[0-9][0-9]?[0-9]?%.[0-9][0-9]?[0-9]?%.[0-9][0-9]?[0-9]?%.[0-9][0-9]?[0-9]?$") then
                        ip_str = ip_str:sub(8)
                        ip = ffi.new("char[32]", ip_str)
                        ret = ffi.C.inet_pton(2, ip, BMCIPAddr)
                else
                        ffi.C.memcpy(BMCIPAddr, server_in6.in6_u.u6_addr8, 16)
                end
            end

            self.pam_priv = priv_map[user_priv_lib.GetUsrLANChPriv(usrpriv, ffi.cast("char*", BMCIPAddr))]
            self:set_auth_mode(self.PAM_AUTH)
        end


    else
        -- Use https://github.com/devurandom/lua-pam library
    end

    return wRet == 0 and self.pam_priv ~= nil
end

--- Function to get the url segments.
-- @return url_segments Table
function RedfishHandler:get_url_segments()
	return self.url_segments
end

--- Function  to set the odata type.
-- @param type String
function RedfishHandler:set_type(type)
	self.collection_type = type
	ODataHandler.set_type(self, "#" .. type)
end

--- Function to set link header in response.
-- @param URI URI string.
-- @param Links it may be string or table.
function RedfishHandler:set_link_header(URI, Links)
	if type(URI) == 'string' then
		self:add_header("Link", URI .. '; rel=describedby')
	end

	if type(Links) == 'string' then
		self:add_header("Link", Links)
	elseif type(Links) == 'table' and #Links > 0 then
		for _i, link in pairs(Links) do
			self:add_header("Link", link)
		end
	end
end

--- Handler to set collection property.
-- @param prop 
function RedfishHandler:set_collection_property(prop)
	self.collection_property = prop
end

--- Function to set allow property in response headers for a given resource URI.
-- @param list Table containing allow methods.
function RedfishHandler:set_allow_header(list)
	if type(list) == "table" then
		list = table.concat(list, ", ")
	end
	self:set_header("Allow", list)
end

--- Sets the response data
-- This function can be used or overridden in inherited modules
-- @tparam table chunk Response data to be sent to client
function RedfishHandler:set_response(chunk)

	--do the magic only if it is table. If it is string simply set request handler
	if type(chunk) ~= "table" then
		turbo.log.error("Invalid response data")
		return
	end	

	-- If $skip or $top are specified for a collection response, trim the collection property accordingly
	if self.current_type:find("Collection") then
		if chunk[self.collection_property] then
			chunk[self.collection_property] = self:do_skip_top(chunk[self.collection_property])
			if chunk[self.collection_property .. "@odata.count"] and (chunk[self.collection_property .. "@odata.count"] - (self.query_parameters.skip or 0)) > CONFIG.DEFAULT_COLLECTION_LIMIT and (self.query_parameters.top == false or (self.query_parameters.top ~= false and tonumber(self.query_parameters.top) > CONFIG.DEFAULT_COLLECTION_LIMIT)) then
				local path = self:get_request().path
				local skip_param = "?$skip=" .. (self.query_parameters.skip or 0) + CONFIG.DEFAULT_COLLECTION_LIMIT
				local top_param = self.query_parameters.top ~= false and "&$top=" .. (self.query_parameters.top - CONFIG.DEFAULT_COLLECTION_LIMIT) or ""
				chunk[self.collection_property .. "@odata.nextLink"] = path .. skip_param .. top_param
			end
		end
	else
		if self.query_parameters.skip or self.query_parameters.top then
			self:error_query_not_supported_on_resource()
		end
	end

	_.extend(self.response_table, chunk)

	if self.actions and utils.table_len(self.actions) > 0 then
		self.response_table["Actions"] = self.actions
	end

	ODataHandler.set_response(self, chunk)

end

--- Handler to set flag which determines whether $skip/$top need to be processed by RedfishHandler.
-- Used to prevent $skip/$top from being processed twice in special cases (such as Log Entry Collection)
-- @param collection Collection property
function RedfishHandler:set_skip_top_flag(collection)
	-- This flag determines whether $skip/$top need to be processed by RedfishHandler
	-- Used to prevent $skip/$top from being processed twice in special cases (such as Log Entry Collection)
	self.skip_top_flag = true
end

--- Function to set flag which determines whether $skip/$top need to be processed by RedfishHandler.
-- Used to prevent $skip/$top from being processed twice in special cases (such as Log Entry Collection)
-- @param collection Collection property
function RedfishHandler:clear_skip_top_flag(collection)
	-- This flag determines whether $skip/$top need to be processed by RedfishHandler
	-- Used to prevent $skip/$top from being processed twice in special cases (such as Log Entry Collection)
	self.skip_top_flag = false
end

--- Function to skip the Log entry collection.
-- @param collection Collection property
function RedfishHandler:do_skip_top(collection)
	if self.skip_top_flag then
		local skip = self.query_parameters.skip or 0
		local top = self.query_parameters.top or #collection
		return _.slice(collection, skip + 1, top)
	else
		return collection
	end
end

--- Function to set the Etag when value of property is changed for each resources.
function RedfishHandler:set_etag()
	local Initial_timestamp = coroutine.yield(self.redis:get("Redfish:LastModified"))-- tostring(utils.fileTime('usr/local/'))
	self.last_modified = coroutine.yield(self.redis:get(self.scope .. ":LastModified"))
	if(self.last_modified == nil) then
		self.last_modified = Initial_timestamp
		coroutine.yield(self.redis:set(self.scope .. ":LastModified", self.last_modified))
	end
	self:set_header("ETag", "W/\"" .. self.last_modified .. "\"")
	self:If_Modified()	
end

--- Function to add action property in response.
-- @param action_table action Table
function RedfishHandler:add_action(action_table)

	self.actions = self.actions or {}

	for i, a in pairs(action_table) do
		-- If target is valid, add it to the application url handler
		-- if a['target'] ~= nil then
		-- 	self.application:add_handler(a['target'], self)
		-- end
		
		self.actions[i] = a
	end
end

--- Function to add oem action property in action table.
-- @param action_table action Table
function RedfishHandler:add_oem_action(action_table)

	self.actions = self.actions or {}
    self.actions["Oem"] = self.actions["Oem"] or {}
	for i, a in pairs(action_table) do
		-- If target is valid, add it to the application url handler
		-- if a['target'] ~= nil then
		-- 	self.application:add_handler(a['target'], self)
		-- end
		
		self.actions["Oem"][i] = a
	end
end

--- Function to set output response to the client.
function RedfishHandler:output()

	--TODO: Redfish specific vars added

	--TODO: 6.5.1.1 Add link header with rel=describedby that points to source json schema for all HEAD and GET calls

	-- Allow Access Control Policy. Redfish 1.0 spec does not make any recommendation. So this will be OEM choice
	self:set_header("Access-Control-Allow-Origin", "*")
	self:set_header("Access-Control-Expose-Headers", "X-Auth-Token")
	self:set_header("Access-Control-Allow-Headers", "X-Auth-Token")
	self:set_header("Access-Control-Allow-Credentials", "true")

	self:set_header("Cache-Control", "no-cache, must-revalidate")


	-- Add Link header, pulling URLs from the "Links" property (if it exists)
	local schema_uri, links_table
	if self.collection_type then
		if CONSTANTS.SCHEMA_URIS[self.collection_type] ~= nil then
			schema_uri = CONSTANTS.SCHEMA_URIS[self.collection_type]
		else
			turbo.log.error("Schema URI missing for type " .. self.collection_type)
		end
	end

	links_table = {}
	if type(self.response_table) == "table" then
		local type_links = {}
		
		utils.getAnnotationLinks(self.response_table, type_links)
		for _i, link in pairs(type_links) do
			if CONSTANTS.SCHEMA_URIS[link] ~= nil then
				table.insert(links_table, CONSTANTS.SCHEMA_URIS[link])
			else
				turbo.log.error("Schema URI missing for type " .. link)
			end
		end

		local resource_links = {}
		utils.getResourceLinks(self.response_table, resource_links)
		for _i, link in pairs(resource_links) do
			table.insert(links_table, "<" .. link["uri"] .. ">; path=" .. link["path"])
		end
	end

	self:set_link_header(schema_uri, links_table)

	if self.request.headers:get_method() ~= "DELETE" then
		if not pcall(self.set_etag, self) then
			error({message = "Error setting ETag. Make sure you did a set_scope", code = Error.POSSIBLE_ETAG_ERROR})
		end
	end

	ODataHandler.output(self)

end

--- Handler to set gzip output response to the client.
function RedfishHandler:gzip_output()

	--TODO: Redfish specific vars added

	--TODO: 6.5.1.1 Add link header with rel=describedby that points to source json schema for all HEAD and GET calls

	-- Allow Access Control Policy. Redfish 1.0 spec does not make any recommendation. So this will be OEM choice
	self:set_header("Access-Control-Allow-Origin", "*")
	self:set_header("Access-Control-Expose-Headers", "X-Auth-Token")
	self:set_header("Access-Control-Allow-Headers", "X-Auth-Token")
	self:set_header("Access-Control-Allow-Credentials", "true")
	self:set_header("Cache-Control", "no-cache, must-revalidate")
	self:set_header("Content-Encoding", "gzip")
	self:set_header("Content-Type", "application/json")
	self:set_header("OData-Version", "4.0")

    self:finish()
end

--- Function to read the user role.
-- @param user_id user ID
-- @return string 
function RedfishHandler:get_user_role(user_id)
    return self.pam_priv or self:get_user_key(user_id, "Role")
end

--- Function to create session based on session id and auth token.
-- @param session_id 
-- @param x_auth_token 
-- @param ... 
-- @return Status
function RedfishHandler:create_session(session_id, x_auth_token, ...)
	if session_id == nil or x_auth_token == nil then
		print ("Invalid session")
		self:unauthorized()
		return
	end

	-- set ... args as session table
	local db = self:get_db()
	local timeout = yield(db:get("Redfish:SessionService:SessionTimeout"))
	yield(db:setex("Redfish:SessionService:Sessions:" .. session_id .. ":Token", timeout, x_auth_token))
	-- Update last modified so that E-Tag can respond properly
	self:update_lastmodified("Redfish:SessionService:Sessions", os.time())

	return true
end

--- Function to get the session Id.
-- @return String Session Id
function RedfishHandler:get_session_id()
	if self:get_auth_mode() == self.SESSION_AUTH then
		local token = self:get_auth_token()
		if token == nil then
			return
		end
		if string.match(token, ":") then
			self:error_insufficient_privilege()
		end
		local token_keys = yield(self.redis:keys("Redfish:SessionService:Sessions:*:Token"))
		for _i, sess_key in pairs(token_keys) do
			local db_token = yield(self.redis:get(sess_key))
			if token == db_token then
				return sess_key:match("Redfish:SessionService:Sessions:(.*):Token")
			end
		end
	elseif self.user_id ~= nil then
		return "basic_" .. self.user_id
	end
end

--- Function to get the session Table based on session id.
-- @param session_id 
-- @return Table Session Table
function RedfishHandler:get_session_table(session_id)

	if session_id == nil then
	        local X_Auth_Token = self.request.headers:get("X-Auth-Token", true)

		if X_Auth_Token ~= nil then
			self:set_auth_mode(self.SESSION_AUTH)
		end

		session_id = self:get_session_id()
	end

	if session_id == nil then
		print ("Invalid session")
		return
	end

	local data = utils.read_from_file(CONFIG.SESSION_PATH .. session_id)
	if data ~= nil then
		return turbo.escape.json_decode(data)
	end

end

---  Function to get the token based on session id.
-- @param session_id 
-- @return string token  
function RedfishHandler:get_auth_token(session_id)
	local token = nil

	if session_id == nil then
		token = self.request.headers:get("X-Auth-Token", true)
	else 
		--local tokens = turboredis.util.from_kvlist(yield(self.redis:hgetall("Redfish:SessionService:Sessions")))
		local session_keys = yield(self.redis:keys("Redfish:SessionService:Sessions:*:Token"))
		for k,v in pairs(session_keys) do
			local db_sess_id = v:match("Redfish:SessionService:Sessions:(.*):Token")
			if db_sess_id == session_id then
				token = yield(self.redis:get(v))
				break
			end
		end
	end
	
	if token == "undefined" then
		token = nil
	end

	return token
end

--- Function to remove the session based in session id.
-- @param session_id 
function RedfishHandler:destroy_session(session_id)
	local token = self:get_auth_token(session_id)
	self:assertTrue_404(token)
	self:update_lastmodified("Redfish:SessionService:Sessions", os.time())
	self:on_logout(session_id)

	return yield(self.redis:del(unpack(yield(self.redis:keys("Redfish:SessionService:Sessions:" .. session_id .. ":*")))))
end

--- Function to get user id based in username.
-- @param username 
-- @return number user_id 
function RedfishHandler:get_user_id(username)

	local user_id = nil
	local user_keys = yield(self:get_db():keys("Redfish:AccountService:Accounts:*:UserName"))
	for k, v in ipairs(user_keys) do
		local user = yield(self:get_db():get(v))
		if user == username then
			local tbl = v:split(":")
			user_id = table.remove(tbl, #tbl - 1)
		end
	end

    if user_id == nil and self:get_auth_mode() == self.PAM_AUTH then
        user_id = username
    end

    return user_id

end

--- Function to get  the user key based on user id and Key.
-- @param user_id user ID
-- @param key
function RedfishHandler:get_user_key(user_id, key)
	if string.find(user_id, ":") or string.find(key, ":") then
		self:error_insufficient_privilege()
	end

	return yield(self:get_db():get("Redfish:AccountService:Accounts:" .. user_id .. ":" .. key))
end

function RedfishHandler:can_user_do(privilege)
	local role = self.role
	if role == nil then
		return
	end

	if not self:get_request().headers:get("X-Forwarded-For") then
		return true
	end

	local user_priv = yield(self:get_db():smembers(role .. ":AssignedPrivileges"))
	local oem_priv = yield(self:get_db():smembers(role .. ":OemPrivileges"))

	for k, v in pairs(oem_priv) do
		table.insert(user_priv, v)
	end
	return turbo.util.is_in(privilege, user_priv) == true
end

--- Function to check the username and password valid or not.
-- @param username 
-- @param password
function RedfishHandler:check_login(username, password)
	if self:check_pam_login(username, password) then
        return true
    end
	-- TODO see if all db lua scripts can be moved to script files

	-- Validate Session Login
	-- Commented in favor of Redis Lua script which is much faster
	local login_result = 0
	local db = self:get_db()
	local user_keys = yield(db:keys("Redfish:AccountService:Accounts:*:UserName"))

	for k, v in ipairs(user_keys) do
		local user = yield(db:get(v))
		if user == username then
			local tbl = v:split(":")
			local id = tostring(table.remove(tbl, #tbl - 1))
			local lockout_threshold = tonumber(yield(db:get("Redfish:AccountService:AccountLockoutThreshold")))
			local lockout_duration = tonumber(yield(db:get("Redfish:AccountService:AccountLockoutDuration")))
			local lockout_reset = tonumber(yield(db:get("Redfish:AccountService:AccountLockoutCounterResetAfter")))

			-- If any of the lockout fields are equal to 0, then the lockout does not happen
			local lockout_enabled = lockout_threshold ~= 0 and lockout_duration ~= 0 and lockout_reset ~= 0

			if lockout_enabled then
				local locked = yield(db:get("Redfish:AccountService:Accounts:" .. id .. ":Locked"))
				if utils.bool(locked) then
					self:error_login_failure(username, "the number of unsuccessful login attempts has exceeded the set threshold.")
				end
			end

			local enabled = yield(db:get(v:match("(.*):.*") .. ":Enabled"))
			if enabled ~= "true" then
				login_result = 0
			else
				if self:get_auth_mode() == self.CERT_AUTH then
					login_result = 1
				else
					local user_pass_hash = yield(db:get("Redfish:AccountService:Accounts:" .. id .. ":Password"))
					if user_pass_hash == md5.sumhexa(password .. CONFIG.SALT) then
						login_result = 1
						if lockout_enabled then
							yield(db:set("Redfish:AccountService:Accounts:" .. id .. ":Locked", "false"))
							yield(db:del("Redfish:AccountService:Accounts:" .. id .. ":FailedLoginCount"))
						end
					else
						login_result = 0
						if lockout_enabled then
							local num_attempts = yield(db:get("Redfish:AccountService:Accounts:" .. id .. ":FailedLoginCount")) or 0
							if num_attempts and tonumber(num_attempts) + 1 >= lockout_threshold then
								yield(db:setex("Redfish:AccountService:Accounts:" .. id .. ":Locked", lockout_duration, "true"))
								self:error_login_failure(username, "the number of unsuccessful login attempts has exceeded the set threshold. IP has been locked out for " .. lockout_duration .. " seconds.")
							else
								yield(db:setex("Redfish:AccountService:Accounts:" .. id .. ":FailedLoginCount", lockout_reset, tonumber(num_attempts) + 1))
							end
						end
					end
				end
			end
			break
		end
	end
	
	--[[
	local login_result = yield(self.redis:eval([ [
		local user_keys = redis.call("KEYS", KEYS[1])
		for k, v in ipairs(user_keys) do
			local username = redis.call("GET", v)
			if username == ARGV[1] then
				local tbl = {}
				for s in string.gmatch(v, "([^:]+)") do
					table.insert(tbl, s)
				end

				local id = table.remove(tbl, #tbl - 1)
				local user_pass_hash = redis.call("GET","Redfish:AccountService:Accounts:" .. tostring(id) .. ":Password")
				if user_pass_hash == ARGV[2] then
					return user_pass_hash
				else
					return 0
				end
			end
		end
		return 0

	] ], 1, "Redfish:AccountService:Accounts:*:UserName", username, md5.sumhexa(password .. CONFIG.SALT)))
	--]]

	return tonumber(login_result) ~= 0 and true or false
end

--- Called after the end of a request. Useful for e.g a cleanup routine.
function RedfishHandler:on_finish()
	finished = true
	ODataHandler.on_finish(self)

	if (self.request.method == "POST" or self.request.method == "PATCH" or self.request.method == "PUT" or self.request.method == "DELETE") and self:get_status() >= 200 and self:get_status() < 300 then
		self.redis:bgsave()
	end

	if self.redis and not yield(self.redis:disconnect()) then
		-- closing, but log the failure locally
	end

	self.response_table = nil
	self.url_args = nil

	if CONFIG.PROFILING_ENABLED then
		print("Stopped profiling")
		ProFi:checkMemory()
		ProFi:stop()
		ProFi:writeReport("../logs/ProFi/ProfileOf." .. table.concat(self.url_segments, "_") .. ".txt")
	end

	self.url_segments = nil
	self.redis = nil

	collectgarbage("collect")

	if CONFIG.DBG_HANDLER_MEMORY then
		self.lastcount = collectgarbage("count")
		collectgarbage("collect")
		self.memdiff = self.lastcount - self.firstcount
		turbo.log.debug(string.format("Memory used (KB): %.2f (before handler) + %.2f (difference) = %.2f (after handler)", self.firstcount, self.memdiff, self.lastcount))
	end
end

--- provides a convinent and safe way to handle errors in handlers
-- @param status The HTTP status code to send to send to client.
-- @param body Optional message to pass as body in the response.
function RedfishHandler:throw_error(status, body)

	error(turbo.web.HTTPError(status, body))

end


--- Helper function to determine if an incoming Collection URL points to a valid resource.
-- This function takes a Redfish Collection resources's URL and determines if the resource
-- that contains it really exists in the Redfish Service.
-- 	e.g.: parent_exists("/redfish/v1/Managers/1/LogServices") would verify that the Managers/1
--		  resouce actually exists (and therefore should have a LogServices collection)
-- @param URL optional URL pointing to a Redfish collection resource, defaults to the URL that triggered the current RedfishHandler instance
-- @return Boolean true if parent resource exists, else false
function RedfishHandler:parent_exists(URL)
	local URL = URL or self.request.headers:get_url()

	-- convert a resource's URL to its redis key prefix
	URL = URL:gsub("/redfish/v1", "Redfish")
	URL = URL:gsub("%?.+$", "")
	local segments = URL:split("/")
	if segments and #segments then
		segments[#segments] = nil
		URL = table.concat(segments, ":")
	end

	local redis_key = URL .. ":ResourceExists"
	local db_res = yield(self:get_db():get(redis_key))
	local parent_exists = db_res == "true"

	return parent_exists
end

--- Function to validate incoming collection request.
-- @param conditional 
function RedfishHandler:assertTrue_404(conditional)

	if type(conditional) == 'nil' then
		self:error_resource_missing_at_uri()
	end

	if type(conditional) == 'boolean' then
		if conditional then
			return
		else
			self:error_resource_missing_at_uri()
		end
	end

	if type(conditional) == 'number' then
		if conditional > 0 then
			return
		else
			self:error_resource_missing_at_uri()
		end
	end

	if type(conditional) == 'string' then
		if conditional:len() > 0 then
			return
		else
			self:error_resource_missing_at_uri()
		end
	end
end

--- Function to check whether the resource data is found in redis or not.
-- @param resource_data
function RedfishHandler:assert_resource(resource_data)

	if resource_data == nil then
		self:error_resource_missing_at_uri()
	end

	local resource_empty = true

	if type(resource_data) == 'table' then
		for rk, rv in pairs(resource_data) do

			if rv ~= nil and utils.table_len(rv) ~= 0 then
				resource_empty = false
			end

		end
	end

	if resource_empty then
		self:error_resource_missing_at_uri()
	end

end

--- Helper function for trigerring POST operation.
-- @param keys_to_watch Set of keys to subscribe to, supports glob-style patterns
-- @param pl Redish pipeline
-- @param m_timeout Milliseconds until subscription is assumed to have failed
function RedfishHandler:doPOST(keys_to_watch, pl , m_timeout)
	
	local errors
	local pending_keys_to_watch
	local result
	
	errors, pending_keys_to_watch, result = self:RedisKeySpaceNotify(keys_to_watch, pl, m_timeout , "POST")
	
	return errors, pending_keys_to_watch, result
end

--- Helper function for trigerring PATCH operation.
-- @param keys_to_watch Set of keys to subscribe to, supports glob-style patterns
-- @param pl Redish pipeline
-- @param m_timeout Milliseconds until subscription is assumed to have failed
function RedfishHandler:doPATCH(keys_to_watch, pl, m_timeout)
	
	local errors
	local pending_keys_to_watch
	local result
	
	errors, pending_keys_to_watch, result = self:RedisKeySpaceNotify(keys_to_watch, pl, m_timeout, "PATCH")
	
	return errors, pending_keys_to_watch, result
end

--- Helper function for trigerring DELETE operation.
-- @param keys_to_watch Set of keys to subscribe to, supports glob-style patterns
-- @param pl Redish pipeline
-- @param m_timeout Milliseconds until subscription is assumed to have failed
function RedfishHandler:doDELETE(keys_to_watch, pl, m_timeout)
	
	local errors
	local pending_keys_to_watch
	local result
	
	errors, pending_keys_to_watch, result = self:RedisKeySpaceNotify(keys_to_watch, pl, m_timeout, "DELETE")
	
	return errors, pending_keys_to_watch, result
end

--- Helper function for trigerring GET operation.
-- @param keys_to_watch Set of keys to subscribe to, supports glob-style patterns
-- @param pl Redish pipeline
-- @param m_timeout Milliseconds until subscription is assumed to have failed
function RedfishHandler:doGET(keys_to_watch, pl, m_timeout)
	
	local errors
	local pending_keys_to_watch
	local result
	
	errors, pending_keys_to_watch, result = self:RedisKeySpaceNotify(keys_to_watch, pl, m_timeout, "GET")
	
	return errors, pending_keys_to_watch, result
end

---
-- Helper function for creating synchronous POST,PATCH or DELETE operation:
-- Sets up a redis subscription for the given keys
-- and pauses execution until a set event (SET, HSET, SADD, etc.) is seen for
-- each key or the wait time exceeds the timeout provided
-- @param keys_to_watch Set of keys to subscribe to, supports glob-style patterns
-- @param pl Redish pipeline
-- @param m_timeout Milliseconds until subscription is assumed to have failed
-- @param http_method Access method
function RedfishHandler:RedisKeySpaceNotify(keys_to_watch, pl , m_timeout , http_method)
	-- Create a redis connection for subscriptions
	local subclient = turboredis.PubSubConnection:new(CONFIG.redis_sock, 0, {family=turbo.socket.AF_UNIX})

	local redisconn = self:get_db()
	
	-- Configure the redis connection and subscribe
	local redis_db_index = 0
	if not yield(subclient:connect()) then
		error(turbo.web.HTTPError:new(500, "Could not connect to redis"))
	end

	yield(subclient:select(redis_db_index))
	yield(subclient:config_set('notify-keyspace-events','KEA'))

	local channels = {}
	local error_channel = {}

	local errors = {}
	local result = {}
	
	local ch_prefix = '__keyspace@'.. redis_db_index ..'__:'

	_.each(keys_to_watch, function(key)
		table.insert(channels, ch_prefix .. key)
		table.insert(error_channel, ch_prefix .. key .. ":ERROR")
		table.insert(error_channel, key .. ":ERROR")
	end)

	-- Create the timeout callback using turbo.IOLoop. If a timeout occurs, break the loop that waits for subscription events,
	-- and unsubscribe to the channels we were listening to.
	local timeleft = true
	local timeout_callback = function ()
		turbo.log.warning("Synchronous ".. http_method .. " operation timed out, resuming HTTP handler...")
		timeleft = false
		yield(subclient:punsubscribe(channels))
		yield(subclient:punsubscribe(error_channel))
	end
	-- Add the timeout callback to turbo.ioloop
	local timeout_ref = turbo.ioloop.instance():add_timeout(turbo.util.gettimemonotonic() + m_timeout, timeout_callback)

	-- We plan to wait until each key in keys_to_watch has been modified, i.e.
	-- until we see a set, hset, sadd, del, hdel, or srem event occurring for the key
	local valid_events = {"set", "hset", "sadd", "del", "hdel", "srem","zadd","zrem", "mset", "hmset", "rename_to"}

	yield(subclient:psubscribe(channels))
	yield(subclient:psubscribe(error_channel))
	
	-- Run any pending database commands.
	local expire_pipe = self:get_db():pipeline()
	if #pl.pending_commands > 0 then
		-- The prefixed keys added to redis by a request should be unique to that request. To make sure data doesn't
		-- conflict with a later request, we'll use the redis EXPIREAT command to invalidate the keys without triggering sync-agent.
		-- Setting keys to EXPIREAT a time that has already passed invalidates them immediately; the EXPIREAT commands are added to a pipeline
		-- that we will execute after the keys are used.
		for _i, cmd in pairs(pl.pending_commands) do
			local cmd_op = cmd[1]
			if _.include(valid_events, cmd_op:lower()) then
				for _i, arg in pairs(cmd) do
					if type(arg) == "string" and arg:match(http_method .. ":") then
						expire_pipe:expireat(arg, "0")
					end
				end
			end
		end

		turbo.log.notice("Setting ".. http_method .. " prefixed keys in Redis...")
		result = yield(pl:run())
		turbo.log.notice("Finished setting ".. http_method .. " prefixed keys in Redis...")
	end
	
	turbo.log.notice("Waiting on ".. http_method .. " operations in sync-agent...")

	while timeleft and #keys_to_watch > 0 do
	
		-- Using turbo.async.task, we create a wrapper that lets us yield to turbo.IOLoop
		-- and resume when a subscription message is recieved
		local msg = yield(task(subclient.read_msg, subclient))
		
		local res = {}
		-- Here we validate the subscription message returned by turbo-redis, if it is a 'pmessage', then it contains
		-- either a keyspace notification about a key being modified or an error message and needs to be handled
		if type(msg) == "table" then
			res.msgtype = msg[1]
		end

		if res.msgtype == 'pmessage' then
			res.pattern = msg[2]
			res.channel = msg[3]
			res.payload = msg[4]

			-- If the message is an error, we remove the corresponding key from keys_to_watch, decode the error object
			-- from subscription message, and store the error in a list. The only assumption about the error message is that it is
			-- passed as an escaped JSON string and should be decoded; the actual structure is left entirely to the user and the
			-- object is inserted blindly into the error list.
			if _.include(error_channel, res.pattern) then
				local watched_key, keyspaced_error, published_error, error_msg, PayLoad

				if res.payload == "set" then
					-- Here we receive an error sent by setting a database key
					watched_key = string.sub(res.pattern, string.len(ch_prefix .. ":"), string.len(res.pattern) - string.len(":ERROR"))
					keyspaced_error = res.pattern
					published_error = watched_key .. ":ERROR"
					PayLoad = yield(redisconn:get(published_error))
					yield(redisconn:del(published_error))
				else
					-- Here we receive an error sent using a redis PUBLISH
					watched_key = string.sub(res.pattern, 1, string.len(res.pattern) - string.len(":ERROR"))
					published_error = res.pattern
					keyspaced_error = ch_prefix .. res.pattern
					PayLoad = res.payload
				end

				keys_to_watch = _.reject(keys_to_watch, function(key) return key == watched_key end)
				error_channel = _.reject(error_channel, function(key) return key == keyspaced_error end)
				error_channel = _.reject(error_channel, function(key) return key == published_error end)

				error_msg = turbo.escape.json_decode(PayLoad)
				table.insert(errors, error_msg)

			else
				-- If the subscription event is one of our keys being modified, we'll mark the key as seen by removing it from keys_to_watch
				local redis_key = string.sub(res.pattern, string.len(ch_prefix)+1)
				if _.include(valid_events, res.payload) then
					keys_to_watch = _.reject(keys_to_watch, function(key) return key == redis_key end)
				end
			end
		end
	end
	turbo.log.notice("Done waiting for ".. http_method .. " operations...")

	if #keys_to_watch > 0 then
		turbo.log.notice("Timeout occured before modifying the following keys:")
		turbo.log.notice(turbo.log.stringify(keys_to_watch, "Remaining keys"))
	else
		turbo.log.notice("Detected an update on all subscribed keys...")
	end

	-- Clean up the data we added to redis by forcing PATCH keys to expire
	yield(expire_pipe:run())

	-- Once we're done waiting, clean up the timeout handler and redis subscription connection we used
	turbo.ioloop.instance():remove_timeout(timeout_ref)
	yield(subclient:disconnect())
	-- We return with the table of error messages collected during the patch operation,
	-- as well as the table of remaining keys_to_watch that timed out (saw no set operation or error message)
	return errors, keys_to_watch, result
end

---
-- Helper function to handle a POST operation in asynchronous manner
-- Post to a process over IPC
-- Post to an oem function which should be handled by task service
-- Post to an external lua script with args
-- Delay and perform a task
-- @param task_name
-- @tparam string op_type LUA_SCRIPT
-- @tparam table ipc_data LUA_SCRIPT program name
-- @tparam table web_request_data Full request data for delayed starting
-- @tparam int wait_time - Seconds to wait before client polls / polling interval
function RedfishHandler:post_task(task_name, op_type, ipc_data, web_request_data, wait_time)
    local redis = self:get_db()
    local prefix = "Redfish:TaskService:Tasks:"
    local new_task_id = yield(redis:zcard(prefix .. "SortedIDs"))
    local response = {}

    local enabled = yield(redis:get("Redfish:TaskService:ServiceEnabled"))
    if enabled == "false" then
    	self:error_service_in_unknown_state()
    end

    if CONFIG.MAX_TASKS and new_task_id >= CONFIG.MAX_TASKS then
        local overwrite_policy = yield(redis:get("Redfish:TaskService:CompletedTaskOverWritePolicy"))

        if overwrite_policy == "Oldest" then
            -- Getting index of most recent entry and incrementing to find index for current entry
            new_task_id = tonumber(yield(redis:zrange(prefix.."SortedIDs", new_task_id - 1, new_task_id - 1, "WITHSCORES"))[2]) + 1

            -- Finding oldest entry and deleting entry from set
            local oldest_key = nil

            -- Looping though tasks looking for the oldest completed task
            for i = 0, new_task_id - 2 do
                local temp_key = yield(redis:zrange(prefix.."SortedIDs", i, i))[1]

                if temp_key and yield(redis:get(temp_key .. ":TaskState")) == "Completed" then
                    oldest_key = temp_key
                    yield(redis:zrem(prefix.."SortedIDs", oldest_key))

                    -- Deleting oldest entry data from database
                    local entry_keys = yield(redis:keys(oldest_key .. ":*"))
                    if entry_keys then
                        yield(redis:del(entry_keys))
                    end

                    break
                end
            end

            -- Sending error if no completed task is found
            if not oldest_key then
                self:error_create_limit_reached_for_resource()
            end
        else
        	-- Sending error if CompletedTaskOverWritePolicy is anything other than "Oldest"
            self:error_create_limit_reached_for_resource()
        end
    else
        new_task_id = new_task_id + 1
    end

    -- Post the new task details to the db
    local pl = redis:pipeline()
    pl:zadd(prefix .. "SortedIDs", new_task_id, prefix .. tostring(new_task_id))
    
    prefix = "Redfish:TaskService:Tasks:" .. new_task_id

    pl:set(prefix ..":Name", task_name)
    pl:set(prefix ..":Description", "Task for " .. tostring(task_name))
    pl:set(prefix ..":TaskState", "New")
    pl:set(prefix ..":TaskType", op_type)
    pl:set(prefix ..":TaskIPCData", ipc_data)
    pl:set(prefix ..":TaskWebRequestData", turbo.escape.json_encode(web_request_data))
    pl:set(prefix ..":WaitTime", tostring(wait_time))
    pl:rpush("Redfish:TaskService:TaskList", new_task_id)

    local result = yield(pl:run())

    -- Starting timer to update the WaitTime key every second
    local ref = turbo.ioloop.instance():set_interval(1000, function()
        local redis = turboredis.Connection:new(CONFIG.redis_sock, 0, {family=turbo.socket.AF_UNIX})
        if not yield(redis:connect()) then
	        error(turbo.web.HTTPError:new(500, "DB is busy"))
	    end

        local time = tonumber(yield(redis:get(prefix ..":WaitTime")))
        if time > 0 then
            yield(redis:set(prefix ..":WaitTime", time - 1))
        end
        yield(redis:disconnect())
    end)

    -- Adding timeout to clear the timer that updates the WaitTime key every second when it is finished
    local wait_time_timeout = turbo.util.gettimemonotonic() + (tonumber(wait_time) + 1) * 1000
    turbo.ioloop.instance():add_timeout(wait_time_timeout, function(timer_ref)
    	turbo.ioloop.instance():clear_interval(timer_ref)
    end, ref)

    -- Update last modified so that E-Tag can respond properly
    self:update_lastmodified("Redfish:TaskService:Tasks:"..new_task_id, os.time())

    local uri = CONFIG.SERVICE_PREFIX.."/TaskService/Tasks/"..new_task_id

    -- Respond with accepted header and location to monitor the task
    self:set_status(202)
    self:set_header("Location", uri)
    -- include a wait header specifying the amount of time the client should wait before polling for status
    self:set_header("Prefer", "respond-async; wait=" .. tostring(wait_time))

    -- Give a representation of the task resource
    response = {
        Id = tostring(new_task_id),
        Name = task_name,
        Description = "Task for " .. tostring(task_name),
        TaskState = "New"
    }

    local select_list = table.concat(_.keys(response), ",")

    response["@odata.id"] = uri
    response["@odata.type"] = '#' .. CONSTANTS.TASK_TYPE
    response["@odata.context"] = CONFIG.SERVICE_PREFIX .. "/$metadata#"..CONSTANTS.TASKSERVICE_INSTANCE_CONTEXT.."(".. select_list ..")"

    -- self:set_scope("Redfish:TaskService:Tasks:"..new_task_id)

    self:set_response(response)
    self:output()

end

--- Adds entry to audit log in database
-- @param message created using the RedfishHandler:create_message() function
-- @param ip the IP put in the log (optional)
-- @param user the username put in the log (optional)
-- @param proto 
-- @param db the database used (optional)
function RedfishHandler:add_audit_log_entry(message, ip, user, proto, db)
	local client_addr = ip or self:get_request().headers:get("X-Forwarded-For") or "127.0.0.1"
	local username = user or self.username or "in-band-user"
	local protocol = proto or self.request.protocol or "in-band"
	local message_prefix = username ~= nil and "User: " .. username .. ", " or ""
	message_prefix = message_prefix .. "IP: " .. client_addr
	message_prefix = message_prefix .. (protocol ~= nil and ", Protocol: " .. protocol or "") .. " - "
	local redis = db or self:get_db()

	if not redis then
		return
	end
	
	-- TODO: Use environment for Self reference instead of hardcoding it
	local enabled = yield(redis:get("Redfish:Managers:Self:LogServices:AuditLog:ServiceEnabled"))
	local health = yield(redis:hget("Redfish:Managers:Self:LogServices:AuditLog:Status", "Health"))

	if enabled ~= "true" or health ~= "OK" then
		return
	end

	local prefix = "Redfish:Managers:Self:LogServices:AuditLog:Entries:"

	local index = yield(redis:zcard(prefix.."SortedIDs"))

	local max_records = yield(redis:get("Redfish:Managers:Self:LogServices:AuditLog:MaxNumberOfRecords"))

	if index == nil or max_records == nil then
		return
	end
	
	-- Checking if the maximum number of records has been exceeded
	if index >= tonumber(max_records) then
		local overwrite = yield(redis:get("Redfish:Managers:Self:LogServices:AuditLog:OverWritePolicy"))
		-- Only handles new log entries if the overwrite policy is WrapsWhenFull
		if overwrite == "WrapsWhenFull" then
			-- Getting index of most recent entry and incrementing to find index for current entry
			index = tonumber(yield(redis:zrange(prefix.."SortedIDs", index - 1, index - 1, "WITHSCORES"))[2]) + 1

			-- Finding oldest entry and deleting entry from set
			local oldest_key = yield(redis:zrange(prefix.."SortedIDs", 0, 0))[1]
			yield(redis:zrem(prefix.."SortedIDs", oldest_key))

			-- Deleting oldest entry data from database
			local entry_keys = yield(redis:keys(oldest_key .. ":*"))
			if entry_keys then
				yield(redis:del(entry_keys))
			end
		else
			return
		end
	else
		index = index + 1
	end

	local pl = redis:pipeline()
	pl:zadd(prefix .. "SortedIDs", index, prefix .. tostring(index))
	pl:set(prefix .. index .. ":Name", "Audit Log Entry " .. tostring(index))
	pl:set(prefix .. index .. ":Created", utils.iso8601_time(os.time()))
	pl:set(prefix .. index .. ":Severity", message.Severity)
	pl:set(prefix .. index .. ":EntryType", "Event")
	pl:set(prefix .. index .. ":Message", message_prefix .. message.Message)
	pl:set(prefix .. index .. ":MessageId", message.MessageId)
	pl:sadd(prefix .. index .. ":MessageArgs", message.MessageArgs)

	-- Update last modified so that E-Tag can respond properly
	self:update_lastmodified(prefix .. index, os.time(), pl, 3)

	yield(pl:run())
end

--- Retrieves a limited set of collection entries from the database
-- @param sorted_ids_key SortedID key of the collection
-- @param  property_keys A table of the fields to be retrieved and what operation to perform to get them (only mget, hmget, and smembers are supported)
function RedfishHandler:get_limited_collection(sorted_ids_key, property_keys)
	local db = self:get_db()

	-- Use zcard to find the total collection size
	local set_size = yield(db:zcard(sorted_ids_key))
	-- Search Redis for any Log Entries, and use response to form an array of IDs
	-- Log entry set can be huge, so we want to do $skip/$top now to limit DB access rather than after the fact;
	-- if $skip and $top are not given, we can enforce our own paging
	local start_index = self.query_parameters.skip or 0
	local end_index = CONFIG.DEFAULT_COLLECTION_LIMIT
	if self.query_parameters.top then
		end_index = tonumber(self.query_parameters.top) > CONFIG.DEFAULT_COLLECTION_LIMIT and CONFIG.DEFAULT_COLLECTION_LIMIT or start_index + tonumber(self.query_parameters.top)
	elseif self.query_parameters.skip then
		end_index = tonumber(self.query_parameters.skip) + CONFIG.DEFAULT_COLLECTION_LIMIT
	end
	
	-- Signal to RedfishHandler that $skip and $top have been processed, and need not be handled a second time
	self:clear_skip_top_flag()

	-- Because zrange lets you use negative arguments to index backwards from end of set, we need to be careful to not
	-- send [0, -1] (which retrieves the whole set) unless we mean it
	local expectEmptySet = self.query_parameters.top == "0"
	local entry_keys = {}
	
	if set_size <= 0 or expectEmptySet or (self.query_parameters.skip and tonumber(self.query_parameters.skip) > set_size) then
		-- Returning empty objects if the there are no log entries or top is zero
		return set_size, {}, {}
	end

	-- Get the keys of interest from Redis; zrange indices are inclusive, so we use end_index-1
	entry_keys = yield(db:zrange(sorted_ids_key, start_index, end_index-1))

	local pl = db:pipeline()

	-- Looping through the sorted ID set
	for _index, entry in ipairs(entry_keys) do
		for _i, prop in ipairs(property_keys) do
			-- The Redis command is named by the first element in each entry
			local command = pl[prop[1]]
			-- The remaining elements in entry are the command's arguments
			local get_args = _.slice(prop, 2, #prop-1)
			-- Verifying that the command is a Redis function
			if type(command) == "function" then
				local cmds = {}
				-- Handling hmget requests
				if prop[1] == "hmget" then
					local first = true
					for _i, key in ipairs(get_args) do
						local cmd = first and entry .. ":" .. key or key
						table.insert(cmds, cmd)
						first = false
					end
				-- Handling all other kinds fo requests
				else
					for _i, key in ipairs(get_args) do
						table.insert(cmds, entry .. ":" .. key)
					end
				end
				command(pl, unpack(cmds))
			else
				print("Invalid Redis command: ", prop[1])
			end
		end
	end

	-- Getting properties from database
	local replies = yield(pl:run())

	local from_db = {}
	-- Looping through the sorted IDs
	for _index, entry in ipairs(entry_keys) do
		local db_index = 1
		local temp = {}
		-- Looping through database property keys
		for _i, prop in ipairs(property_keys) do
			local command = prop[1]
			local get_args = _.slice(prop, 2, #prop-1)
			local general = replies[((_index - 1) * #property_keys) + db_index]

			-- Handling mget command results
			if command == "mget" then
				for i, key in ipairs(get_args) do
					temp[key] = general[i]
				end
			-- Handling hmget command results
			elseif command == "hmget" then
				local inner_obj = {}
				local outer_key = get_args[1]
				get_args = _.slice(get_args, 2, #get_args-1)
				for i, key in ipairs(get_args) do
					inner_obj[key] = general[i]
				end
				temp[outer_key] = inner_obj
			-- Handling smember results
			elseif type(general) == "table" then
				temp[get_args[1]] = {}
				_.extend(temp[get_args[1]], general)
			else
				temp[get_args[1]] = general
			end
			db_index = db_index + 1
		end
		table.insert(from_db, temp)
	end

	return set_size, entry_keys, from_db
end

function RedfishHandler:add_auth_failure_audit_log_entry(msg)
	local db = self:get_db()
	local auth_failure_log_threshold = tonumber(yield(db:get("Redfish:AccountService:AuthFailureLoggingThreshold"))) or 0
	if auth_failure_log_count + 1 >= auth_failure_log_threshold then
		self:add_audit_log_entry(msg)
		auth_failure_log_count = 0
	else
		auth_failure_log_count = auth_failure_log_count + 1
	end
end

--- Helper function that sends the error body created by the add_error_body() function and throws an error
-- @tparam table body The output from add_error_body()
function RedfishHandler:send_error_body(body)
	self:write(body)
	self:finish()
	error()
end

-- Base registry errors

--- Helper function that sends the PropertyDuplicate error
-- @param property The property that there is a duplicate of
-- @tparam[opt] table response If this is not equal to nil, then instead of sending the error and ending the response, it will add the error to this table 
 function RedfishHandler:error_property_duplicate(property, response)
	if type(response) == "table" then
		self:add_error_body(response, 400, self:create_message("Base", "PropertyDuplicate", {property}, {property}))
	else
		local response = self:add_error_body({}, 400, self:create_message("Base", "PropertyDuplicate", {property}, {property}))
		self:send_error_body(response)
	end
end

--- Helper function that sends the PropertyUnknown error
-- @param property The property that is unknown
-- @tparam[opt] table response If this is not equal to nil, then instead of sending the error and ending the response, it will add the error to this table 
function RedfishHandler:error_property_unknown(property, response)
	if type(response) == "table" then
		self:add_error_body(response, 400, self:create_message("Base", "PropertyUnknown", {property}, {property}))
	else
		local response = self:add_error_body({}, 400, self:create_message("Base", "PropertyUnknown", {property}, {property}))
		self:send_error_body(response)
	end
end

--- Helper function that sends the PropertyValueTypeError error
-- @param property The property whose value's type is invalid
-- @param value The value whose type is invalid
-- @tparam[opt] table response If this is not equal to nil, then instead of sending the error and ending the response, it will add the error to this table 
function RedfishHandler:error_property_value_type(property, value, response)
	if type(response) == "table" then
		self:add_error_body(response, 400, self:create_message("Base", "PropertyValueTypeError", {property}, {value, property}))
	else
		local response = self:add_error_body({}, 400, self:create_message("Base", "PropertyValueTypeError", {property}, {value, property}))
		self:send_error_body(response)
	end
end

--- Helper function that sends the PropertyValueFormatError error
-- @param property The property whose value's format is invalid
-- @param value The value whose format is invalid
-- @tparam[opt] table response If this is not equal to nil, then instead of sending the error and ending the response, it will add the error to this table 
function RedfishHandler:error_property_value_format(property, value, response)
	if type(response) == "table" then
		self:add_error_body(response, 400, self:create_message("Base", "PropertyValueFormatError", {property}, {value, property}))
	else
		local response = self:add_error_body({}, 400, self:create_message("Base", "PropertyValueFormatError", {property}, {value, property}))
		self:send_error_body(response)
	end
end

--- Helper function that sends the PropertyValueNotInList error
-- @param property The property whose value's format is invalid
-- @param value The value whose format is invalid
-- @tparam[opt] table response If this is not equal to nil, then instead of sending the error and ending the response, it will add the error to this table 
function RedfishHandler:error_property_value_not_in_list(property, value, response)
	if type(response) == "table" then
		self:add_error_body(response, 400, self:create_message("Base", "PropertyValueNotInList", {property}, {value, property}))
	else
		local response = self:add_error_body({}, 400, self:create_message("Base", "PropertyValueNotInList", {property}, {value, property}))
		self:send_error_body(response)
	end
end

--- Helper function that sends the PropertyNotWritable error
-- @param property The property that is not writable
-- @tparam[opt] table response If this is not equal to nil, then instead of sending the error and ending the response, it will add the error to this table 
function RedfishHandler:error_property_not_writable(property, response)
	if type(response) == "table" then
		self:add_error_body(response, 400, self:create_message("Base", "PropertyNotWritable", {property}, {property}))
	else
		local response = self:add_error_body({}, 400, self:create_message("Base", "PropertyNotWritable", {property}, {property}))
		self:send_error_body(response)
	end
end

--- Helper function that sends the PropertyMissing error
-- @param property The property that is missing
-- @tparam[opt] table response If this is not equal to nil, then instead of sending the error and ending the response, it will add the error to this table 
function RedfishHandler:error_property_missing(property, response)
	if type(response) == "table" then
		self:add_error_body(response, 400, self:create_message("Base", "PropertyMissing", {property}, {property}))
	else
		local response = self:add_error_body({}, 400, self:create_message("Base", "PropertyMissing", {property}, {property}))
		self:send_error_body(response)
	end
end

--- Helper function that sends the MalformedJSON error
-- @tparam[opt] table response If this is not equal to nil, then instead of sending the error and ending the response, it will add the error to this table 
function RedfishHandler:error_malformed_json(response)
	if type(response) == "table" then
		self:add_error_body(response, 400, self:create_message("Base", "MalformedJSON"))
	else
		local response = self:add_error_body({}, 400, self:create_message("Base", "MalformedJSON"))
		self:send_error_body(response)
	end
end

--- Helper function that sends the ActionNotSupported error
-- @tparam[opt] table response If this is not equal to nil, then instead of sending the error and ending the response, it will add the error to this table 
function RedfishHandler:error_action_not_supported(response)
	if type(response) == "table" then
		self:add_error_body(response, 404, self:create_message("Base", "ActionNotSupported", nil, {self:get_request().path}))
	else
		local response = self:add_error_body({}, 404, self:create_message("Base", "ActionNotSupported", nil, {self:get_request().path}))
		self:send_error_body(response)
	end
end

--- Helper function that sends the ActionParameterMissing error
-- @param parameter The parameter that is missing
-- @tparam[opt] table response If this is not equal to nil, then instead of sending the error and ending the response, it will add the error to this table 
function RedfishHandler:error_action_parameter_missing(parameter, response)
	if type(response) == "table" then
		self:add_error_body(response, 400, self:create_message("Base", "ActionParameterMissing", {parameter}, {self:get_request().path, parameter}))
	else
		local response = self:add_error_body({}, 400, self:create_message("Base", "ActionParameterMissing", {parameter}, {self:get_request().path, parameter}))
		self:send_error_body(response)
	end
end

--- Helper function that sends the ActionParameterDuplicate error
-- @param parameter The parameter that is a duplicate
-- @tparam[opt] table response If this is not equal to nil, then instead of sending the error and ending the response, it will add the error to this table 
function RedfishHandler:error_action_parameter_duplicate(parameter, response)
	if type(response) == "table" then
		self:add_error_body(response, 400, self:create_message("Base", "ActionParameterDuplicate", {parameter}, {self:get_request().path, parameter}))
	else
		local response = self:add_error_body({}, 400, self:create_message("Base", "ActionParameterDuplicate", {parameter}, {self:get_request().path, parameter}))
		self:send_error_body(response)
	end
end

--- Helper function that sends the ActionParameterUnknown error
-- @param parameter The parameter that is unknown
-- @tparam[opt] table response If this is not equal to nil, then instead of sending the error and ending the response, it will add the error to this table 
function RedfishHandler:error_action_parameter_unknown(parameter, response)
	if type(response) == "table" then
		self:add_error_body(response, 400, self:create_message("Base", "ActionParameterUnknown", {parameter}, {self:get_request().path, parameter}))
	else
		local response = self:add_error_body({}, 400, self:create_message("Base", "ActionParameterUnknown", {parameter}, {self:get_request().path, parameter}))
		self:send_error_body(response)
	end
end

--- Helper function that sends the ActionParameterValueTypeError error
-- @param parameter The parameter whose value has the invalid type
-- @param value The value whose type is invalid
-- @tparam[opt] table response If this is not equal to nil, then instead of sending the error and ending the response, it will add the error to this table 
function RedfishHandler:error_action_parameter_type(parameter, value, response)
	if type(response) == "table" then
		self:add_error_body(response, 400, self:create_message("Base", "ActionParameterValueTypeError", {parameter}, {value, parameter, self:get_request().path}))
	else
		local response = self:add_error_body({}, 400, self:create_message("Base", "ActionParameterValueTypeError", {parameter}, {value, parameter, self:get_request().path}))
		self:send_error_body(response)
	end
end

--- Helper function that sends the ActionParameterValueFormatError error
-- @param parameter The parameter whose value has the invalid format
-- @param value The value whose format is invalid
-- @tparam[opt] table response If this is not equal to nil, then instead of sending the error and ending the response, it will add the error to this table 
function RedfishHandler:error_action_parameter_format(parameter, value, response)
	if type(response) == "table" then
		self:add_error_body(response, 400, self:create_message("Base", "ActionParameterValueFormatError", {parameter}, {value, parameter, self:get_request().path}))
	else
		local response = self:add_error_body({}, 400, self:create_message("Base", "ActionParameterValueFormatError", {parameter}, {value, parameter, self:get_request().path}))
		self:send_error_body(response)
	end
end

--- Helper function that sends the ActionParameterNotSupported error
-- @param parameter The parameter that is not supported
-- @tparam[opt] table response If this is not equal to nil, then instead of sending the error and ending the response, it will add the error to this table 
function RedfishHandler:error_action_parameter_not_supported(parameter, response)
	if type(response) == "table" then
		self:add_error_body(response, 400, self:create_message("Base", "ActionParameterNotSupported", {parameter}, {parameter, self:get_request().path}))
	else
		local response = self:add_error_body({}, 400, self:create_message("Base", "ActionParameterNotSupported", {parameter}, {parameter, self:get_request().path}))
		self:send_error_body(response)
	end
end

--- Helper function that sends the QueryParameterValueTypeError error
-- @param parameter The parameter whose value has the invalid type
-- @param value The value whose type is invalid
-- @tparam[opt] table response If this is not equal to nil, then instead of sending the error and ending the response, it will add the error to this table 
function RedfishHandler:error_query_parameter_value_type(parameter, value, response)
	if type(response) == "table" then
		self:add_error_body(response, 400, self:create_message("Base", "QueryParameterValueTypeError", {parameter}, {value, parameter}))
	else
		local response = self:add_error_body({}, 400, self:create_message("Base", "QueryParameterValueTypeError", {parameter}, {value, parameter}))
		self:send_error_body(response)
	end
end

--- Helper function that sends the QueryParameterValueFormatError error
-- @param parameter The parameter whose value has the invalid format
-- @param value The value whose format is invalid
-- @tparam[opt] table response If this is not equal to nil, then instead of sending the error and ending the response, it will add the error to this table 
function RedfishHandler:error_query_parameter_value_format(parameter, value, response)
	if type(response) == "table" then
		self:add_error_body(response, 400, self:create_message("Base", "QueryParameterValueFormatError", {parameter}, {value, parameter}))
	else
		local response = self:add_error_body({}, 400, self:create_message("Base", "QueryParameterValueFormatError", {parameter}, {value, parameter}))
		self:send_error_body(response)
	end
end

--- Helper function that sends the QueryParameterOutOfRange error
-- @param parameter The parameter whose value is out of range
-- @param value The value that is out of range
-- @param range The range that is valid
-- @tparam[opt] table response If this is not equal to nil, then instead of sending the error and ending the response, it will add the error to this table 
function RedfishHandler:error_query_parameter_out_of_range(parameter, value, range, response)
	if type(response) == "table" then
		self:add_error_body(response, 400, self:create_message("Base", "QueryParameterOutOfRange", {parameter}, {value, parameter, range}))
	else
		local response = self:add_error_body({}, 400, self:create_message("Base", "QueryParameterOutOfRange", {parameter}, {value, parameter, range}))
		self:send_error_body(response)
	end
end

--- Helper function that sends the QueryNotSupportedOnResource error
-- @tparam[opt] table response If this is not equal to nil, then instead of sending the error and ending the response, it will add the error to this table 
function RedfishHandler:error_query_not_supported_on_resource(response)
	if type(response) == "table" then
		self:add_error_body(response, 501, self:create_message("Base", "QueryNotSupportedOnResource"))
	else
		local response = self:add_error_body({}, 501, self:create_message("Base", "QueryNotSupportedOnResource"))
		self:send_error_body(response)
	end
end

--- Helper function that sends the QueryNotSupported error
-- @tparam[opt] table response If this is not equal to nil, then instead of sending the error and ending the response, it will add the error to this table 
function RedfishHandler:error_query_not_supported(response)
	if type(response) == "table" then
		self:add_error_body(response, 501, self:create_message("Base", "QueryNotSupported"))
	else
		local response = self:add_error_body({}, 501, self:create_message("Base", "QueryNotSupported"))
		self:send_error_body(response)
	end
end

--- Helper function that sends the SessionLimitExceeded error
-- @tparam[opt] table response If this is not equal to nil, then instead of sending the error and ending the response, it will add the error to this table 
function RedfishHandler:error_session_limit_exceeded(response)
	if type(response) == "table" then
		self:add_error_body(response, 400, self:create_message("Base", "SessionLimitExceeded"))
	else
		local response = self:add_error_body({}, 400, self:create_message("Base", "SessionLimitExceeded"))
		self:send_error_body(response)
	end
end

--- Helper function that sends the EventSubscriptionLimitExceeded error
-- @tparam[opt] table response If this is not equal to nil, then instead of sending the error and ending the response, it will add the error to this table 
function RedfishHandler:error_event_subscription_limit_exceeded(response)
	if type(response) == "table" then
		self:add_error_body(response, 400, self:create_message("Base", "EventSubscriptionLimitExceeded"))
	else
		local response = self:add_error_body({}, 400, self:create_message("Base", "EventSubscriptionLimitExceeded"))
		self:send_error_body(response)
	end
end

--- Helper function that sends the ResourceCannotBeDeleted error
-- @tparam[opt] table response If this is not equal to nil, then instead of sending the error and ending the response, it will add the error to this table 
function RedfishHandler:error_resource_cannot_be_deleted(response)
	if type(response) == "table" then
		self:add_error_body(response, 400, self:create_message("Base", "ResourceCannotBeDeleted"))
	else
		local response = self:add_error_body({}, 400, self:create_message("Base", "ResourceCannotBeDeleted"))
		self:send_error_body(response)
	end
end

--- Helper function that sends the ResourceInUse error
-- @tparam[opt] table response If this is not equal to nil, then instead of sending the error and ending the response, it will add the error to this table 
function RedfishHandler:error_resource_in_use(response)
	if type(response) == "table" then
		self:add_error_body(response, 400, self:create_message("Base", "ResourceInUse"))
	else
		local response = self:add_error_body({}, 400, self:create_message("Base", "ResourceInUse"))
		self:send_error_body(response)
	end
end

--- Helper function that sends the ResourceAlreadyExists error
-- @tparam[opt] table response If this is not equal to nil, then instead of sending the error and ending the response, it will add the error to this table 
function RedfishHandler:error_resource_already_exists(response)
	if type(response) == "table" then
		self:add_error_body(response, 400, self:create_message("Base", "ResourceAlreadyExists"))
	else
		local response = self:add_error_body({}, 400, self:create_message("Base", "ResourceAlreadyExists"))
		self:send_error_body(response)
	end
end

--- Helper function that sends the CreateFailedMissingReqProperties error
-- @param property The required property that is missing
-- @tparam[opt] table response If this is not equal to nil, then instead of sending the error and ending the response, it will add the error to this table 
function RedfishHandler:error_create_failed_missing_req_properties(property, response)
	if type(response) == "table" then
		self:add_error_body(response, 400, self:create_message("Base", "CreateFailedMissingReqProperties", {property}, {property}))
	else
		local response = self:add_error_body({}, 400, self:create_message("Base", "CreateFailedMissingReqProperties", {property}, {property}))
		self:send_error_body(response)
	end
end

--- Helper function that sends the CreateLimitReachedForResource error
-- @tparam[opt] table response If this is not equal to nil, then instead of sending the error and ending the response, it will add the error to this table 
function RedfishHandler:error_create_limit_reached_for_resource(response)
	if type(response) == "table" then
		self:add_error_body(response, 400, self:create_message("Base", "CreateLimitReachedForResource"))
	else
		local response = self:add_error_body({}, 400, self:create_message("Base", "CreateLimitReachedForResource"))
		self:send_error_body(response)
	end
end

--- Helper function that sends the ServiceShuttingDown error
-- @tparam[opt] table response If this is not equal to nil, then instead of sending the error and ending the response, it will add the error to this table 
function RedfishHandler:error_service_shutting_down(response)
	if type(response) == "table" then
		self:add_error_body(response, 503, self:create_message("Base", "ServiceShuttingDown"))
	else
		local response = self:add_error_body({}, 503, self:create_message("Base", "ServiceShuttingDown"))
		self:send_error_body(response)
	end
end

--- Helper function that sends the ServiceInUnknownState error
-- @tparam[opt] table response If this is not equal to nil, then instead of sending the error and ending the response, it will add the error to this table 
function RedfishHandler:error_service_in_unknown_state(response)
	if type(response) == "table" then
		self:add_error_body(response, 503, self:create_message("Base", "ServiceInUnknownState"))
	else
		local response = self:add_error_body({}, 503, self:create_message("Base", "ServiceInUnknownState"))
		self:send_error_body(response)
	end
end

--- Helper function that sends the NoValidSession error
-- @tparam[opt] table response If this is not equal to nil, then instead of sending the error and ending the response, it will add the error to this table 
function RedfishHandler:error_no_valid_session(response)
	if type(response) == "table" then
		self:add_error_body(response, 400, self:create_message("Base", "NoValidSession"))
	else
		local response = self:add_error_body({}, 400, self:create_message("Base", "NoValidSession"))
		self:send_error_body(response)
	end
end

--- Helper function that sends the AccountNotModified error
-- @tparam[opt] table response If this is not equal to nil, then instead of sending the error and ending the response, it will add the error to this table 
function RedfishHandler:error_account_not_modified(response)
	if type(response) == "table" then
		self:add_error_body(response, 400, self:create_message("Base", "AccountNotModified"))
	else
		local response = self:add_error_body({}, 400, self:create_message("Base", "AccountNotModified"))
		self:send_error_body(response)
	end
end

--- Helper function that sends the InvalidObject error
-- @tparam[opt] table response If this is not equal to nil, then instead of sending the error and ending the response, it will add the error to this table 
function RedfishHandler:error_invalid_object(response)
	if type(response) == "table" then
		self:add_error_body(response, 400, self:create_message("Base", "InvalidObject", nil, {self:get_request().path}))
	else
		local response = self:add_error_body({}, 400, self:create_message("Base", "InvalidObject", nil, {self:get_request().path}))
		self:send_error_body(response)
	end
end

--- Helper function that sends the InternalError error
-- @tparam[opt] table response If this is not equal to nil, then instead of sending the error and ending the response, it will add the error to this table 
function RedfishHandler:error_internal(response)
	if type(response) == "table" then
		self:add_error_body(response, 500, self:create_message("Base", "InternalError"))
	else
		local response = self:add_error_body({}, 500, self:create_message("Base", "InternalError"))
		self:send_error_body(response)
	end
end

--- Helper function that sends the UnrecognizedRequestBody error
-- @tparam[opt] table response If this is not equal to nil, then instead of sending the error and ending the response, it will add the error to this table 
function RedfishHandler:error_unrecognized_request_body(response)
	if type(response) == "table" then
		self:add_error_body(response, 400, self:create_message("Base", "UnrecognizedRequestBody"))
	else
		local response = self:add_error_body({}, 400, self:create_message("Base", "UnrecognizedRequestBody"))
		self:send_error_body(response)
	end
end

--- Helper function that sends the ResourceMissingAtURI error
-- @tparam[opt] table response If this is not equal to nil, then instead of sending the error and ending the response, it will add the error to this table 
function RedfishHandler:error_resource_missing_at_uri(response)
	if type(response) == "table" then
		self:add_error_body(response, 404, self:create_message("Base", "ResourceMissingAtURI", nil, {self:get_request().path}))
	else
		local response = self:add_error_body({}, 404, self:create_message("Base", "ResourceMissingAtURI", nil, {self:get_request().path}))
		self:send_error_body(response)
	end
end

--- Helper function that sends the ResourceAtUriInUnknownFormat error
-- @tparam[opt] table response If this is not equal to nil, then instead of sending the error and ending the response, it will add the error to this table 
function RedfishHandler:error_resource_at_uri_in_unknown_format(response)
	if type(response) == "table" then
		self:add_error_body(response, 400, self:create_message("Base", "ResourceAtUriInUnknownFormat", nil, {self:get_request().path}))
	else
		local response = self:add_error_body({}, 400, self:create_message("Base", "ResourceAtUriInUnknownFormat", nil, {self:get_request().path}))
		self:send_error_body(response)
	end
end

--- Helper function that sends the ResourceAtUriUnauthorized error
-- @param auth_error_msg The error message to send with the error
-- @tparam[opt] table response If this is not equal to nil, then instead of sending the error and ending the response, it will add the error to this table 
function RedfishHandler:error_resource_at_uri_unauthorized(auth_error_msg, response)
	if type(response) == "table" then
		self:add_error_body(response, 400, self:create_message("Base", "ResourceAtUriUnauthorized", nil, {self:get_request().path, auth_error_msg}))
	else
		local response = self:add_error_body({}, 400, self:create_message("Base", "ResourceAtUriUnauthorized", nil, {self:get_request().path, auth_error_msg}))
		self:send_error_body(response)
	end
end

--- Helper function that sends the CouldNotEstablishConnection error
-- @tparam[opt] table response If this is not equal to nil, then instead of sending the error and ending the response, it will add the error to this table 
function RedfishHandler:error_could_not_establish_connection(response)
	if type(response) == "table" then
		self:add_error_body(response, 400, self:create_message("Base", "CouldNotEstablishConnection", nil, {self:get_request().path}))
	else
		local response = self:add_error_body({}, 400, self:create_message("Base", "CouldNotEstablishConnection", nil, {self:get_request().path}))
		self:send_error_body(response)
	end
end

--- Helper function that sends the SourceDoesNotSupportProtocol error
-- @param protocol The protocol that there is not supported
-- @tparam[opt] table response If this is not equal to nil, then instead of sending the error and ending the response, it will add the error to this table 
function RedfishHandler:error_source_does_not_support_protocol(protocol, response)
	if type(response) == "table" then
		self:add_error_body(response, 400, self:create_message("Base", "SourceDoesNotSupportProtocol", nil, {self:get_request().path, protocol}))
	else
		local response = self:add_error_body({}, 400, self:create_message("Base", "SourceDoesNotSupportProtocol", nil, {self:get_request().path, protocol}))
		self:send_error_body(response)
	end
end

--- Helper function that sends the ServiceTemporarilyUnavailable error
-- @param retry_time The amount of time that should be waited before trying to reach the service again
-- @tparam[opt] table response If this is not equal to nil, then instead of sending the error and ending the response, it will add the error to this table 
function RedfishHandler:error_service_temporarily_unavailable(retry_time, response)
	if type(response) == "table" then
		self:add_error_body(response, 503, self:create_message("Base", "ServiceTemporarilyUnavailable", nil, {retry_time}))
	else
		local response = self:add_error_body({}, 503, self:create_message("Base", "ServiceTemporarilyUnavailable", nil, {retry_time}))
		self:send_error_body(response)
	end
end

--- Helper function that sends the InvalidIndex error
-- @param index The invalid index
-- @tparam[opt] table response If this is not equal to nil, then instead of sending the error and ending the response, it will add the error to this table 
function RedfishHandler:error_invalid_index(index, response)
	if type(response) == "table" then
		self:add_error_body(response, 400, self:create_message("Base", "InvalidIndex", nil, {index}))
	else
		local response = self:add_error_body({}, 400, self:create_message("Base", "InvalidIndex", nil, {index}))
		self:send_error_body(response)
	end
end

--- Helper function that sends the PropertyValueModified error
-- @param property The property that was modified
-- @param value The value the property was changed to
-- @tparam[opt] table response If this is not equal to nil, then instead of sending the error and ending the response, it will add the error to this table 
function RedfishHandler:error_property_value_modified(property, value, response)
	if type(response) == "table" then
		self:add_error_body(response, 400, self:create_message("Base", "PropertyValueModified", nil, {property, value}))
	else
		local response = self:add_error_body({}, 400, self:create_message("Base", "PropertyValueModified", nil, {property, value}))
		self:send_error_body(response)
	end
end

--- Helper function that sends the ServiceDisabled error
-- @tparam[opt] table response If this is not equal to nil, then instead of sending the error and ending the response, it will add the error to this table 
function RedfishHandler:error_service_disabled(response)
	if type(response) == "table" then
		self:add_error_body(response, 400, self:create_message("Base", "ServiceDisabled"))
	else
		local response = self:add_error_body({}, 400, self:create_message("Base", "ServiceDisabled"))
		self:send_error_body(response)
	end
end

-- Security registry errors

--- Helper function that sends the LoginFailure error
-- @param user The user that attempted to login
-- @param reason The reason the login was not successful
-- @tparam[opt] table response If this is not equal to nil, then instead of sending the error and ending the response, it will add the error to this table 
function RedfishHandler:error_login_failure(user, reason, response)
	local msg = self:create_message("Security", "LoginFailure", nil, {user, reason})
	self:add_auth_failure_audit_log_entry(msg)

	if type(response) == "table" then
		self:add_error_body(response, 401, msg)
	else
		local response = self:add_error_body({}, 401, msg)
		self:send_error_body(response)
	end
end

--- Helper function that sends the InsufficientPrivilege error
-- @tparam[opt] table response If this is not equal to nil, then instead of sending the error and ending the response, it will add the error to this table 
function RedfishHandler:error_insufficient_privilege(response)
	local msg = self:create_message("Security", "InsufficientPrivilege", nil, {self:get_request().path, self:get_request().method})
	self:add_auth_failure_audit_log_entry(msg)

	if type(response) == "table" then
		self:add_error_body(response, 403, msg)
	else
		local response = self:add_error_body({}, 403, msg)
		self:send_error_body(response)
	end
end

--- Helper function that sends the InsufficientPrivilege error
-- @param property The property that was modified
-- @tparam[opt] table response If this is not equal to nil, then instead of sending the error and ending the response, it will add the error to this table 
function RedfishHandler:error_insufficient_privilege_for_property(property, response)
	local msg = self:create_message("Security", "InsufficientPrivilegeForProperty", nil, {property})
	self:add_auth_failure_audit_log_entry(msg)

	if type(response) == "table" then
		self:add_error_body(response, 400, msg)
	else
		local response = self:add_error_body({}, 400, msg)
		self:send_error_body(response)
	end
end

--- Helper function that sends the ResourceNotWritable error
-- @tparam[opt] table response If this is not equal to nil, then instead of sending the error and ending the response, it will add the error to this table 
function RedfishHandler:error_resource_not_writable(response)
	if type(response) == "table" then
		self:add_error_body(response, 400, self:create_message("Security", "ResourceNotWritable", nil, {self:get_request().path, self:get_request().method}))
	else
		local response = self:add_error_body({}, 400, self:create_message("Security", "ResourceNotWritable", nil, {self:get_request().path, self:get_request().method}))
		self:send_error_body(response)
	end
end

--- Helper function that sends the AccessDenied error
-- @tparam[opt] table response If this is not equal to nil, then instead of sending the error and ending the response, it will add the error to this table 
function RedfishHandler:error_access_denied(response)
	local msg = self:create_message("Security", "AccessDenied", nil, {self:get_request().path})
	self:add_auth_failure_audit_log_entry(msg)
	
	if type(response) == "table" then
		self:add_error_body(response, 401, msg)
	else
		local response = self:add_error_body({}, 401, msg)
		self:send_error_body(response)
	end
end


-- HTTP registry errors

--- Helper function that sends the MethodNotAllowed error that corresponds to the 405 HTTP status code
-- @tparam[opt] table response If this is not equal to nil, then instead of sending the error and ending the response, it will add the error to this table 
function RedfishHandler:error_method_not_allowed(response)
	if type(response) == "table" then
		self:add_error_body(response, 405, self:create_message("HttpStatus", "MethodNotAllowed", nil, {self:get_request().method, self:get_request().path}))
	else
		local response = self:add_error_body({}, 405, self:create_message("HttpStatus", "MethodNotAllowed", nil, {self:get_request().method, self:get_request().path}))
		self:send_error_body(response)
	end
end

--- Helper function that sends the NotAcceptable error that corresponds to the 406 HTTP status code
-- @tparam[opt] table response If this is not equal to nil, then instead of sending the error and ending the response, it will add the error to this table 
function RedfishHandler:error_not_acceptable(response)
	if type(response) == "table" then
		self:add_error_body(response, 406, self:create_message("HttpStatus", "NotAcceptable", nil, {self:get_request().path}))
	else
		local response = self:add_error_body({}, 406, self:create_message("HttpStatus", "NotAcceptable", nil, {self:get_request().path}))
		self:send_error_body(response)
	end
end

--- Helper function that sends the Conflict error that corresponds to the 409 HTTP status code
-- @tparam[opt] table response If this is not equal to nil, then instead of sending the error and ending the response, it will add the error to this table 
function RedfishHandler:error_conflict(response)
	if type(response) == "table" then
		self:add_error_body(response, 409, self:create_message("HttpStatus", "Conflict", nil, {self:get_request().path}))
	else
		local response = self:add_error_body({}, 409, self:create_message("HttpStatus", "Conflict", nil, {self:get_request().path}))
		self:send_error_body(response)
	end
end

--- Helper function that sends the LengthRequired error that corresponds to the 411 HTTP status code
-- @tparam[opt] table response If this is not equal to nil, then instead of sending the error and ending the response, it will add the error to this table 
function RedfishHandler:error_length_required(response)
	if type(response) == "table" then
		self:add_error_body(response, 411, self:create_message("HttpStatus", "LengthRequired", nil, {self:get_request().path}))
	else
		local response = self:add_error_body({}, 411, self:create_message("HttpStatus", "LengthRequired", nil, {self:get_request().path}))
		self:send_error_body(response)
	end
end

--- Helper function that sends the PreconditionFailed error that corresponds to the 412 HTTP status code
-- @param failed_precondition The precondition that was failed that caused this error
-- @tparam[opt] table response If this is not equal to nil, then instead of sending the error and ending the response, it will add the error to this table 
function RedfishHandler:error_precondition_failed(failed_precondition, response)
	if type(response) == "table" then
		self:add_error_body(response, 412, self:create_message("HttpStatus", "PreconditionFailed", nil, {self:get_request().path, failed_precondition}))
	else
		local response = self:add_error_body({}, 412, self:create_message("HttpStatus", "PreconditionFailed", nil, {self:get_request().path, failed_precondition}))
		self:send_error_body(response)
	end
end

--- Helper function that sends the UnsupportedMediaType error that corresponds to the 415 HTTP status code
-- @param media_type The media type that is unsupported
-- @tparam[opt] table response If this is not equal to nil, then instead of sending the error and ending the response, it will add the error to this table 
function RedfishHandler:error_unsupported_media_type(media_type, response)
	if type(response) == "table" then
		self:add_error_body(response, 415, self:create_message("HttpStatus", "UnsupportedMediaType", nil, {self:get_request().path, media_type}))
	else
		local response = self:add_error_body({}, 415, self:create_message("HttpStatus", "UnsupportedMediaType", nil, {self:get_request().path, media_type}))
		self:send_error_body(response)
	end
end

--- Helper function that sends the NotImplemented error that corresponds to the 501 HTTP status code
-- @tparam[opt] table response If this is not equal to nil, then instead of sending the error and ending the response, it will add the error to this table 
function RedfishHandler:error_not_implemented(response)
	if type(response) == "table" then
		self:add_error_body(response, 501, self:create_message("HttpStatus", "NotImplemented", nil, {self:get_request().path, self:get_request().method}))
	else
		local response = self:add_error_body({}, 501, self:create_message("HttpStatus", "NotImplemented", nil, {self:get_request().path, self:get_request().method}))
		self:send_error_body(response)
	end
end

--- Helper function that sends the EmptyJSONRequest error
-- @tparam[opt] table response If this is not equal to nil, then instead of sending the error and ending the response, it will add the error to this table 
function RedfishHandler:error_request_empty(response)
	if type(response) == "table" then
		self:add_error_body(response, 400, self:create_message("Base", "EmptyJSONRequest"))
	else
		local response = self:add_error_body({}, 400, self:create_message("Base", "EmptyJSONRequest"))
		self:send_error_body(response)
	end
end

--- Function to get the onshutdown prefix
-- @return String 
function RedfishHandler:get_onshutdown_prefix()
    return "OnShutdown:"
end

--- Function to get the onboot prefix
-- @return String 
function RedfishHandler:get_onboot_prefix()
    return "OnBoot:"
end

--- Function to get the onlogin prefix.
-- @param username
-- @return String
function RedfishHandler:get_onlogin_prefix(username)
    --username = username or "AnyUser"

    return "OnLogin:" .. username .. ":"
end

--- Function to get the onlogout prefix.
-- @return String
function RedfishHandler:get_onlogout_prefix()
    local auth_mode = self:get_auth_mode()
    local prefix = ""
    if auth_mode == self.SESSION_AUTH then
        prefix = "OnLogout:" .. self:get_session_id() .. ":"
    end

    return prefix
end

--- Function to get the logout prefix.
-- @param session_id
-- @return String
function RedfishHandler:on_logout(session_id)
	local session = session_id or self:get_session_id()
    if session then
    	settings.apply("Logout:" .. session)
    else
    	print("Cannot call OnLogout event because session ID is invalid")
    end
end

--- Function to get the login prefix.
-- @param username
-- @return String
function RedfishHandler:on_login(username)
    if username then
    	settings.apply("Login:" .. username)
    end
    --settings.apply("Login:AnyUser")
end

--- Helper function to capture the null property from the patch request
-- @param req string
-- @param access Property access table
-- @param extended Extended Table from Patch handler.
function RedfishHandler:validatePatchRequest(req, access, extended)
    
    --[[if string.match(req,'"null"') == nil then
        request_data_str, recursions = req:gsub("null", "\"666$NULLVALUEPROPERTY$666\"")
    else
        request_data_str = req
    end--]]
    request_data_str, recursions = req:gsub("null", "\"666$NULLVALUEPROPERTY$666\"")
  
    local request_data = turbo.escape.json_decode(request_data_str)
    
    readonly_properties, writable_properties = utils.readonlyCheck(request_data, access)
  
    --Get all writable properties that includes properties with null value
    local writableProps, array_diff = utils.intersect_and_diff_array(request_data, writable_properties)
    local writablePropCount = utils.table_len(writableProps)
    
  
    if writablePropCount ~= 0 then
        -- Get the writable property list with null value in request body
        local writableNullPropertyList = utils.nullPropertyList(writableProps)
        local writableNullPropertyListCount = utils.table_len(writableNullPropertyList)
        if writableNullPropertyListCount ~= 0 then
          for k, v in pairs(writableNullPropertyList) do
            table.insert(extended, RedfishHandler:create_message("Base", "PropertyValueTypeError", {"#/"..k}, {"null".."(".."null"..")", k}))
          end
        end
    end
    
    --Get all readable properties that includes properties with null value and also and unknown properties list
    local leftOverReadOnlyProps, propertyNotInList = utils.intersect_and_diff_array(array_diff, readonly_properties)
    local leftOverReadOnlyPropsCount = utils.table_len(leftOverReadOnlyProps)
    local propertyNotInListCount = utils.table_len(propertyNotInList)
    
    if leftOverReadOnlyPropsCount ~= 0 then
				-- Get readable properties list with null value
				local readOnlyNullPropertyList = utils.nullPropertyList(leftOverReadOnlyProps)
				local readOnlyNullPropertyListCount = utils.table_len(readOnlyNullPropertyList)
				if readOnlyNullPropertyListCount ~= 0 then
            for k, v in pairs(readOnlyNullPropertyList) do
                table.insert(extended, RedfishHandler:create_message("Base", "PropertyNotWritable", "#/" .. k, k))
            end
				end
			end
			
		if propertyNotInListCount ~= 0 then
				local nullPropertyNotInList = utils.nullPropertyList(propertyNotInList)
				local nullPropertyNotInListCount = utils.table_len(nullPropertyNotInList)
				if nullPropertyNotInListCount ~= 0 then
            for k, v in pairs(nullPropertyNotInList) do
                table.insert(extended, RedfishHandler:create_message("Base", "PropertyUnknown", "#/" .. k, k))
            end
				end
		end
    return extended
  
end

return RedfishHandler
