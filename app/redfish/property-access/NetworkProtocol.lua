-- This file was automatically generated
local pa_ManagerNetworkProtocol = {
    ["ManagerNetworkProtocol"] = {
        ["@odata.context"] = "r",
        ["@odata.id"] = "r",
        ["@odata.type"] = "r",
        ["Oem"] = {},
        ["Id"] = "r",
        ["Description"] = "r",
        ["Name"] = "r",
        ["HostName"] = "r",
        ["FQDN"] = "r",
        ["HTTPS"] = {
            ["ProtocolEnabled"] = "w",
            ["Port"] = "w"
        },
        ["SNMP"] = {
            ["ProtocolEnabled"] = "r",
            ["Port"] = "r"
        },
        ["VirtualMedia"] = {
            ["ProtocolEnabled"] = "w",
            ["Port"] = "w"
        },
        ["Telnet"] = {
            ["ProtocolEnabled"] = "w",
            ["Port"] = "w"
        },
        -- TODO: change when SSDP is implemented
        ["SSDP"] = {
            ["ProtocolEnabled"] = "r",
            ["Port"] = "r",
            ["NotifyMulticastIntervalSeconds"] = "r",
            ["NotifyTTL"] = "r",
            ["NotifyIPv6Scope"] = "r"
        },
        ["IPMI"] = {
            ["ProtocolEnabled"] = "r",
            ["Port"] = "r"
        },
        ["SSH"] = {
            ["ProtocolEnabled"] = "w",
            ["Port"] = "w"
        },
        ["KVMIP"] = {
            ["ProtocolEnabled"] = "w",
            ["Port"] = "w"
        },
        ["Status"] = {
            ["State"] = "r",
            ["HealthRollup"] = "r",
            ["Health"] = "r",
            ["Oem"] = {}
        }
    }
}
return pa_ManagerNetworkProtocol
