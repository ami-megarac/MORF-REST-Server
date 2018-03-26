-- [See "config.lua"](./config.html)
local CONFIG = require("config")
-- [See "constants.lua"](./constants.html)
local CONSTANTS = require("constants")
-- [See "turbo library"](http://turbolua.org)
local turbo = require("turbo")

-- Import all handlers
-- [See "redfish/service-root.lua"](./redfish/service-root.html)
local ServiceRootHandler = require("redfish.service-root")
-- [See "redfish-handler.lua"](./redfish-handler.html)
local RedfishHandler = require("redfish-handler")
-- [See "odata-handler.lua"](./odata-handler.html)
local OdataHandler = require("odata-handler")
-- [See "redfish/manager.lua"](./redfish/manager.html)
local ManagerHandler = require("redfish.manager")
-- [See "redfish/manager/ethernet-interface.lua"](./redfish/manager/ethernet-interface.html)
local EthernetInterfaceHandler = require("redfish.manager.ethernet-interface")
-- [See "redfish/manager/log-service.lua"](./redfish/manager/log-service.html)
local LogServiceHandler = require("redfish.manager.log-service")
-- [See "redfish/manager/log-service-actions.lua"](./redfish/manager/log-service-actions.html)
local LogServiceActionHandler = require("redfish.manager.log-service-actions")
-- [See "redfish/manager/log-service-entries.lua"](./redfish/manager/log-service-entries.html)
local LogServiceEntriesHandler = require("redfish.manager.log-service-entries")
-- [See "redfish/manager/network-protocol.lua"](./redfish/manager/network-protocol.html)
local NetworkProtocolHandler = require("redfish.manager.network-protocol")
-- [See "redfish/manager/serial-interface.lua"](./redfish/manager/serial-interface.html)
local SerialInterfaceHandler = require("redfish.manager.serial-interface")
-- [See "redfish/manager/virtual-media.lua"](./redfish/manager/virtual-media.html)
local VirtualMediaHandler = require("redfish.manager.virtual-media")

-- [See "redfish/system.lua"](./redfish/system.html)
local SystemHandler = require("redfish.system")
-- [See "redfish/system-actions.lua"](./redfish/system-actions.html)
local SystemActionHandler = require("redfish.system-actions")
-- [See "redfish/system/ethernet-interface.lua"](./redfish/system/ethernet-interface.html)
local SystemEthernetInterfaceHandler = require("redfish.system.ethernet-interface")
-- [See "redfish/system/vlan.lua"](./redfish/system/vlan.html)
local SystemVlanHandler = require("redfish.system.vlan")
-- [See "redfish/system/log-service.lua"](./redfish/system/log-service.html)
local SystemLogServiceHandler = require("redfish.system.log-service")
-- [See "redfish/system/log-service-actions.lua"](./redfish/system/log-service-actions.html)
local SystemLogServiceActionHandler = require("redfish.system.log-service-actions")
-- [See "redfish/system/log-service-entries.lua"](./redfish/system/log-service-entries.html)
local SystemLogServiceEntriesHandler = require("redfish.system.log-service-entries")
-- [See "redfish/system/processor.lua"](./redfish/system/processor.html)
local SystemProcessorHandler = require("redfish.system.processor")
-- [See "redfish/system/memory.lua"](./redfish/system/memory.html)
local SystemMemoryHandler = require("redfish.system.memory")
-- [See "redfish/system/memorychunks.lua"](./redfish/system/memorychunks.html)
local SystemMemoryChunksHandler = require("redfish.system.memorychunks")
-- [See "redfish/system/simple-storage.lua"](./redfish/system/simple-storage.html)
local SystemSimpleStorageHandler = require("redfish.system.simple-storage")
-- [See "redfish/system/bios.lua"](./redfish/system/bios.html)
local BiosHandler = require("redfish.system.bios")
-- [See "redfish/system/bios-actions.lua"](./redfish/system/bios-actions.html)
local BiosActionsHandler = require("redfish.system.bios-actions")
-- [See "redfish/system/secure-boot.lua"](./redfish/system/secure-boot.html)
local SecureBootHandler = require("redfish.system.secureboot")
-- [See "redfish/system/secure-boot.lua"](./redfish/system/secure-boot.html)
local SecureBootActionsHandler = require("redfish.system.secureboot-actions")

-- [See "redfish/chassis.lua"](./redfish/chassis.html)
local ChassisHandler = require("redfish.chassis")
-- [See "redfish/chassis/power.lua"](./redfish/chassis/power.html)
local PowerHandler = require("redfish.chassis.power")
-- [See "redfish/chassis/thermal.lua"](./redfish/chassis/thermal.html)
local ThermalHandler = require("redfish.chassis.thermal")
-- [See "redfish/chassis/log-service-actions.lua"](./redfish/chassis/log-service-actions.html)
local ChassisLogServiceHandler = require("redfish.chassis.log-service")
-- [See "redfish/chassis/log-service-actions.lua"](./redfish/chassis/log-service-actions.html)
local ChassisLogServiceActionHandler = require("redfish.chassis.log-service-actions")
-- [See "redfish/chassis/log-service-entries.lua"](./redfish/chassis/log-service-entries.html)
local ChassisLogServiceEntriesHandler = require("redfish.chassis.log-service-entries")
-- [See sh/chassis/networkadapter-collection.lua"](./redfish/chassis/networkadapter-collection.html)
local NetworkAdapterCollectionHandler = require("redfish.chassis.networkadapter-collection")
-- [See "redfish/chassis/networkadapter-instance.lua"](./redfish/chassis/networkadapter-instance.html)
local NetworkAdapterInstanceHandler = require("redfish.chassis.networkadapter-instance")
-- [See "redfish/chassis/networkadapter-action.lua"](./redfish/chassis/networkadapter-action.html)
local NetworkAdapterActionHandler = require("redfish.chassis.networkadapter-actions")
-- [See "redfish/chassis/networkdevicefunction-collection.lua"](./redfish/chassis/networkdevicefunction-collection.html)
local NetworkDeviceFunctionCollectionHandler = require("redfish.chassis.networkdevicefunction-collection")
-- [See "redfish/chassis/pcie-devices.lua"](./redfish/chassis/pcie-devices.html)
local PCIeDeviceHandler = require("redfish.chassis.pcie-devices")
-- [See "redfish/chassis/pcie-device-functions.lua"](./redfish/chassis/pcie-device-functions.html)
local PCIeDeviceFunctionHandler = require("redfish.chassis.pcie-device-functions")

-- [See "redfish/chassis/networkdevicefunction-instance.lua"](./redfish/chassis/networkdevicefunction-instance.html)
local NetworkDeviceFunctionInstanceHandler = require("redfish.chassis.networkdevicefunction-instance")
-- [See "redfish/system/networkinterface-collection.lua"](./redfish/system/networkinterface-collection.html)
local NetworkInterfaceCollectionHandler = require("redfish.system.networkinterface-collection")
-- [See "redfish/system/networkinterface-instance.lua"](./redfish/system/networkinterface-instance.html)
local NetworkInterfaceInstanceHandler = require("redfish.system.networkinterface-instance")
-- [See "redfish/system/storage-collection.lua"](./redfish/system/storage-collection.html)
local StorageCollectionHandler = require("redfish.system.storage-collection")
-- [See "redfish/system/storage-instance.lua"](./redfish/system/storage-instance.html)
local StorageInstanceHandler = require("redfish.system.storage-instance")
-- [See "redfish/system/storage-actions.lua"](./redfish/system/storage-actions.html)
local StorageActionHandler = require("redfish.system.storage-actions")
-- [See "redfish/system/volume-collection.lua"](./redfish/system/volume-collection.html)
local VolumeCollectionHandler = require("redfish.system.volume-collection")
-- [See "redfish/system/volume-instance.lua"](./redfish/system/volume-instance.html)
local VolumeInstanceHandler = require("redfish.system.volume-instance")
-- [See "redfish/system/volume-actions.lua"](./redfish/system/volume-actions.html)
local VolumeActionHandler = require("redfish.system.volume-actions")

-- [See "redfish/account-service.lua"](./redfish/account-service.html)
local AccountServiceHandler = require("redfish.account-service")
-- [See "redfish/account-service/account.lua"](./redfish/account-service/account.html)
local AccountHandler = require("redfish.account-service.account")
-- [See "redfish/account-service/role.lua"](./redfish/account-service/role.html)
local RoleHandler = require("redfish.account-service.role")

-- [See "redfish/odata-service-root.lua"](./redfish/odata-service-root.html)
local oDataServiceRootHandler = require("redfish.odata-service-root")
-- [See "redfish/session-service.lua"](./redfish/session-service.html)
local SessionServiceHandler = require("redfish.session-service")

-- [See "redfish/event-service.lua"](./redfish/event-service.html)
local EventServiceHandler = require("redfish.event-service")

-- [See "redfish/task-service.lua"](./redfish/task-service.html)
local TaskServiceHandler = require("redfish.task-service")

-- [See "redirect-handler.lua"](./redirect-handler.html)
local RedirectHandler = require("redirect-handler")

-- [See "registry.lua"](./redfish/registry.html)
local RegistryHandler = require("redfish.registry")

-- [See "json-schema.lua"](./redfish/json-schema.html)
local JsonSchemaHandler = require("redfish.json-schema")

-- [See "default-handler.lua"](./redfish/default-handler.html)
local DefaultHandler = require("redfish.default-handler")

local HI_Enabled, HostInterfaceSupport = pcall(require, "extensions.host-interface.host-interface-support-module")
if HI_Enabled == true then
        RedfishHandler:include(HostInterfaceSupport)
end

-- Create Default Redfish routing table. This table is maps all general Redfish resource end-points. 
-- For more detail on regular expression usage, refer turbo library docs

local route_table = {
        -- ServiceRoot uses a different redirection rule than other resources (by specification), so it must be routed before RedirectHandler
        {CONFIG.SERVICE_PREFIX .. "/$", ServiceRootHandler},
        {CONFIG.SERVICE_PREFIX .. "$", RedirectHandler, CONFIG.SERVICE_PREFIX .. "/"},
        -- redirection for invalid urls
        {"(.+)/+$", RedirectHandler},
        
        {CONFIG.SERVICE_PREFIX .. "/Managers/([^/]+)/VirtualMedia/([^/]+)$", VirtualMediaHandler},
        {CONFIG.SERVICE_PREFIX .. "/Managers/([^/]+)/VirtualMedia$", VirtualMediaHandler},
        {CONFIG.SERVICE_PREFIX .. "/Managers/([^/]+)/SerialInterfaces/([^/]+)$", SerialInterfaceHandler},
        {CONFIG.SERVICE_PREFIX .. "/Managers/([^/]+)/SerialInterfaces$", SerialInterfaceHandler},
        {CONFIG.SERVICE_PREFIX .. "/Managers/([^/]+)/NetworkProtocol$", NetworkProtocolHandler},
        {CONFIG.SERVICE_PREFIX .. "/Managers/([^/]+)/LogServices/([^/]+)/Entries/([^/]+)$", LogServiceEntriesHandler},
        {CONFIG.SERVICE_PREFIX .. "/Managers/([^/]+)/LogServices/([^/]+)/Entries", LogServiceEntriesHandler},
        {CONFIG.SERVICE_PREFIX .. "/Managers/([^/]+)/LogServices/([^/]+)/Actions/([^/]+)$", LogServiceActionHandler},
        {CONFIG.SERVICE_PREFIX .. "/Managers/([^/]+)/LogServices/([^/]+)$", LogServiceHandler},
        {CONFIG.SERVICE_PREFIX .. "/Managers/([^/]+)/LogServices$", LogServiceHandler},
        {CONFIG.SERVICE_PREFIX .. "/Managers/([^/]+)/EthernetInterfaces/([^/]+)/SD$", EthernetInterfaceHandler},
        {CONFIG.SERVICE_PREFIX .. "/Managers/([^/]+)/EthernetInterfaces/([^/]+)$", EthernetInterfaceHandler},
        {CONFIG.SERVICE_PREFIX .. "/Managers/([^/]+)/EthernetInterfaces$", EthernetInterfaceHandler},
        {CONFIG.SERVICE_PREFIX .. "/Managers/([^/]+)/Actions/([^/]+)$", ManagerHandler},
        {CONFIG.SERVICE_PREFIX .. "/Managers/([^/]+)$", ManagerHandler},
        {CONFIG.SERVICE_PREFIX .. "/Managers$", ManagerHandler},

        {CONFIG.SERVICE_PREFIX .. "/Systems/([^/]+)/Processors/([^/]+)$", SystemProcessorHandler},
        {CONFIG.SERVICE_PREFIX .. "/Systems/([^/]+)/Processors$", SystemProcessorHandler},
        {CONFIG.SERVICE_PREFIX .. "/Systems/([^/]+)/SecureBoot$", SecureBootHandler},
        {CONFIG.SERVICE_PREFIX .. "/Systems/([^/]+)/SecureBoot/Actions/([^/]+)$", SecureBootHandler},
	    {CONFIG.SERVICE_PREFIX .. "/Systems/([^/]+)/Memory/([^/]+)$", SystemMemoryHandler},
        {CONFIG.SERVICE_PREFIX .. "/Systems/([^/]+)/Memory$", SystemMemoryHandler},
        {CONFIG.SERVICE_PREFIX .. "/Systems/([^/]+)/MemoryChunks/([^/]+)$", SystemMemoryChunksHandler},
        {CONFIG.SERVICE_PREFIX .. "/Systems/([^/]+)/MemoryChunks$", SystemMemoryChunksHandler},
        {CONFIG.SERVICE_PREFIX .. "/Systems/([^/]+)/SimpleStorage/([^/]+)$", SystemSimpleStorageHandler},
        {CONFIG.SERVICE_PREFIX .. "/Systems/([^/]+)/SimpleStorage$", SystemSimpleStorageHandler},
        {CONFIG.SERVICE_PREFIX .. "/Systems/([^/]+)/LogServices/([^/]+)/Entries/([^/]+)$", SystemLogServiceEntriesHandler},
        {CONFIG.SERVICE_PREFIX .. "/Systems/([^/]+)/LogServices/([^/]+)/Entries$", SystemLogServiceEntriesHandler},
        {CONFIG.SERVICE_PREFIX .. "/Systems/([^/]+)/LogServices/([^/]+)/Actions/([^/]+)$", SystemLogServiceActionHandler},
        {CONFIG.SERVICE_PREFIX .. "/Systems/([^/]+)/LogServices/([^/]+)$", SystemLogServiceHandler},
        {CONFIG.SERVICE_PREFIX .. "/Systems/([^/]+)/LogServices$", SystemLogServiceHandler},
        {CONFIG.SERVICE_PREFIX .. "/Systems/([^/]+)/EthernetInterfaces/([^/]+)/VLANs/([^/]+)$", SystemVlanHandler},
        {CONFIG.SERVICE_PREFIX .. "/Systems/([^/]+)/EthernetInterfaces/([^/]+)/VLANs$", SystemVlanHandler},
        {CONFIG.SERVICE_PREFIX .. "/Systems/([^/]+)/EthernetInterfaces/([^/]+)$", SystemEthernetInterfaceHandler},
        {CONFIG.SERVICE_PREFIX .. "/Systems/([^/]+)/EthernetInterfaces$", SystemEthernetInterfaceHandler},
        {CONFIG.SERVICE_PREFIX .. "/Systems/([^/]+)/Bios/(SD)$", BiosHandler},
        {CONFIG.SERVICE_PREFIX .. "/Systems/([^/]+)/Bios/Actions/([^/]+)$", BiosActionsHandler},
        {CONFIG.SERVICE_PREFIX .. "/Systems/([^/]+)/Bios$", BiosHandler},
        {CONFIG.SERVICE_PREFIX .. "/Systems/([^/]+)/Actions/([^/]+)$", SystemActionHandler},
        {CONFIG.SERVICE_PREFIX .. "/Systems/([^/]+)$", SystemHandler},
        {CONFIG.SERVICE_PREFIX .. "/Systems$", SystemHandler},
        -- Host Interface: Network Interface Support
        {CONFIG.SERVICE_PREFIX .. "/Systems/([^/]+)/NetworkInterfaces/([^/]+)$", NetworkInterfaceInstanceHandler},
        {CONFIG.SERVICE_PREFIX .. "/Systems/([^/]+)/NetworkInterfaces$", NetworkInterfaceCollectionHandler},
        -- Host Interface: Storage Support
        {CONFIG.SERVICE_PREFIX .. "/Systems/([^/]+)/Storage/([^/]+)/Actions/([^/]+)$", StorageActionHandler},
        {CONFIG.SERVICE_PREFIX .. "/Systems/([^/]+)/Storage/([^/]+)$", StorageInstanceHandler},
        {CONFIG.SERVICE_PREFIX .. "/Systems/([^/]+)/Storage$", StorageCollectionHandler},
        -- Host Interface: Volumn Support
        {CONFIG.SERVICE_PREFIX .. "/Systems/([^/]+)/Storage/([^/]+)/Volumes/([^/]+)/Actions/([^/]+)$", VolumeActionHandler},
        {CONFIG.SERVICE_PREFIX .. "/Systems/([^/]+)/Storage/([^/]+)/Volumes/([^/]+)$", VolumeInstanceHandler},
        {CONFIG.SERVICE_PREFIX .. "/Systems/([^/]+)/Storage/([^/]+)/Volumes$", VolumeCollectionHandler},
    
        {CONFIG.SERVICE_PREFIX .. "/Chassis/([^/]+)$", ChassisHandler},
        {CONFIG.SERVICE_PREFIX .. "/Chassis/([^/]+)/$ref$", ChassisHandler},
        {CONFIG.SERVICE_PREFIX .. "/Chassis$", ChassisHandler},
        {CONFIG.SERVICE_PREFIX .. "/Chassis/([^/]+)/Power$", PowerHandler},
        {CONFIG.SERVICE_PREFIX .. "/Chassis/([^/]+)/Thermal$", ThermalHandler},         
        {CONFIG.SERVICE_PREFIX .. "/Chassis/([^/]+)/Actions/([^/]+)$", ChassisHandler},
        {CONFIG.SERVICE_PREFIX .. "/Chassis/([^/]+)/LogServices/([^/]+)/Entries$", ChassisLogServiceEntriesHandler},
        {CONFIG.SERVICE_PREFIX .. "/Chassis/([^/]+)/LogServices/([^/]+)/Entries/([^/]+)$", ChassisLogServiceEntriesHandler},
        {CONFIG.SERVICE_PREFIX .. "/Chassis/([^/]+)/LogServices/([^/]+)/Actions/([^/]+)$", ChassisLogServiceActionHandler},
        {CONFIG.SERVICE_PREFIX .. "/Chassis/([^/]+)/LogServices/([^/]+)$", ChassisLogServiceHandler},
        {CONFIG.SERVICE_PREFIX .. "/Chassis/([^/]+)/LogServices$", ChassisLogServiceHandler},
        -- Host Interface: Network Adapter Support
        {CONFIG.SERVICE_PREFIX .. "/Chassis/([^/]+)/NetworkAdapters/([^/]+)/Actions/([^/]+)$", NetworkAdapterActionHandler},
        {CONFIG.SERVICE_PREFIX .. "/Chassis/([^/]+)/NetworkAdapters/([^/]+)$", NetworkAdapterInstanceHandler},
        {CONFIG.SERVICE_PREFIX .. "/Chassis/([^/]+)/NetworkAdapters$", NetworkAdapterCollectionHandler},
        -- Host Interface: Network Device Function Support
        {CONFIG.SERVICE_PREFIX .. "/Chassis/([^/]+)/NetworkAdapters/([^/]+)/NetworkDeviceFunctions/([^/]+)$", NetworkDeviceFunctionInstanceHandler},
        {CONFIG.SERVICE_PREFIX .. "/Chassis/([^/]+)/NetworkAdapters/([^/]+)/NetworkDeviceFunctions$", NetworkDeviceFunctionCollectionHandler},

        {CONFIG.SERVICE_PREFIX .. "/Chassis/([^/]+)/PCIeDevices/([^/]+)$", PCIeDeviceHandler},
        {CONFIG.SERVICE_PREFIX .. "/Chassis/([^/]+)/PCIeDevices/([^/]+)/Functions/([^/]+)$", PCIeDeviceFunctionHandler},

        {CONFIG.SERVICE_PREFIX .. "/AccountService/Accounts/([^/]+)$", AccountHandler},
        {CONFIG.SERVICE_PREFIX .. "/AccountService/Accounts$", AccountHandler},
        {CONFIG.SERVICE_PREFIX .. "/AccountService/Roles/([^/]+)$", RoleHandler},
        {CONFIG.SERVICE_PREFIX .. "/AccountService/Roles$", RoleHandler},
        {CONFIG.SERVICE_PREFIX .. "/AccountService$", AccountServiceHandler},

        {CONFIG.SERVICE_PREFIX .. "/SessionService/Sessions/([^/]+)$", SessionServiceHandler},
        {CONFIG.SERVICE_PREFIX .. "/SessionService/(Sessions)$", SessionServiceHandler},
        {CONFIG.SERVICE_PREFIX .. "/SessionService$", SessionServiceHandler},

        {CONSTANTS.SEND_TEST_TARGET, EventServiceHandler},
        {CONFIG.SERVICE_PREFIX .. "/EventService/Subscriptions/([^/]+)$", EventServiceHandler},
        {CONFIG.SERVICE_PREFIX .. "/EventService/(Subscriptions)/(Members)$", EventServiceHandler},
        {CONFIG.SERVICE_PREFIX .. "/EventService/(Subscriptions)$", EventServiceHandler},
        {CONFIG.SERVICE_PREFIX .. "/EventService$", EventServiceHandler},

        {CONFIG.SERVICE_PREFIX .. "/TaskService/Tasks/([^/]+)$", TaskServiceHandler},
        {CONFIG.SERVICE_PREFIX .. "/TaskService/(Tasks)/(Members)$", TaskServiceHandler},
        {CONFIG.SERVICE_PREFIX .. "/TaskService/(Tasks)$", TaskServiceHandler},
        {CONFIG.SERVICE_PREFIX .. "/TaskService$", TaskServiceHandler},

        {CONFIG.SERVICE_PREFIX .. "/Registries/Static/([^/]+)$", RegistryHandler},
        {CONFIG.SERVICE_PREFIX .. "/Registries/([^/]+)$", RegistryHandler},
        {CONFIG.SERVICE_PREFIX .. "/Registries$", RegistryHandler},

        {CONFIG.SERVICE_PREFIX .. "/JsonSchemas/([^/]+)$", JsonSchemaHandler},
        {CONFIG.SERVICE_PREFIX .. "/JsonSchemas$", JsonSchemaHandler},

        {CONFIG.SERVICE_PREFIX .. "/odata/$", oDataServiceRootHandler},
        {CONFIG.SERVICE_PREFIX .. "/odata$", oDataServiceRootHandler},
        --{CONFIG.SERVICE_PREFIX .. "/($metadata)$", turbo.web.StaticFileHandler, "./static/"},
        {CONFIG.SERVICE_PREFIX .. "/($metadata)$",OdataHandler},
        {"/redfish$", RedfishHandler},
        {"/redfish.*$", DefaultHandler}
    
    }

return route_table
