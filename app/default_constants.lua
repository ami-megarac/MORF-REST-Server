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

-- [See "config.lua"](/config.html)
local config = require("config")
local constants = {}
-- Following are the the definition for OData Types
constants.ACCOUNT_SERVICE_TYPE = "AccountService.v1_1_0.AccountService"
constants.BIOS_TYPE = "Bios.v1_0_1.Bios"
constants.CHASSIS_TYPE = "Chassis.v1_4_0.Chassis"
constants.SYSTEM_TYPE = "ComputerSystem.v1_3_0.ComputerSystem"
constants.ETHERNET_INTERFACE_TYPE = "EthernetInterface.v1_2_0.EthernetInterface"
constants.EVENTDESTINATION_TYPE = "EventDestination.v1_1_1.EventDestination"
constants.EVENT_SERVICE_TYPE = "EventService.v1_0_3.EventService"
constants.JSON_SCHEMA_TYPE = "JsonSchemaFile.v1_0_3.JsonSchemaFile"
constants.LOG_ENTRY_TYPE = "LogEntry.v1_1_1.LogEntry"
constants.LOG_SERVICE_TYPE = "LogService.v1_0_3.LogService"
constants.MANAGER_TYPE = "Manager.v1_3_0.Manager"
constants.ACCOUNT_TYPE = "ManagerAccount.v1_0_3.ManagerAccount"
constants.NETWORK_PROTOCOL_TYPE = "ManagerNetworkProtocol.v1_1_0.ManagerNetworkProtocol"
constants.MEMORY_TYPE = "Memory.v1_1_0.Memory"
constants.MEMORYCHUNKS_TYPE = "MemoryChunk.v1_0_1.MemoryChunk"
constants.MESSAGE_TYPE = "Message.v1_0_4.Message"
constants.MESSAGE_REGISTRY_TYPE = "MessageRegistry.v1_0_3.MessageRegistry"
constants.MESSAGE_REGISTRY_FILE_TYPE = "MessageRegistryFile.v1_0_3.MessageRegistryFile"
constants.PCIE_DEVICE_TYPE = "PCIeDevice.v1_0_1.PCIeDevice"
constants.PCIE_DEVICE_FUNCTION_TYPE = "PCIeFunction.v1_0_1.PCIeFunction"
constants.SECUREBOOT_TYPE = "SecureBoot.v1_0_1.SecureBoot"
constants.POWER_TYPE = "Power.v1_2_1.Power"
constants.PROCESSOR_TYPE = "Processor.v1_0_3.Processor"
constants.ROLE_TYPE = "Role.v1_0_2.Role"
constants.SERIAL_INTERFACE_TYPE = "SerialInterface.v1_0_3.SerialInterface"
constants.SERVICE_ROOT_TYPE = "ServiceRoot.v1_1_1.ServiceRoot"
constants.SESSION_TYPE = "Session.v1_0_3.Session"
constants.SESSION_SERVICE_TYPE = "SessionService.v1_1_1.SessionService"
constants.SIMPLE_STORAGE_TYPE = "SimpleStorage.v1_1_1.SimpleStorage"
constants.TASK_TYPE = "Task.v1_0_3.Task"
constants.TASK_SERVICE_TYPE = "TaskService.v1_0_3.TaskService"
constants.THERMAL_TYPE = "Thermal.v1_2_0.Thermal"
constants.VIRTUAL_MEDIA_TYPE = "VirtualMedia.v1_0_3.VirtualMedia"
constants.VLAN_TYPE = "VLanNetworkInterface.v1_0_3.VLanNetworkInterface"
--Host Interface: Network Adapter Type
constants.NETWORKADAPTER_TYPE = "NetworkAdapter.v1_0_0.NetworkAdapter"
--Host Interface: Network Interface Type
constants.NETWORKINTERFACE_TYPE = "NetworkInterface.v1_0_0.NetworkInterface"
--Host Interface: Network Device Function Type
constants.NETWORKDEVICEFUNCTION_TYPE = "NetworkDeviceFunction.v1_0_0.NetworkDeviceFunction"
--Host Interface: Storage Type
constants.STORAGE_TYPE = "Storage.v1_1_1.Storage"
--Host Interface: Volume Type
constants.VOLUME_TYPE = "Volume.v1_0_2.Volume"
constants.PCIe_DEVICE_COLLECTION_TYPE = "PCIeDeviceCollection.PCIeDeviceCollection"
constants.PCIe_DEVICE_INSTANCE_TYPE = "PCIeDevice.v1_1_0.PCIeDevice"
constants.SETTINGS_TYPE = "Settings.v1_0_3.Settings"

