-- This file was automatically generated
local pa_Power = {
    ["Power"] = {
        ["@odata.context"] = "r",
        ["@odata.id"] = "r",
        ["@odata.type"] = "r",
        ["Oem"] = {},
        ["Id"] = "r",
        ["Description"] = "r",
        ["Name"] = "r",
        ["PowerControl@odata.count"] = "r",
        ["PowerControl@odata.navigationLink"] = {
            ["@odata.id"] = "r"
        },
        ["PowerControl"] = "r",
        ["Voltages@odata.count"] = "r",
        ["Voltages@odata.navigationLink"] = {
            ["@odata.id"] = "r"
        },
        ["Voltages"] = "r",
        ["PowerSupplies@odata.count"] = "r",
        ["PowerSupplies@odata.navigationLink"] = {
            ["@odata.id"] = "r"
        },
        ["PowerSupplies"] = "r",
        ["Redundancy@odata.count"] = "r",
        ["Redundancy@odata.navigationLink"] = {
            ["@odata.id"] = "r"
        },
        ["Redundancy"] = "r"
    },
	["powerControl"] = {
		["@odata.id"] = "w",
		["Name"] = "r",
		["PowerAllocatedWatts"] = "r",
		["PowerAvailableWatts"] = "r",
		["PowerCapacityWatts"] = "r",
		["PowerConsumedWatts"] = "r",
		["PowerLimit"] = {
			["CorrectionInMs"] = "w",
			["LimitException"] = "w",
			["LimitInWatts"] = "w"
		},
		["PowerMetrics"] = {
			["AverageConsumedWatts"] = "r",
			["IntervalInMin"] = "r",
			["MaxConsumedWatts"] = "r",
			["MinConsumedWatts"] = "r"
		},
		["PowerRequestedWatts"] = "r"
	},
  ["PowerSupply"] = {
    ["@odata.id"] = "w",
    ["Oem"] = {},
    ["MemberId"] = "r",
    ["Name"] = "r",
    ["PowerSupplyType"] = "r",
    ["LineInputVoltageType"] = "r",
    ["PowerCapacityWatts"] = "r",
    ["LastPowerOutputWatts"] = "r",
    ["Model"] = "r",
    ["FirmwareVersion"] = "r",
    ["SerialNumber"] = "r",
    ["PartNumber"] = "r",
    ["SparePartNumber"] = "r",
    ["Status"] = {
            ["State"] = "r",
            ["HealthRollup"] = "r",
            ["Health"] = "r",
            ["Oem"] = {}
          }
  },
  ["Voltage"] = {
    ["@odata.id"] = "w",
    ["Oem"] = {},
    ["MemberId"] = "r",
    ["Name"] = "r",
    ["SensorNumber"] = "r",
    ["Status"] = {
            ["State"] = "r",
            ["HealthRollup"] = "r",
            ["Health"] = "r",
            ["Oem"] = {}
          },
    ["ReadingVolts"] = "r",
    ["UpperThresholdNonCritical"] = "r",
    ["UpperThresholdCritical"] = "r",
    ["UpperThresholdFatal"] = "r",
    ["LowerThresholdNonCritical"] = "r",
    ["LowerThresholdCritical"] = "r",
    ["LowerThresholdFatal"] = "r",
    ["MinReadingRange"] = "r",
    ["MaxReadingRange"] = "r",
    ["PhysicalContext"] = "r",
    ["RelatedItem"] = "r"
  }
  
}
return pa_Power