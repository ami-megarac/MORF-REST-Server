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

local Lua_table_IPMI = {
    ["@Redfish.Copyright"] = "Copyright AMI 2015",
    ["@odata.type"] = "#MessageRegistry.1.0.0.MessageRegistry",
    ["Id"] = "IPMI.1.0.0",
    ["Name"] = "IPMI Message Registry",
    ["Language"] = "en",
    ["Description"] = "This registry defines messages for representing IPMI completion codes in Redfish",
    ["RegistryPrefix"] = "IPMI",
    ["RegistryVersion"] = "1.0.0",
    ["OwningEntity"] = "AMI",
    ["Messages"] = {
        ["CompletedNormally"] = {
            ["Description"] = "Command Completed Normally.",
            ["Message"] = "The request was processed and completed normally.",
            ["Severity"] = "OK",
            ["NumberOfArgs"] = 0,
            ["Resolution"] = "None"
        },
        ["NodeBusy"] = {
            ["Description"] = "Node Busy. Command could not be processed because command processing resources are temporarily unavailable.",
            ["Message"] = "The request could not be completed because the required service is busy.",
            ["Severity"] = "Critical",
            ["NumberOfArgs"] = 0,
            ["Resolution"] = "Verify other pending operations have finished and resubmit the request."
        },
        ["InvalidCommand"] = {
            ["Description"] = "Invalid Command. Used to indicate an unrecognized or unsupported command.",
            ["Message"] = "The request could not be completed due to the use of an unrecognized or unsupported IPMI command.",
            ["Severity"] = "Critical",
            ["NumberOfArgs"] = 0,
            ["Resolution"] = "None"
        },
        ["InvalidCommandForLUN"] = {
            ["Description"] = "Command invalid for given LUN.",
            ["Message"] = "The request could not be completed due to the use of an IPMI command not recognized and/or supported by the LUN it was sent to.",
            ["Severity"] = "Critical",
            ["NumberOfArgs"] = 0,
            ["Resolution"] = "None"
        },
        ["Timeout"] = {
            ["Description"] = "Timeout while processing command. Response unavailable.",
            ["Message"] = "A timeout occurred while processing the requeset. No response available.",
            ["Severity"] = "Critical",
            ["NumberOfArgs"] = 0,
            ["Resolution"] = "Verify that the IPMI service is functional and resubmit the request."
        },
        ["OutOfSpace"] = {
            ["Description"] = "Out of space. Command could not be completed because of a lack of storage space required to execute the given command operation.",
            ["Message"] = "The request could not be completed because of a lack of storage space required to execute the given command operation.",
            ["Severity"] = "Critical",
            ["NumberOfArgs"] = 0,
            ["Resolution"] = "Create additional storage space and resubmit the request."
        },
        ["NoReservation"] = {
            ["Description"] = "Reservation Canceled or Invalid Reservation ID.",
            ["Message"] = "The request could not be completed due to an invalid or cancelled IPMI Reservation ID.",
            ["Severity"] = "Critical",
            ["NumberOfArgs"] = 0,
            ["Resolution"] = "None"
        },
        ["DataTruncated"] = {
            ["Description"] = "Request data truncated.",
            ["Message"] = "The request could not be completed because an underlying IPMI request was truncated.",
            ["Severity"] = "Critical",
            ["NumberOfArgs"] = 0,
            ["Resolution"] = "Verify the request parameters and resubmit the request."
        },
        ["DataLengthInvalid"] = {
            ["Description"] = "Request data length invalid.",
            ["Message"] = "The request could not be completed because an underlying IPMI request sent an invalid data length.",
            ["Severity"] = "Critical",
            ["NumberOfArgs"] = 0,
            ["Resolution"] = "Verify the request parameters and resubmit the request."
        },
        ["DataLengthExceeded"] = {
            ["Description"] = "Request data field length limit exceeded.",
            ["Message"] = "The request could not be completed because an underlying IPMI request exceeded its data length limit.",
            ["Severity"] = "Critical",
            ["NumberOfArgs"] = 0,
            ["Resolution"] = "Verify the request parameters and resubmit the request."
        },
        ["ParamaterOutOfRange"] = {
            ["Description"] = "Parameter out of range. One or more parameters in the data field of the Request are out of range. This is different from ‘Invalid data field’ (CCh) code in that it indicates that the erroneous field(s) has a contiguous range of possible values.",
            ["Message"] = "The request could not be completed because one or more parameters were not within the range of acceptable values.",
            ["Severity"] = "Critical",
            ["NumberOfArgs"] = 0,
            ["Resolution"] = "Verify that all parameter values are valid and resubmit the request."
        },
        ["ResponseSize"] = {
            ["Description"] = "Cannot return number of requested data bytes.",
            ["Message"] = "The request could not be completed because the response was too large.",
            ["Severity"] = "Critical",
            ["NumberOfArgs"] = 0,
            ["Resolution"] = "None"
        },
        ["ResourceNotFound"] = {
            ["Description"] = "Requested Sensor, data, or record not present.",
            ["Message"] = "The request could not be completed because it referenced a sensor, record, or data field that could not be found.",
            ["Severity"] = "Critical",
            ["NumberOfArgs"] = 0,
            ["Resolution"] = "Verify that the correct resource was specified and resubmit the request."
        },
        ["InvalidRequestData"] = {
            ["Description"] = "Invalid data field in Request",
            ["Message"] = "The request could not be completed because one or more parameters were invalid.",
            ["Severity"] = "Critical",
            ["NumberOfArgs"] = 0,
            ["Resolution"] = "Verify that all parameter values are valid and resubmit the request."
        },
        ["IllegalCommand"] = {
            ["Description"] = "Command illegal for specified sensor or record type.",
            ["Message"] = "The request could not be completed due to the use of an IPMI command not recognized and/or supported by the sensor or record it was sent to.",
            ["Severity"] = "Critical",
            ["NumberOfArgs"] = 0,
            ["Resolution"] = "Verify the requested command and resource and resubmit the request."
        },
        ["NoResponse"] = {
            ["Description"] = "Command response could not be provided.",
            ["Message"] = "The request was accepted but returned with no response",
            ["Severity"] = "Critical",
            ["NumberOfArgs"] = 0,
            ["Resolution"] = "Verify the IPMI service is functional and resubmit the request."
        },
        ["CannotExecuteDuplicate"] = {
            ["Description"] = "Cannot execute duplicated request. This completion code is for devices which cannot return the response that was returned for the original instance of the request. Such devices should provide separate commands that allow the completion status of the original request to be determined. An Event Receiver does not use this completion code, but returns the 00h completion code in the response to (valid) duplicated requests.",
            ["Message"] = "The request could not be completed because it was detected as a duplicate of a previous request.",
            ["Severity"] = "Critical",
            ["NumberOfArgs"] = 0,
            ["Resolution"] = "None"
        },
        ["SDRInUpdateMode"] = {
            ["Description"] = "Command response could not be provided. SDR Repository in update mode.",
            ["Message"] = "The request could not be completed because the SDR Repository is in update mode.",
            ["Severity"] = "Critical",
            ["NumberOfArgs"] = 0,
            ["Resolution"] = "Resubmit the request after SDR Repository update is complete."
        },
        ["FirmwareInUpdateMode"] = {
            ["Description"] = "Command response could not be provided. Device in firmware update mode.",
            ["Message"] = "The request could not be completed because the device is in firmware update mode.",
            ["Severity"] = "Critical",
            ["NumberOfArgs"] = 0,
            ["Resolution"] = "Resubmit the request after the Firmware update is completed."
        },
        ["BMCInitializing"] = {
            ["Description"] = "Command response could not be provided. BMC initialization or initialization agent in progress.",
            ["Message"] = "The request could not be completed because BMC initialization is in progress",
            ["Severity"] = "Critical",
            ["NumberOfArgs"] = 0,
            ["Resolution"] = "Resubmit the request after the BMC initialization is completed."
        },
        ["DestinationUnavailable"] = {
            ["Description"] = "Destination unavailable. Cannot deliver request to selected destination. E.g. this code can be returned if a request message is targeted to SMS, but receive message queue reception is disabled for the particular channel.",
            ["Message"] = "The request could not be completed because the target destination is unavailable.",
            ["Severity"] = "Critical",
            ["NumberOfArgs"] = 0,
            ["Resolution"] = "None"
        },
        ["InsufficientPrivilege"] = {
            ["Description"] = "Cannot execute command due to insufficient privilege level or other security-based restriction (e.g. disabled for ‘firmware firewall’).",
            ["Message"] = "The request could not be completed because it was sent with insufficient privilege level or other security restriction.",
            ["Severity"] = "Critical",
            ["NumberOfArgs"] = 0,
            ["Resolution"] = "Resubmit the request with proper security clearance."
        },
        ["IncompatibleState"] = {
            ["Description"] = "Cannot execute command. Command, or request parameter(s), not supported in present state.",
            ["Message"] = "The request could not be completed because a command or request parameter is not supported in the present state.",
            ["Severity"] = "Critical",
            ["NumberOfArgs"] = 0,
            ["Resolution"] = "Verify that the service is not in a conflicting state and resubmit the request."
        },
        ["SubfunctionDisabled"] = {
            ["Description"] = "Cannot execute command. Parameter is illegal because command sub-function has been disabled or is unavailable (e.g. disabled for ‘firmware firewall’).",
            ["Message"] = "The request could not be completed because it relied on a sub-function has been disabled or is unavailable.",
            ["Severity"] = "Critical",
            ["NumberOfArgs"] = 0,
            ["Resolution"] = "Verify that the service is functional and resubmit the request."
        },
        ["UnspecifiedError"] = {
            ["Description"] = "Unspecified error.",
            ["Message"] = "The request could not be completed due to an unspecified error.",
            ["Severity"] = "Critical",
            ["NumberOfArgs"] = 0,
            ["Resolution"] = "None"
        },
        ["DeviceSpecific"] = {
            ["Description"] = "Device specific (OEM) completion code. This range is used for command-specific codes that are also specific for a particular device and version. A-priori knowledge of the device command set is required for interpretation of these codes.",
            ["Message"] = "Device specific (OEM) completion code: %1.",
            ["Severity"] = "Critical",
            ["NumberOfArgs"] = 1,
            ["ParamTypes"] = { "string" },
            ["Resolution"] = "Consult OEM documentation for the given completion code."
        },
        ["CommandSpecific"] = {
            ["Description"] = "Standard command-specific codes. This range is reserved for command-specific completion codes described by IPMI specification.",
            ["Message"] = "Standard command-specific code: %1.",
            ["Severity"] = "Critical",
            ["NumberOfArgs"] = 1,
            ["ParamTypes"] = { "string" },
            ["Resolution"] = "Consult IPMI specification for the given completion code."
        },
        ["Reserved"] = {
            ["Description"] = "Reserved completion code.",
            ["Message"] = "Reserved completion code: %1.",
            ["Severity"] = "Critical",
            ["NumberOfArgs"] = 1,
            ["ParamTypes"] = { "string" },
            ["Resolution"] = "None"
        },
        ["MediumError"] = {
            ["Description"] = "Indicates that the error occurred not during the IPMI operation, but in the communication medium.",
            ["Message"] = "An error occurred in the IPMI communication medium: %1.",
            ["Severity"] = "Critical",
            ["NumberOfArgs"] = 1,
            ["ParamTypes"] = { "string" },
            ["Resolution"] = "Verify that the IPMI service is functional and resubmit the request."
        },
    }
}

return Lua_table_IPMI