-- This file was automatically generated
pa_NetworkDeviceFunction = {
    ["NetworkDeviceFunction"] = {
        ["@odata.context"] = "r",
        ["@odata.id"] = "r",
        ["@odata.type"] = "r",
        ["Oem"] = {},
        ["Id"] = "r",
        ["Description"] = "r",
        ["Name"] = "r",
        ["Status"] = "w",
        ["NetDevFuncType"] = "w",
        ["DeviceEnabled"] = "w",
        ["NetDevFuncCapabilities"] = "r",
        ["Ethernet"] = "w",
        ["iSCSIBoot"] = "w",
        ["FibreChannel"] = "w",
        ["BootMode"] = "w",
        ["VirtualFunctionsEnabled"] = "r",
        ["MaxVirtualFunctions"] = "r",
        ["Links"] = {
            ["PCIeFunction"] = "r"
        },
        ["AssignablePhysicalPorts@odata.count"] = "r",
        ["AssignablePhysicalPorts@odata.navigationLink"] = "w",
        ["AssignablePhysicalPorts"] = "r",
        ["PhysicalPortAssignment"] = "r"
    }
}
return pa_NetworkDeviceFunction