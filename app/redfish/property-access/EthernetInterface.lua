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