constants.ETHERNET_INTERFACE_COLLECTION_TYPE = "EthernetInterfaceCollection.EthernetInterfaceCollection"
constants.VLAN_COLLECTION_TYPE = "VLanNetworkInterfaceCollection.VLanNetworkInterfaceCollection"
constants.LOG_SERVICE_COLLECTION_TYPE = "LogServiceCollection.LogServiceCollection"
constants.LOG_ENTRY_COLLECTION_TYPE = "LogEntryCollection.LogEntryCollection"
constants.SERIAL_INTERFACE_COLLECTION_TYPE = "SerialInterfaceCollection.SerialInterfaceCollection"
constants.VIRTUAL_MEDIA_COLLECTION_TYPE = "VirtualMediaCollection.VirtualMediaCollection"
constants.MANAGER_COLLECTION_TYPE = "ManagerCollection.ManagerCollection"
constants.MEMORY_COLLECTION_TYPE = "MemoryCollection.MemoryCollection"
constants.MEMORYCHUNKS_COLLECTION_TYPE = "MemoryChunkCollection.MemoryChunkCollection"
constants.CHASSIS_COLLECTION_TYPE = "ChassisCollection.ChassisCollection"
constants.MANAGER_ACCOUNT_COLLECTION_TYPE = "ManagerAccountCollection.ManagerAccountCollection"
constants.ROLE_COLLECTION_TYPE = "RoleCollection.RoleCollection"
constants.SYSTEM_COLLECTION_TYPE = "ComputerSystemCollection.ComputerSystemCollection"
constants.PROCESSORS_COLLECTION_TYPE = "ProcessorCollection.ProcessorCollection"
constants.SIMPLE_STORAGE_COLLECTION_TYPE = "SimpleStorageCollection.SimpleStorageCollection"
constants.SESSION_COLLECTION_TYPE = "SessionCollection.SessionCollection"
constants.TASK_COLLECTION_TYPE = "TaskCollection.TaskCollection"
constants.EVENTDESTINATION_COLLECTION_TYPE = "EventDestinationCollection.EventDestinationCollection"
constants.JSON_SCHEMA_COLLECTION_TYPE = "JsonSchemaFileCollection.JsonSchemaFileCollection"
constants.MESSAGE_REGISTRY_FILE_COLLECTION_TYPE = "MessageRegistryFileCollection.MessageRegistryFileCollection"
--Host Interface: Network Adapter Collection Type
constants.NETWORKADAPTER_COLLECTION_TYPE = "NetworkAdapterCollection.NetworkAdapterCollection"
--Host Interface: Network Interface Type
constants.NETWORKINTERFACE_COLLECTION_TYPE = "NetworkInterfaceCollection.NetworkInterfaceCollection"
--Host Interface: Network Device Function Type
constants.NETWORKDEVICEFUNCTION_COLLECTION_TYPE = "NetworkDeviceFunctionCollection.NetworkDeviceFunctionCollection"
--Host Interface: Storage Type
constants.STORAGE_COLLECTION_TYPE = "StorageCollection.StorageCollection"
--Host Interface: Volume Type
constants.VOLUME_COLLECTION_TYPE = "VolumeCollection.VolumeCollection"
constants.PCIe_DEVICEFUNCTION_COLLECTION_TYPE = "PCIeFunctionCollection.PCIeFunctionCollection"
constants.PCIe_DEVICEFUNCTION_INSTANCE_TYPE = "PCIeFunction.v1_1_0.PCIeFunction"

