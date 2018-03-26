-- This file was automatically generated
local pa_EthernetInterface = {
    ["EthernetInterface"] = {
        ["@odata.context"] = "r",
        ["@odata.id"] = "r",
        ["@odata.type"] = "r",
        ["Oem"] = {},
        ["Id"] = "r",
        ["Description"] = "r",
        ["Name"] = "r",
        ["UefiDevicePath"] = "r",
        ["Status"] = {
            ["State"] = "r",
            ["HealthRollup"] = "r",
            ["Health"] = "r",
            ["Oem"] = {}
        },
        ["InterfaceEnabled"] = "w",
        ["PermanentMACAddress"] = "r",
        ["MACAddress"] = "w",
        ["SpeedMbps"] = "w",
        ["AutoNeg"] = "w",
        ["FullDuplex"] = "w",
        ["MTUSize"] = "w",
        ["HostName"] = "w",
        ["FQDN"] = "w",
        ["MaxIPv6StaticAddresses"] = "r",
        ["VLAN"] = {
            ["VLANEnable"] = "w",
            ["VLANId"] = "w"
        },
        ["IPv4Addresses"] = "w",
        ["IPv6AddressPolicyTable"] = "w",
        ["IPv6Addresses"] = "w",
        ["IPv6StaticAddresses"] = "w",
        ["IPv6DefaultGateway"] = "r",
        ["NameServers"] = "r",
        ["VLANs"] = "r"
    }
}
return pa_EthernetInterface