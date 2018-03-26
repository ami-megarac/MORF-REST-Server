-- This file was automatically generated
local pa_Manager = {
    ["Manager"] = {
        ["@odata.context"] = "r",
        ["@odata.id"] = "r",
        ["@odata.type"] = "r",
        ["Oem"] = {},
        ["Id"] = "r",
        ["Description"] = "r",
        ["Name"] = "r",
        ["ManagerType"] = "r",
        ["Links"] = "r",
        ["ServiceEntryPointUUID"] = "r",
        ["UUID"] = "r",
        ["Model"] = "r",
        ["DateTime"] = "w",
        ["DateTimeLocalOffset"] = "w",
        ["FirmwareVersion"] = "r",
        ["SerialConsole"] = {
            ["ServiceEnabled"] = "w",
            ["MaxConcurrentSessions"] = "r",
            ["ConnectTypesSupported"] = "r"
        },
        ["CommandShell"] = {
            ["ServiceEnabled"] = "w",
            ["MaxConcurrentSessions"] = "r",
            ["ConnectTypesSupported"] = "r"
        },
        ["GraphicalConsole"] = {
            ["ServiceEnabled"] = "w",
            ["MaxConcurrentSessions"] = "r",
            ["ConnectTypesSupported"] = "r"
        },
        ["Actions"] = "r",
        ["Status"] = {
            ["State"] = "r",
            ["HealthRollup"] = "r",
            ["Health"] = "r",
            ["Oem"] = {}
        },
        ["EthernetInterfaces"] = "r",
        ["SerialInterfaces"] = "r",
        ["NetworkProtocol"] = "r",
        ["LogServices"] = "r",
        ["VirtualMedia"] = "r",
        ["Redundancy@odata.count"] = "r",
        ["Redundancy@odata.navigationLink"] = {
            ["@odata.id"] = "r"
        },
        ["Redundancy"] = "r"
    }
}
return pa_Manager