-- Following are the definitions for schema links in header
constants.SCHEMA_ROOT = "<http://redfish.dmtf.org/schemas/v1/"

constants.SCHEMA_URIS = {}
constants.SCHEMA_URIS[constants.SERVICE_ROOT_TYPE] = constants.SCHEMA_ROOT .. "ServiceRoot.v1_1_1.json>"
constants.SCHEMA_URIS[constants.NETWORK_PROTOCOL_TYPE] = constants.SCHEMA_ROOT .. "ManagerNetworkProtocol.v1_1_0.json>"
constants.SCHEMA_URIS[constants.ETHERNET_INTERFACE_TYPE] = constants.SCHEMA_ROOT .. "EthernetInterface.v1_2_0.json>"
constants.SCHEMA_URIS[constants.VLAN_TYPE] = constants.SCHEMA_ROOT .. "VLanNetworkInterface.v1_0_3.json>"
constants.SCHEMA_URIS[constants.LOG_SERVICE_TYPE] = constants.SCHEMA_ROOT .. "LogService.v1_0_3.json>"
constants.SCHEMA_URIS[constants.LOG_ENTRY_TYPE] = constants.SCHEMA_ROOT .. "LogEntry.v1_1_1.json>"
constants.SCHEMA_URIS[constants.SERIAL_INTERFACE_TYPE] = constants.SCHEMA_ROOT .. "SerialInterface.v1_0_3.json>"
constants.SCHEMA_URIS[constants.VIRTUAL_MEDIA_TYPE] = constants.SCHEMA_ROOT .. "VirtualMedia.v1_0_3.json>"
constants.SCHEMA_URIS[constants.MANAGER_TYPE] = constants.SCHEMA_ROOT .. "Manager.v1_3_0.json>"
constants.SCHEMA_URIS[constants.CHASSIS_TYPE] = constants.SCHEMA_ROOT .. "Chassis.v1_4_0.json>"
constants.SCHEMA_URIS[constants.THERMAL_TYPE] = constants.SCHEMA_ROOT .. "Thermal.v1_2_0.json>"
constants.SCHEMA_URIS[constants.POWER_TYPE] = constants.SCHEMA_ROOT .. "Power.v1_2_1.json>"
constants.SCHEMA_URIS[constants.ACCOUNT_SERVICE_TYPE] = constants.SCHEMA_ROOT .. "AccountService.v1_1_0.json>"
constants.SCHEMA_URIS[constants.ACCOUNT_TYPE] = constants.SCHEMA_ROOT .. "ManagerAccount.v1_0_3.json>"
constants.SCHEMA_URIS[constants.ROLE_TYPE] = constants.SCHEMA_ROOT .. "Role.v1_0_2.json>"
constants.SCHEMA_URIS[constants.SYSTEM_TYPE] = constants.SCHEMA_ROOT .. "ComputerSystem.v1_3_0.json>"
constants.SCHEMA_URIS[constants.PROCESSOR_TYPE] = constants.SCHEMA_ROOT .. "Processor.v1_0_3.json>"
constants.SCHEMA_URIS[constants.MEMORY_TYPE] = constants.SCHEMA_ROOT .. "Memory.v1_1_0.json>"
constants.SCHEMA_URIS[constants.MEMORYCHUNKS_TYPE] = constants.SCHEMA_ROOT .. "MemoryChunk.v1_0_1.json>"
constants.SCHEMA_URIS[constants.SIMPLE_STORAGE_TYPE] = constants.SCHEMA_ROOT .. "SimpleStorage.v1_1_1.json>"
constants.SCHEMA_URIS[constants.SESSION_SERVICE_TYPE] = constants.SCHEMA_ROOT .. "SessionService.v1_1_1.json>"
constants.SCHEMA_URIS[constants.SESSION_TYPE] = constants.SCHEMA_ROOT .. "Session.v1_0_3.json>"
constants.SCHEMA_URIS[constants.EVENT_SERVICE_TYPE] = constants.SCHEMA_ROOT .. "EventService.v1_0_3.json>"
constants.SCHEMA_URIS[constants.EVENTDESTINATION_TYPE] = constants.SCHEMA_ROOT .. "EventDestination.v1_1_1.json>"
constants.SCHEMA_URIS[constants.TASK_SERVICE_TYPE] = constants.SCHEMA_ROOT .. "TaskService.v1_0_3.json>"
constants.SCHEMA_URIS[constants.TASK_TYPE] = constants.SCHEMA_ROOT .. "Task.v1_0_3.json>"
constants.SCHEMA_URIS[constants.JSON_SCHEMA_TYPE] = constants.SCHEMA_ROOT .. "JsonSchemaFile.v1_0_3.json>"
constants.SCHEMA_URIS[constants.MESSAGE_REGISTRY_FILE_TYPE] = constants.SCHEMA_ROOT .. "MessageRegistryFile.v1_0_3.json>"
constants.SCHEMA_URIS[constants.MESSAGE_REGISTRY_TYPE] = constants.SCHEMA_ROOT .. "MessageRegistry.v1_0_3.json>"
constants.SCHEMA_URIS[constants.SETTINGS_TYPE] = constants.SCHEMA_ROOT .. "Settings.v1_0_3.json>"

