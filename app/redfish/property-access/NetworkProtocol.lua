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
