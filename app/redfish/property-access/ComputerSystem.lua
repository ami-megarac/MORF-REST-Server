-- This file was automatically generated
local pa_ComputerSystem = {
    ["ComputerSystem"] = {
        ["@odata.context"] = "r",
        ["@odata.id"] = "r",
        ["@odata.type"] = "r",
        ["Oem"] = {},
        ["Id"] = "r",
        ["Description"] = "r",
        ["Name"] = "r",
        ["SystemType"] = "r",
        ["Links"] = "r",
        ["AssetTag"] = "w",
        ["Manufacturer"] = "r",
        ["Model"] = "r",
        ["SKU"] = "r",
        ["SerialNumber"] = "r",
        ["PartNumber"] = "r",
        ["UUID"] = "r",
        ["HostName"] = "w",
        ["IndicatorLED"] = "w",
        ["PowerState"] = "r",
        ["Boot"] = {
            ["BootSourceOverrideTarget"] = "w",
            ["BootSourceOverrideEnabled"] = "w",
            ["UefiTargetBootSourceOverride"] = "w"
        },
        ["BiosVersion"] = "w",
        ["ProcessorSummary"] = {
            ["Count"] = "r",
            ["Model"] = "r",
            ["Status"] = {
                ["State"] = "r",
                ["HealthRollup"] = "r",
                ["Health"] = "r",
                ["Oem"] = {}
            }
        },
        ["MemorySummary"] = {
            ["TotalSystemMemoryGiB"] = "r",
            ["Status"] = {
                ["State"] = "r",
                ["HealthRollup"] = "r",
                ["Health"] = "r",
                ["Oem"] = {}
            }
        },
        ["Actions"] = "r",
        ["Status"] = {
            ["State"] = "r",
            ["HealthRollup"] = "r",
            ["Health"] = "r",
            ["Oem"] = {}
        },
        ["Processors"] = "r",
        ["EthernetInterfaces"] = "r",
        ["SimpleStorage"] = "r",
        ["LogServices"] = "r"
    }
}
return pa_ComputerSystem