constants.SCHEMA_URIS[constants.ETHERNET_INTERFACE_COLLECTION_TYPE] = constants.SCHEMA_ROOT .. "EthernetInterfaceCollection.json>"
constants.SCHEMA_URIS[constants.VLAN_COLLECTION_TYPE] = constants.SCHEMA_ROOT .. "VLanNetworkInterfaceCollection.json>"
constants.SCHEMA_URIS[constants.LOG_SERVICE_COLLECTION_TYPE] = constants.SCHEMA_ROOT .. "LogServiceCollection.json>"
constants.SCHEMA_URIS[constants.LOG_ENTRY_COLLECTION_TYPE] = constants.SCHEMA_ROOT .. "LogEntryCollection.json>"
constants.SCHEMA_URIS[constants.SERIAL_INTERFACE_COLLECTION_TYPE] = constants.SCHEMA_ROOT .. "SerialInterfaceCollection.json>"
constants.SCHEMA_URIS[constants.VIRTUAL_MEDIA_COLLECTION_TYPE] = constants.SCHEMA_ROOT .. "VirtualMediaCollection.json>"
constants.SCHEMA_URIS[constants.MANAGER_COLLECTION_TYPE] = constants.SCHEMA_ROOT .. "ManagerCollection.json>"
constants.SCHEMA_URIS[constants.CHASSIS_COLLECTION_TYPE] = constants.SCHEMA_ROOT .. "ChassisCollection.json>"
constants.SCHEMA_URIS[constants.MANAGER_ACCOUNT_COLLECTION_TYPE] = constants.SCHEMA_ROOT .. "ManagerAccountCollection.json>"
constants.SCHEMA_URIS[constants.ROLE_COLLECTION_TYPE] = constants.SCHEMA_ROOT .. "RoleCollection.json>"
constants.SCHEMA_URIS[constants.SYSTEM_COLLECTION_TYPE] = constants.SCHEMA_ROOT .. "ComputerSystemCollection.json>"
constants.SCHEMA_URIS[constants.PROCESSORS_COLLECTION_TYPE] = constants.SCHEMA_ROOT .. "ProcessorCollection.json>"
constants.SCHEMA_URIS[constants.MEMORY_COLLECTION_TYPE] = constants.SCHEMA_ROOT .. "MemoryCollection.json>"
constants.SCHEMA_URIS[constants.MEMORYCHUNKS_COLLECTION_TYPE] = constants.SCHEMA_ROOT .. "MemoryChunkCollection.json>"
constants.SCHEMA_URIS[constants.SIMPLE_STORAGE_COLLECTION_TYPE] = constants.SCHEMA_ROOT .. "SimpleStorageCollection.json>"
constants.SCHEMA_URIS[constants.SESSION_COLLECTION_TYPE] = constants.SCHEMA_ROOT .. "SessionCollection.json>"
constants.SCHEMA_URIS[constants.EVENTDESTINATION_COLLECTION_TYPE] = constants.SCHEMA_ROOT .. "EventDestinationCollection.json>"
constants.SCHEMA_URIS[constants.TASK_COLLECTION_TYPE] = constants.SCHEMA_ROOT .. "TaskCollection.json>"
constants.SCHEMA_URIS[constants.JSON_SCHEMA_COLLECTION_TYPE] = constants.SCHEMA_ROOT .. "JsonSchemaFileCollection.json>"
constants.SCHEMA_URIS[constants.MESSAGE_REGISTRY_FILE_COLLECTION_TYPE] = constants.SCHEMA_ROOT .. "MessageRegistryFileCollection.json>"
constants.SCHEMA_URIS[constants.BIOS_TYPE] = constants.SCHEMA_ROOT .. "Bios.v1_0_1.json>"
constants.SCHEMA_URIS[constants.PCIE_DEVICE_TYPE] = constants.SCHEMA_ROOT .. "PCIeDevice.v1_0_1.json>"
constants.SCHEMA_URIS[constants.PCIE_DEVICE_FUNCTION_TYPE] = constants.SCHEMA_ROOT .. "PCIeFunction.v1_0_1.json>"
constants.SCHEMA_URIS[constants.SECUREBOOT_TYPE] = constants.SCHEMA_ROOT .. "SecureBoot.v1_0_1.json>"

