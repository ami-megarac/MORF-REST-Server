-- Import required libraries
-- [See "redfish-handler.lua"](/redfish-handler.html)
local RedfishHandler = require("redfish-handler")
-- [See "constants.lua"](/constants.html)
local CONSTANTS = require("constants")
local CONFIG = require("config")
-- [See "utils.lua"](/utils.html)
local utils = require("utils")
-- [See "turbo library"](http://turbolua.org)
local turbo = require("turbo")
-- [See "underscore.lua"](https://mirven.github.io/underscore.lua/)
local _ = require("underscore")

local SystemProcessorHandler = class("SystemProcessorHandler", RedfishHandler)

local yield = coroutine.yield

-- Set the path names for system processor OEM extensions
local collection_oem_path = "system.system-processor-collection"
local instance_oem_path = "system.system-processor-instance"
SystemProcessorHandler:set_all_oem_paths(collection_oem_path, instance_oem_path)

--Handles GET requests for System Processor collection and instance
function SystemProcessorHandler:get(id1, id2)

	local response = {}
	
	if id2 == nil then
		--GET collection
		self:get_collection(response)
	else
		--GET instance
		self:get_instance(response)
	end

	self:set_response(response)

	-- GET requests must respond with the 'Allow' header specifying what methods are available for the given URL
	self:set_allow_header("GET")

	self:output()
end

-- Handles GET System Processor collection
function SystemProcessorHandler:get_collection(response)
	-- Before proceeding with the handler, we'll make sure the collection request is valid
	local collection_exists = self:parent_exists()
	self:assertTrue_404(collection_exists)

	local redis = self:get_db()
	local url_segments = self:get_url_segments();

	local collection, instance, secondary_collection = 
		url_segments[1], url_segments[2], url_segments[3]

	local prefix = "Redfish:" .. collection .. ":" .. instance .. ":" .. secondary_collection

	self:set_scope("Redfish:" .. table.concat(url_segments, ":"))

	-- Creating response
	response["Name"] = "Processors Collection"
	response["Description"] = "Collection of processors for this system"

	local odataIDs = utils.getODataIDArray(yield(redis:keys(prefix .. ":*:ProcessorArchitecture")), 1)

	response["Members@odata.count"] = #odataIDs
	response["Members"] = odataIDs

	response = self:oem_extend(response, "query." .. self:get_oem_collection_path())

	self:set_context(CONSTANTS.PROCESSORS_COLLECTION_CONTEXT)
	self:set_type(CONSTANTS.PROCESSORS_COLLECTION_TYPE)
	self:set_allow_header("GET")
end

-- Handles GET System Processor instance
function SystemProcessorHandler:get_instance(response)

	local redis = self:get_db()

	local url_segments = self:get_url_segments()
	local prefix = "Redfish:" .. table.concat(url_segments, ":")
	self:set_scope("Redfish:" .. table.concat(url_segments, ":"))

	local pl = redis:pipeline()
	pl:mget({
		prefix .. ":Name",
		prefix .. ":Description",
		prefix .. ":Socket",
		prefix .. ":ProcessorType",
		prefix .. ":ProcessorArchitecture",
		prefix .. ":InstructionSet",
		prefix .. ":ProcessorId:VendorId",
		prefix .. ":ProcessorId:IdentificationRegisters",
		prefix .. ":ProcessorId:EffectiveFamily",
		prefix .. ":ProcessorId:EffectiveModel",
		prefix .. ":ProcessorId:Step",
		prefix .. ":ProcessorId:MicrocodeInfo",
		prefix .. ":Status:State",
		prefix .. ":Status:HealthRollup",
		prefix .. ":Status:Health",
		prefix .. ":Manufacturer",
		prefix .. ":Model",
		prefix .. ":MaxSpeedMHz",
		prefix .. ":TotalCores",
		prefix .. ":TotalThreads"
	})

	local db_result = yield(pl:run())
	self:assert_resource(db_result)
	local general = unpack(db_result)

	response["Id"] = url_segments[#url_segments]
	response["Name"] = general[1]
	response["Description"] = general[2]
	response["Socket"] = general[3]
	response["ProcessorType"] = general[4]
	response["ProcessorArchitecture"] = general[5]
	response["InstructionSet"] = general[6]

	response["ProcessorId"] = {}
	response["ProcessorId"]["VendorId"] = general[7]
	response["ProcessorId"]["IdentificationRegisters"] = general[8]
	response["ProcessorId"]["EffectiveFamily"] = general[9]
	response["ProcessorId"]["EffectiveModel"] = general[10]
	response["ProcessorId"]["Step"] = general[11]
	response["ProcessorId"]["MicrocodeInfo"] = general[12]

	response["Status"] = {}
	response["Status"]["State"] = general[13]
	response["Status"]["HealthRollup"] = general[14]
	response["Status"]["Health"] = general[15]
	response["Status"]["Oem"] = {}

	response["Manufacturer"] = general[16]
	response["Model"] = general[17]
	response["MaxSpeedMHz"] = tonumber(general[18])
	response["TotalCores"] = tonumber(general[19])
	response["TotalThreads"] = tonumber(general[20])

	response = self:oem_extend(response, "query." .. self:get_oem_instance_path())

	utils.remove_nils(response)
	-- Set the OData context and type for the response
	local keys = _.keys(response)
	if #keys < 14 then
		local select_list = turbo.util.join(",", keys)
		self:set_context(CONSTANTS.PROCESSOR_CONTEXT .. "(" .. select_list .. ")")
	else
		self:set_context(CONSTANTS.PROCESSOR_CONTEXT .. "(*)")
	end

	self:set_type(CONSTANTS.PROCESSOR_TYPE)
	self:set_allow_header("GET")

end

return SystemProcessorHandler