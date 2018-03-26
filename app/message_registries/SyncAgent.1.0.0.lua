local Lua_table_sync = {
    ["@Redfish.Copyright"] = "Copyright AMI 2015",
    ["@odata.type"] = "#MessageRegistry.1.0.0.MessageRegistry",
    ["Id"] = "SyncAgent.1.0.0",
    ["Name"] = "SyncAgent Message Registry",
    ["Language"] = "en",
    ["Description"] = "This registry defines messages for representing SyncAgent errors in Redfish",
    ["RegistryPrefix"] = "SyncAgent",
    ["RegistryVersion"] = "1.0.0",
    ["OwningEntity"] = "AMI",
    ["Messages"] = {
        ["SinglePortEnabled"] = {
            ["Description"] = "Indicates that the single port app feature prevented the action from being processed normally.",
            ["Message"] = "%1 cannot be changed when the single port app feature is enabled.",
            ["Severity"] = "Critical",
            ["NumberOfArgs"] = 1,
            ["ParamTypes"] = { "string" },
            ["Resolution"] = "Disable single port app feature and resubmit the request."
        },
        ["IPMISOLReadOnlyProperty"] = {
            ["Description"] = "Indicates that the serial interface property is defined by IPMI Serial-Over-LAN spec and is therefore read-only.",
            ["Message"] = "%1 is a property of an IPMI Serial-Over-LAN interface and is defined to be read-only.",
            ["Severity"] = "Critical",
            ["NumberOfArgs"] = 1,
            ["ParamTypes"] = { "string" },
            ["Resolution"] = "Remove the property from the request and resubmit the request if necessary."
        },
        ["ValueNotSupported"] = {
            ["Description"] = "Indicates that the property was not changed because the value given was not supported by the backend implementation.",
            ["Message"] = "The value '%1' for property %2 is not supported by the backend implementation for this resource.",
            ["Severity"] = "Critical",
            ["NumberOfArgs"] = 2,
            ["ParamTypes"] = { "string", "string" },
            ["Resolution"] = "Verify the request is valid and resubmit the request if necessary."
        },
        ["UnspecifiedError"] = {
            ["Description"] = "Indicates that the attempt to update the property resulted in an error with and undetermined cause.",
            ["Message"] = "An unspecified error occured while fulfilling the request, the value of %1 may have changed.",
            ["Severity"] = "Critical",
            ["NumberOfArgs"] = 1,
            ["ParamTypes"] = { "string" },
            ["Resolution"] = "Verify the state of the resource and resubmit the request if necessary."
        },
        ["PatchTimeout"] = {
            ["Description"] = "Indicates that the property was not changed or did not cause an error before a timeout occurred.",
            ["Message"] = "The timeout duration (%1s) was exceeded before the patch operation on %2 responded.",
            ["Severity"] = "Critical",
            ["NumberOfArgs"] = 2,
            ["ParamTypes"] = { "number", "string" },
            ["Resolution"] = "Verify the request is valid and resubmit the request if necessary."
        },
        ["PostTimeout"] = {
            ["Description"] = "Indicates that the property was not changed or did not cause an error before a timeout occurred.",
            ["Message"] = "The timeout duration (%1s) was exceeded before the post operation on %2 responded.",
            ["Severity"] = "Critical",
            ["NumberOfArgs"] = 2,
            ["ParamTypes"] = { "number", "string" },
            ["Resolution"] = "Verify the request is valid and resubmit the request if necessary."
        },
        ["DeleteTimeout"] = {
            ["Description"] = "Indicates that the property was not changed or did not cause an error before a timeout occurred.",
            ["Message"] = "The timeout duration (%1s) was exceeded before the delete operation on %2 responded.",
            ["Severity"] = "Critical",
            ["NumberOfArgs"] = 2,
            ["ParamTypes"] = { "number", "string" },
            ["Resolution"] = "Verify the request is valid and resubmit the request if necessary."
        },
        ["PropertyModificationNotImplemented"] = {
            ["Description"] = "Indicates that a property was given a value in the request body, but the property is not implemented as a writable property.",
            ["Message"] = "Modifying property %1 is not possible in the current implementation and cannot be assigned a value.",
            ["Severity"] = "Warning",
            ["NumberOfArgs"] = 1,
            ["ParamTypes"] = { "string" },
            ["Resolution"] = "Remove the property from the request body and resubmit the request if the operation failed."
        }
    }
}

return Lua_table_sync