--Host Interface: Network Adapter Schema URIs
constants.SCHEMA_URIS[constants.NETWORKADAPTER_TYPE] = constants.SCHEMA_ROOT .. "NetworkAdapter.v1_0_0.json>"
constants.SCHEMA_URIS[constants.NETWORKADAPTER_COLLECTION_TYPE] = constants.SCHEMA_ROOT .. "NetworkAdapterCollection.json>"
--Host Interface: Network Interface Schema URIs
constants.SCHEMA_URIS[constants.NETWORKINTERFACE_TYPE] = constants.SCHEMA_ROOT .. "NetworkInterface.v1_0_0.json>"
constants.SCHEMA_URIS[constants.NETWORKINTERFACE_COLLECTION_TYPE] = constants.SCHEMA_ROOT .. "NetworkInterfaceCollection.json>"
--Host Interface: Network Device Schema URIs
constants.SCHEMA_URIS[constants.NETWORKDEVICEFUNCTION_TYPE] = constants.SCHEMA_ROOT .. "NetworkDeviceFunction.v1_0_0.json>"
constants.SCHEMA_URIS[constants.NETWORKDEVICEFUNCTION_COLLECTION_TYPE] = constants.SCHEMA_ROOT .. "NetworkDeviceFunctionCollection.json>"
--Host Interface: Storage Schema URIs
constants.SCHEMA_URIS[constants.STORAGE_TYPE] = constants.SCHEMA_ROOT .. "Storage.v1_1_1.json>"
constants.SCHEMA_URIS[constants.STORAGE_COLLECTION_TYPE] = constants.SCHEMA_ROOT .. "StorageCollection.json>"
--Host Interface: Volumn Schema URIs
constants.SCHEMA_URIS[constants.VOLUME_TYPE] = constants.SCHEMA_ROOT .. "Volume.v1_0_2.json>"
constants.SCHEMA_URIS[constants.VOLUME_COLLECTION_TYPE] = constants.SCHEMA_ROOT .. "VolumeCollection.json>"

