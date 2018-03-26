-- Import required libraries
-- [See "redfish-handler.lua"](/redfish-handler.html)
local RedfishHandler = require("redfish-handler")
-- [See "constants.lua"](/constants.html)
local CONSTANTS = require("constants")
-- [See "config.lua"](/config.html)
local CONFIG = require("config")
-- [See "turboredis.lua"](https://github.com/enotodden/turboredis)
local db_utils = require("turboredis.util")
-- [See "utils.lua"](/utils.html)
local utils = require("utils")
-- [See "turbo library"](http://turbolua.org)
local turbo = require("turbo")
-- [See "underscore.lua"](https://mirven.github.io/underscore.lua/)
local _ = require("underscore")
local yield = coroutine.yield
local VolumeInstanceHandler = class("VolumeInstanceHandler", RedfishHandler)

-- ATTENTION: These allowable values need to be filled in with the appropriate values
local Initialize_allowable_vals = {}
function VolumeInstanceHandler:get(url_capture0, url_capture1, url_capture2)
	local response = {}
	local redis = self:get_db()
	local url_segments = self:get_url_segments()
	local prefix = "Redfish:" .. table.concat(url_segments, ":")
	self:set_scope(prefix)
	local pl = redis:pipeline()
	pl:mget({
		prefix .. ":Id",
		prefix .. ":Name",
		prefix .. ":Description",
		prefix .. ":Status:State",
		prefix .. ":Status:HealthRollup",
		prefix .. ":Status:Health",
		prefix .. ":CapacityBytes",
		prefix .. ":VolumeType",
		prefix .. ":Encrypted",
		prefix .. ":BlockSizeBytes",
		prefix .. ":OptimumIOSizeBytes"
	})

	pl:smembers(prefix .. ":EncryptionTypes")

	pl:smembers(prefix .. ":Links:Drives")
	local db_result = yield(pl:run())
	self:assert_resource(db_result)
	local general, EncryptionTypes, Links_Drives = unpack(db_result)

	response["Id"] = general[1]
	response["Name"] = general[2]
	response["Description"] = general[3]
	response["Status"] = {}
	response["Status"]["State"] = general[4]
	response["Status"]["HealthRollup"] = general[5]
	response["Status"]["Health"] = general[6]
	response["Status"]["Oem"] = {}
	response["CapacityBytes"] = tonumber(general[7])
	response["VolumeType"] = general[8]
	response["Encrypted"] = utils.bool(general[9])
	response["EncryptionTypes"] = {}
	response["EncryptionTypes"] = EncryptionTypes
	response["Identifiers"] = {}
	
	local identifiers = yield(redis:hgetall(prefix .. ":Identifiers:"))
	if identifiers[1] then
		response["Identifiers"] = utils.convertHashListToArray(db_utils.from_kvlist(identifiers))
	end
	response["BlockSizeBytes"] = tonumber(general[10])
	response["Operations"] = {}
	local operations = yield(redis:hgetall(prefix .. ":Operations:"))
	if operations[1] then
		response["Operations"] = utils.convertHashListToArray(db_utils.from_kvlist(operations))
	end
	response["OptimumIOSizeBytes"] = tonumber(general[11])
	response["Links"] = {}
	response["Links"]["Oem"] = {}
	response["Links"]["Drives"] = utils.getODataIDArray(Links_Drives)
	-- ATTENTION: The target and action parameter for this action may not be correct. Please double check them and make the appropraite changes.
	self:add_action({
		["#Volume.Initialize"] = {
			target = CONFIG.SERVICE_PREFIX .. "/" .. table.concat(url_segments, "/") .. "/Actions/Volume.Initialize",
			["InitializeType@Redfish.AllowableValues"] = Initialize_allowable_vals
		},
	})
	response = self:oem_extend(response, "query.volume-instance")
	utils.remove_nils(response)
	-- Set the OData context and type for the response
	local keys = _.keys(response)
	if #keys < 14 then
		local select_list = turbo.util.join(",", keys)
		self:set_context(CONSTANTS.VOLUME_INSTANCE_CONTEXT .. "(" .. select_list .. ")")
	else
		self:set_context(CONSTANTS.VOLUME_INSTANCE_CONTEXT .. "(*)")
	end
  
	self:set_type(CONSTANTS.VOLUME_TYPE)
	self:set_allow_header("GET,PATCH")
	self:set_response(response)
	self:output()
end

function VolumeInstanceHandler:patch(url_capture0, url_capture1, url_capture2)
	local response = {}
	local url_segments = self:get_url_segments()
	if self:can_user_do("ConfigureComponents") == true then
		local redis = self:get_db()
		local successful_sets = {}
		local request_data = turbo.escape.json_decode(self:get_request().body)
		local prefix = "Redfish:" .. table.concat(url_segments, ":")
		self:set_scope(prefix)
		local pl = redis:pipeline()
		local extended = {}
		if type(request_data.Encrypted) ~= "nil" then
			if type(request_data.Encrypted) ~= "boolean" then
				table.insert(extended, self:create_message("Base", "PropertyValueTypeError", {"#/Encrypted"}, {tostring(request_data.Encrypted) .. "(" .. type(request_data.Encrypted) .. ")", "Encrypted"}))
			else
				pl:set(prefix .. ":Encrypted", tostring(request_data.Encrypted))
				table.insert(successful_sets, "Encrypted")
			end
			request_data.Encrypted = nil
		end
		if type(request_data.EncryptionTypes) ~= "nil" then
			if type(request_data.EncryptionTypes) == "table" then
				local EncryptionTypes_allowed = {"NativeDriveEncryption", "ControllerAssisted", "SoftwareAssisted"}
				pl:del(prefix .. ":EncryptionTypes")
				for _index, entry in pairs(request_data.EncryptionTypes) do

					if _.any(EncryptionTypes_allowed, function(i) return i == entry end) then
--						print("Patch")
						pl:sadd(prefix .. ":EncryptionTypes" , entry)
					end
				end
			end
			request_data.EncryptionTypes = nil
		end

		if type(request_data.Identifiers) ~= "nil" then
			local Identifiers_allowed = {"DurableName", "DurableNameFormat"}
			if type(request_data.Identifiers) == "table" then
				-- delete all keys in hset
				pl:del(prefix .. ":Identifiers:")

				for _index, entry in pairs(request_data.Identifiers) do

					for set_keys ,set_value in pairs(entry) do
						-- hset keys for each of set
						if _.any(Identifiers_allowed, function(i) return i == set_keys end) then
--							print("Patch")
							pl:hset(prefix .. ":Identifiers:", ":" .. _index  .. ":" .. set_keys, set_value)
						end
					end
				end
			end
			request_data.Identifiers = nil
		end
		if type(request_data.Operations) ~= "nil" then
			local Operations_allowed = {"OperationName", "PercentageComplete"}
			if type(request_data.Operations) == "table" then
				-- delete all keys in hset
				pl:del(prefix .. ":Operations:")

				for _index, entry in pairs(request_data.Operations) do
					for set_keys ,set_value in pairs(entry) do
						-- hset keys for each of set
						if _.any(Operations_allowed, function(i) return i == set_keys end) then
--							print("Patch")
							pl:hset(prefix .. ":Operations:", ":" .. _index  .. ":" .. set_keys, set_value)
						end
					end
				end
			end
			request_data.Operations = nil
		end
		response = self:oem_extend(response, "patch.volume-instance")
		if #pl.pending_commands > 0 then
			self:update_lastmodified(prefix, os.time(), pl)
			local result = yield(pl:run())
		end
		local leftover_fields = utils.table_len(request_data)
		if leftover_fields ~= 0 then
			local keys = _.keys(request_data)
			table.insert(extended, self:create_message("Base", "PropertyNotWritable", keys, turbo.util.join(",", keys)))
		end
		if #extended ~= 0 then
			self:add_error_body(response,400,extended)
		else
			self:set_status(204)
		end
		self:set_response(response)
		self:output()
	else
		self:error_insufficient_privilege()
	end
end
return VolumeInstanceHandler