constants.SCHEMA_URIS[constants.PCIe_DEVICE_COLLECTION_TYPE] = constants.SCHEMA_ROOT .. "PCIeDeviceCollection.json>"
constants.SCHEMA_URIS[constants.PCIe_DEVICE_INSTANCE_TYPE] = constants.SCHEMA_ROOT .. "PCIeDevice.v1_1_0.json>"

constants.SCHEMA_URIS[constants.PCIe_DEVICEFUNCTION_COLLECTION_TYPE] = constants.SCHEMA_ROOT .. "PCIeFunctionCollection.json>"
constants.SCHEMA_URIS[constants.PCIe_DEVICEFUNCTION_INSTANCE_TYPE] = constants.SCHEMA_ROOT .. "PCIeFunction.v1_1_0.json>"

-- action targets
constants.SEND_TEST_TARGET = config.SERVICE_PREFIX .. "/EventService/Actions/EventService.SubmitTestEvent"



-- enums
constants.ENUM = {}

constants.ENUM.TASK_STATE = {}
constants.ENUM.TASK_STATE.NEW = "New"
constants.ENUM.TASK_STATE.STARTING = "Starting"
constants.ENUM.TASK_STATE.RUNNING = "Running"
constants.ENUM.TASK_STATE.SUSPENDED = "Suspended"
constants.ENUM.TASK_STATE.INTERRUPTED = "Interrupted"
constants.ENUM.TASK_STATE.PENDING = "Pending"
constants.ENUM.TASK_STATE.STOPPING = "Stopping"
constants.ENUM.TASK_STATE.COMPLETED = "Completed"
constants.ENUM.TASK_STATE.KILLED = "Killed"
constants.ENUM.TASK_STATE.EXCEPTION = "Exception"
constants.ENUM.TASK_STATE.SERVICE = "Service"

-- Following are the the definition for OData Context
constants.CHASSIS_INSTANCE_CONTEXT = "Chassis.Chassis"
constants.POWER_INSTANCE_CONTEXT = "Power.Power"
constants.THERMAL_INSTANCE_CONTEXT = "Thermal.Thermal"
constants.MANAGER_INSTANCE_CONTEXT = "Manager.Manager"
constants.SYSTEMS_INSTANCE_CONTEXT = "ComputerSystem.ComputerSystem"
constants.MEMORY_INSTANCE_CONTEXT = "Memory.Memory"
constants.MEMORY_COLLECTION_CONTEXT = "MemoryCollection.MemoryCollection"
constants.MEMORYCHUNKS_COLLECTION_CONTEXT = "MemoryChunkCollection.MemoryChunkCollection"
constants.MEMORYCHUNKS_INSTANCE_CONTEXT = "MemoryChunk.MemoryChunk"
constants.SERVICE_ROOT_CONTEXT = "ServiceRoot.ServiceRoot"
constants.PROCESSOR_CONTEXT = "Processor.Processor"
constants.PROCESSORS_COLLECTION_CONTEXT = "ProcessorCollection.ProcessorCollection"
constants.STORAGE_INSTANCE_CONTEXT = "Storage.Storage"
constants.VOLUME_INSTANCE_CONTEXT = "Volume.Volume"
constants.SECUREBOOT_CONTEXT = "SecureBoot.SecureBoot"
constants.NETWORKINTERFACE_CONTEXT = "NetworkInterface.NetworkInterface"
constants.NETWORKADAPTER_CONTEXT = "NetworkAdapter.NetworkAdapter"
constants.ACCOUNTSERVICE_CONTEXT = "AccountService.AccountService"
constants.ACCOUNT_COLLECTION_CONTEXT = "ManagerAccountCollection.ManagerAccountCollection"
constants.ACCOUNT_INSTANCE_CONTEXT = "ManagerAccount.ManagerAccount"
constants.ROLE_COLLECTION_CONTEXT = "RoleCollection.RoleCollection"
constants.ROLE_INSTANCE_CONTEXT = "Role.Role"
constants.EVENTSERVICE_CONTEXT = "EventService.EventService"
constants.EVENTSERVICE_DESTINATION_COLLECTION_CONTEXT = "EventDestinationCollection.EventDestinationCollection"
constants.EVENTDESTINATION_INSTANCE_CONTEXT = "EventDestination.EventDestination"
constants.TASKSERVICE_CONTEXT = "TaskService.TaskService"
constants.TASKSERVICE_COLLECTION_CONTEXT = "TaskCollection.TaskCollection"
constants.TASKSERVICE_INSTANCE_CONTEXT = "Task.Task"
constants.JSONSCHEMA_COLLECTION_CONTEXT = "JsonSchemaFileCollection.JsonSchemaFileCollection"
constants.JSONSCHEMA_INSTANCE_CONTEXT = "JsonSchemaFile.JsonSchemaFile"
constants.CHASSIS_COLLECTION_CONTEXT = "ChassisCollection.ChassisCollection"
constants.SYSTEMS_COLLECTION_CONTEXT = "ComputerSystemCollection.ComputerSystemCollection"
constants.MANAGERS_COLLECTION_CONTEXT = "ManagerCollection.ManagerCollection"
constants.LOGSERVICE_COLLECTION_CONTEXT = "LogServiceCollection.LogServiceCollection"
constants.LOGSERVICE_INSTANCE_CONTEXT = "LogService.LogService"
constants.LOGENTRY_COLLECTION_CONTEXT = "LogEntryCollection.LogEntryCollection"
constants.LOGENTRY_INSTANCE_CONTEXT = "LogEntry.LogEntry"
constants.ETHERNET_INTERFACE_COLLECTION_CONTEXT = "EthernetInterfaceCollection.EthernetInterfaceCollection"
constants.ETHERNET_INTERFACE_INSTANCE_CONTEXT = "EthernetInterface.EthernetInterface"
constants.NETWORK_PROTOCOL_INSTANCE_CONTEXT = "ManagerNetworkProtocol.ManagerNetworkProtocol"
constants.SERIAL_INTERFACE_COLLECTION_CONTEXT = "SerialInterfaceCollection.SerialInterfaceCollection"
constants.SERIAL_INTERFACE_INSTANCE_CONTEXT = "SerialInterface.SerialInterface"
constants.VIRTUAL_MEDIA_COLLECTION_CONTEXT = "VirtualMediaCollection.VirtualMediaCollection"
constants.VIRTUAL_MEDIA_INSTANCE_CONTEXT = "VirtualMedia.VirtualMedia"
constants.BIOS_INSTANCE_CONTEXT = "Bios.Bios"
constants.SIMPLE_STORAGE_COLLECTION_CONTEXT = "SimpleStorageCollection.SimpleStorageCollection"
constants.SIMPLE_STORAGE_INSTANCE_CONTEXT = "SimpleStorage.SimpleStorage"
constants.VLAN_COLLECTION_CONTEXT = "VLanNetworkInterfaceCollection.VLanNetworkInterfaceCollection"
constants.VLAN_INSTANCE_CONTEXT = "VLanNetworkInterface.VLanNetworkInterface"
constants.SESSION_SERVICE_CONTEXT = "SessionService.SessionService"
constants.SESSION_COLLECTION_CONTEXT = "SessionCollection.SessionCollection"
constants.SESSION_INSTANCE_CONTEXT = "Session.Session"
constants.MESSAGE_REGISTRY_FILE_COLLECTION_CONTEXT = "MessageRegistryFileCollection.MessageRegistryFileCollection"
constants.MESSAGE_REGISTRY_FILE_INSTANCE_CONTEXT = "MessageRegistryFile.MessageRegistryFile"

return constants
