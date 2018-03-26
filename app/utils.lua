-------------
-- Utils
-- @module Utils
-- @author AMI MegaRAC
-- @license AMI
-- @copyright AMI 2015

-- [See "utils.lua"](/utils.html)
local utils = {}
-- [See "config.lua"](/config.html)
local CONFIG = require("config")
-- [See "underscore.lua"](https://mirven.github.io/underscore.lua/)
local _ = require("underscore")
-- [See "turbo library"](http://turbolua.org)
local turbo = require("turbo")
local posix_present, posix = pcall(require, "posix")
-- [See "lfs.lua"](https://keplerproject.github.io/luafilesystem/)
local lfs = require("lfs")

local yield = coroutine.yield

local ffi = require("ffi")
local jsonc_present, jsonc = pcall(ffi.load, "json-c")

-- if jsonc library is found
if jsonc_present then
ffi.cdef([[

    typedef enum json_type {
        json_type_null, json_type_boolean, json_type_double, json_type_int, json_type_object, json_type_array, json_type_string
    } json_type;

    typedef struct json_object json_object;

    struct json_object* json_tokener_parse ( const char * str );
    int json_object_is_type ( const struct json_object * obj, enum json_type type );
]])
end


--- utility to split the string according to given pattern
-- @param str String
-- @param pattern Pattern
-- @return tb1 Table which contain splited string.
utils.split = function(str, pattern)
    
    local tbl = {}

    for s in string.gmatch(str, "([^" .. pattern .. "]+)") do
        table.insert(tbl, s)
    end

    return tbl

end

--- utility to get file modified Time
-- @param file
utils.fileTime = function(file)
    
    return lfs.attributes(file).change

end

--- utility to get odata.id in array.
-- @param redis_key_table Table
-- @param strip
utils.getODataIDArray = function(redis_key_table, strip)
    local ary = {}

    for index, redis_key in pairs(redis_key_table) do
        local odata = {}
        odata["@odata.id"] = utils.getODataID(redis_key, strip)
        table.insert(ary, odata)
    end
    return ary
end

--- utility to get odata.id.
-- @param redis_key Table
-- @param strip
utils.getODataID = function(redis_key, strip)
    if strip == nil then
        strip = 0
    end

	local key_ary = redis_key and redis_key:split(":") or {}
    return CONFIG.SERVICE_PREFIX .. "/" .. table.concat(key_ary, "/", 2, #key_ary - strip)
end

--- Gets @odata.idSMBIOS links from table.
-- @param resource Resource name
-- @param instance instance name
utils.getODataIDSMBIOS = function(resource, instance)
	local arr = CONFIG.SERVICE_PREFIX .. "/" .. resource .. "/" .. instance
	return arr
end

--- utility to get the status of the string.
-- @param string 
-- @return Boolean
utils.bool = function(string)
    return string == "true" and true or false
end


--- Gets @odata.id links from a table, recurses through nested tables.
-- @param body Table contains @odata.id
-- @param arr Table
-- @param path
utils.getResourceLinks = function(body, arr, path)
    arr = arr or {}
    path = path or ""

	if type(body) == "table" then
		if body["@odata.id"] and type(body["@odata.type"]) == "string" then
            local temp_arr = {}
            temp_arr["uri"] = body["@odata.id"]
			temp_arr["path"] = path
            table.insert(arr, temp_arr)
		else
			for prop, value in pairs(body) do
                if type(prop) == "string" and not prop:find("@") then
				    utils.getResourceLinks(value, arr, path .. "/" .. prop)
                end
			end
		end
	end

end


--- Gets @odata.type links from a table, recurses through nested tables.
-- @param body Table contains @odata.id
-- @param arr Table
-- @param ignore
utils.getAnnotationLinks = function(body, arr, ignore)
    arr = arr or {}
    if type(body) == "table" then
        if body["@odata.type"] and body["@odata.type"] ~= ignore and type(body["@odata.type"]) == "string" then
            table.insert(arr, body["@odata.type"])
        else
            for prop, value in pairs(body) do
                utils.getAnnotationLinks(value, arr, ignore)
            end
        end
    end

end

-- @deprecated The next function will override this. This maintained until stable update
--- utility to Converts Hashlist to Array Eg: 0:key1 val1, 0:key2 val2, 1:key1 val3, 1:key2 val4 to [{'key1': 'val1', 'key2': val2}, {'key1': 'val3', 'key2': val4}]
-- @param hash_list Hashlist values
-- @return ary2 Converted array.
utils.convertHashListToArray = function(hash_list)
    local ary= {}
    local ary2= {}

    for key, val in pairs(hash_list) do
        if not string.find(key, ":") then
            return {}
        end

        local key_set = utils.split(key, ":")
        local ind = tonumber(key_set[1])

        if not ary[ind] then ary[ind] = {} end

        if tonumber(val) ~= nil then val = tonumber(val) end

        if val == "true" then val = true end

        if val == "false" then val = false end

        ary[ind][key_set[2]] = val
    end

    for key, val in pairs(ary) do
        table.insert(ary2, val)
    end

    return ary2
end

--- utility to Converts Hashlist to Array Eg: 0:key1 val1, 0:key2 val2, 1:key1 val3, 1:key2 val4 to [{'key1': 'val1', 'key2': val2}, {'key1': 'val3', 'key2': val4}]
-- @param hash_list Hashlist values
-- @return ary2 Converted array.
utils.convertHashListToArray = function(hash_list)
    local ary= {}
    local ary2= {}

    if not hash_list then
        return
    end

    for key, val in pairs(hash_list) do
        if not string.find(key, ":") then
            return {}
        end

        local key_set = utils.split(key, ":")
        local ind = tonumber(key_set[1])

        if not ary[ind] then ary[ind] = {} end

        if tonumber(val) ~= nil then val = tonumber(val) end

        if val == "true" then val = true end

        if val == "false" then val = false end

        if key_set[3] == nil then
            ary[ind][key_set[2]] = val
        else
            ary[ind][key_set[2]] = {}
            ary[ind][key_set[2]][key_set[3]] = val
        end
    end

    for key, val in pairs(ary) do
        table.insert(ary2, val)
    end

    return ary2
end

--- utility to check the presence of value in array
-- @param array Table
-- @param value Value to be check in Array
-- @return Boolean Return true if value present in array or else return false
utils.array_has = function(array, value)

    for k,v in pairs(array) do
        if v == value then
            return true
        end
    end

    return false

end

--- Looks through 'table' for keys from 'mapping', then uses the function entries in 'mapping' to replace 'table' entries; goes down one level while searching 'mapping' is of the form:
--- {'KeyToFindInTable' = functionToModifyValue,
---  'StringThatShouldBeNumber' = tonumber,
---  'otherKey' = otherFunc, ...
--- }
-- @param table table of Keys
-- @param mapping Mapping table
utils.deepMap = function(table, mapping)
	for key, func in pairs(mapping) do
		-- check table for keys
		if table[key] then
			if type(table[key]) == "string" or type(table[key]) == "number" then
				table[key] = func(table[key])
			end
		end
		-- check one level deeper in table
		for k, t in pairs(table) do
			if type(t) == "table" then
				if t[key] then
					if type(t[key]) == "string" or type(t[key]) == "number" then
						table[k][key] = func(table[k][key])
					end
				end
			end 
		end
	end
end

--- Utility to segerigate the readable, writeable property and return the remaining property
-- @param body The request body given by the user
-- @param access Readable, Writeable property list
-- @return readonly_found List of Readable Properties in the request body
-- @return write_found List of Writeable Properties in the request body
-- @return leftover List of Properties that are neither readable or writeable
-- Looks through 'body' for keys from 'access', and splits properties from 'body' into separate tables
-- based on whether 'access' defines them as readonly or re-writable; 'access' can and should include 
-- embedded tables, it should have the exact same structure as 'body', but should contain 'r' or 'w'
-- denoting read/write access instead of actual data (which would be in 'body')
utils.readonlyCheck = function(body, access)
    local readonly_found = {}
    local write_found = {}
    local leftover = {}
    local switch = {
        ["r"] = function (k,v)
            readonly_found[k] = v
        end,
        ["w"] = function (k,v)
            write_found[k] = v
        end
    }
    for key, val in pairs(body) do
        if type(val) == "table" and type(access[key]) == "table" then
            ro, wr = utils.readonlyCheck(val, access[key])
            readonly_found[key] = ro
            write_found[key] = wr
        elseif access[key] then
            switch[access[key]](key,val)
        else
            leftover[key] = val
        end
    end
    if next(readonly_found) == nil then readonly_found = nil end
    if next(write_found) == nil then write_found = nil end
    if next(leftover) == nil then leftover = nil end
    return readonly_found, write_found, leftover
end

--- Utility to validate the Type of Property and segerigate the readable and writeable property
-- @param body The request body given by the user
-- @param access Readable, Writeable property list
-- @param proptype Property type list 
-- @return readonly_found List of Readable Properties in the request body
-- @return write_found List of Writeable Properties in the request body
-- @return type_error List of Properties in request for which Type mismatches
-- Looks through 'body' for keys from 'access', and splits properties from 'body' into separate tables
-- based on whether 'access' defines them as readonly or re-writable; 'access' can and should include 
-- embedded tables, it should have the exact same structure as 'body', but should contain 'r' or 'w'
-- denoting read/write access instead of actual data (which would be in 'body')
utils.readonlyTypeCheck = function(body, access, proptype)
      local readonly_found = {}
      local write_found = {}
      local type_error = {}
      local switch = {
            ["r"] = function (k,v)
                  readonly_found[k] = v
            end,
            ["w"] = function (k,v)
                  write_found[k] = v
            end
      }
      for key, val in pairs(body) do
            if type(val) == "table" and type(access[key]) == "table" then
                  ro, wr,te = utils.readonlyTypeCheck(val, access[key],proptype[key])
                  readonly_found[key] = ro
                  write_found[key] = wr
                  type_error[key] = te
            elseif type(key) == "number" then
                  for key2,val2 in pairs(val) do
                        if type(val2) == "table" and type(access[key2]) == "table" then
                              ro2, wr2,te2 = utils.readonlyTypeCheck(val2, access[key2],proptype[key2])
                              readonly_found[key2] = ro2
                              write_found[key2] = wr2
                              type_error[key2] = te2  
                        elseif access[key2] then
                              if(access[key2] == "w" and type(val2) ~= proptype[key2]) then
                                    type_error[key2] = val2
                              else
                                    switch[access[key2]](key2,val2)
                              end
                        end
                  
                  end  
            elseif access[key] then
                  if(access[key] == "w" and type(val) ~= proptype[key]) then
                        type_error[key] = val
                  else
                        switch[access[key]](key,val)
                  end
            end
      end
      if next(readonly_found) == nil then readonly_found = nil end
      if next(write_found) == nil then write_found = nil end
      if next(type_error) == nil then type_error = nil end
      
      return readonly_found, write_found,type_error
end

--- utility to merge two array
-- @param a Array1
-- @param b Array2
utils.array_merge = function(a, b)
    for k,v in pairs(b) do 
        table.insert(a, v)
    end
end

--- utility to get length of the table
-- @param t Table
-- @return Lenght of the Table
utils.table_len = function(t)
    local count = 0

    if type(t) ~= 'table' then return -1 end
    
    for k in pairs (t) do
        count = count + 1
    end

    return count
end

utils.remove_nils = function(root)
    for key, val in pairs(root) do
        if type(val) == "table" then
            if utils.table_len(val) == 0 then
                root[key] = nil
            else
                root[key] = utils.remove_nils(val)
            end
        end
    end

    if utils.table_len(root) == 0 then
        root = nil
    end

    return root
end

--- utilityto validate the json string
-- @param json_str Json string
-- @return Boolean returns true if jsonc_present is not found.
utils.jsonc_validate = function(json_str)

    -- if jsonc library is found, use it to validate the JSON string argument
    if jsonc_present then

        local json_obj = jsonc.json_tokener_parse(json_str)

        return jsonc.json_object_is_type(json_obj, jsonc.json_type_null) == 0

    else
    -- else return defaults to 'true'
        return true
    end

end

--- utility to read the data from file.
-- @param filename Name of the file.
-- @return status
utils.read_from_file = function(filename)

    local f = io.open(filename, "r")
    local t = nil
    if f ~= nil then
        t = f:read("*all")
        f:close()
    end

    return t

end

--- utility to read Process id file.
-- @param filename Name of the file.
-- @return Status.
utils.read_from_pid_file = function(filename)

    local f = io.open(filename, "r")
    local t = nil
    if f ~= nil then
        t = f:read("*number")
        f:close()
    end

    return t

end

--- utility to write the data into file
-- @param filename Name of the file.
-- @param data Data to write in file.
-- @return Status 
utils.write_to_file = function(filename, data)
    
    local f = io.open(filename, "w")
    local status = f:write(data)
    f:close()

    return status

end

--- utility to create sub process using lua posix
-- @param lj_task Task id
-- @param ...
utils.sub_process = function(lj_task, ...)

    if not posix_present then return end

    local pid = posix.fork()
    if pid < 0 then
        turbo.log.error("Forking process failed:" .. lj_task)
        posix._exit(1)
    elseif pid == 0 then
        local wait = posix.execp("luajit",lj_task, ...)
        posix._exit(0)
    else
        posix.wait(pid)
    end    

end

--- utility to create sub process using lua posix in non blocking fashion.
-- @param lj_task Task id
-- @param ...
utils.sub_process_nonblocking = function(lj_task, ...)

    if not posix_present then return end

    local pid = posix.fork()
    if pid < 0 then
        turbo.log.error("Forking process failed:" .. lj_task)
        posix._exit(1)
    elseif pid == 0 then
        local wait = posix.execp("luajit",lj_task, ...)
        posix._exit(0)
    end    

end

--- utility to moniter the Pidfile continuosly.
-- @param pidfile Process Id file.
utils.daemon = function(pidfile)

    if not posix then return end

    local ppid = posix.getpid("ppid")
    if posix.getpid("ppid") == 1 then
        return
    end
    if pidfile then
        if posix.access(pidfile) then
            turbo.log.error("PID already exists")
            posix._exit(1)
        end
    end
    local pid = posix.fork()
    if pid < 0 then
        turbo.log.error("Daemonizing failed")
        posix._exit(1)
    elseif pid ~= 0 then
        local f = io.open(pidfile, "w")
        if f then
            f:write(string.format("%d\n", pid))
            f:close()
        else
            posix.kill(pid)
            posix.wait(pid)
            posix._exit(1)
        end
        posix._exit(0)
    end

end

--- utility to get the OEM directories.
-- @return oem_dirs OEM directories
utils.get_oem_dirs = function()
    if not posix_present then return {} end

    local files, errstr, errno = posix.dir("./oem")

    local oem_dirs = {}

    if files then
        for fi, fn in ipairs(files) do
            if fn ~= "." and fn ~= ".." then
                table.insert(oem_dirs, "oem." .. fn)
            end
        end
    else
        turbo.log.error("Unable to load OEM dirs")
    end

    return oem_dirs
end

--- utility to check equality of two tables
-- @param o1 Table1
-- @param o2 Table2
-- @param ignore_meta 
utils.table_equals = function(o1, o2, ignore_meta)
    if o1 == o2 then return true end
    local o1Type = type(o1)
    local o2Type = type(o2)
    if o1Type ~= o2Type then return false end
    if o1Type ~= 'table' then return false end

    if not ignore_mt then
        local mt1 = getmetatable(o1)
        if mt1 and mt1.__eq then
            --compare using built in method
            return o1 == o2
        end
    end

    local keySet = {}

    for key1, value1 in pairs(o1) do
        local value2 = o2[key1]
        if value2 == nil or equals(value1, value2, ignore_mt) == false then
            return false
        end
        keySet[key1] = true
    end

    for key2, _ in pairs(o2) do
        if not keySet[key2] then return false end
    end
    return true
end

--- it can also be a number in which case, it must be timezone difference in seconds
-- @param unix_timestamp Timestamp
-- @param with_timezone can be boolean in which case, the used timezone is of systems
utils.iso8601_time = function(unix_timestamp, with_timezone)
    if with_timezone then
        local tz = type(with_timezone) == "number" and with_timezone or utils.timezone()
        return os.date('%Y-%m-%dT%H:%M:%S') .. utils.tz_offset(tz)
    else
        return os.date('%Y-%m-%dT%H:%M:%SZ')        
    end
end

--- Utility to get local time
-- @return local Time
utils.timezone = function()
    local now = os.time()
    return os.difftime(now, os.time(os.date("!*t", now)))
end

--- Utility to get local time offset
-- @param timezone   Local Time Zone
-- @return string Local time offset
utils.tz_offset = function(timezone)
    local h,m = math.modf(timezone/3600)
    return string.format("%+.2d:%.2d", h, math.abs(m*60))
end

--- Utility to get non nil Keys from object
-- @param obj Table
-- @return Keys 
utils.get_non_nil_keys = function(obj)

    local keys = {}

    for k, v in pairs(obj) do
        if v ~= nil then
            table.insert(keys, k)
        end
    end

    return keys

end

--- Utility to get intersect of keys from two arrays
-- @param array1 Lua Table
-- @param array2 Lua Table
-- @return ary intersect Table with Key 
utils.intersect = function(array1, array2)

    local ary = {}

    if type(array1) ~= "table" then
        turbo.log.warning("utils.intersect : array1 is not a table!")
        array1 = {}
    end
    if type(array2) ~= "table" then
        turbo.log.warning("utils.intersect : array2 is not a table!")
        array2 = {}
    end

    for k1,v1 in pairs(array1) do

        if turbo.util.is_in(k1, array2) then
            table.insert(ary, k1)
        end

    end

    return ary

end

--- Utility to get difference of keys from two arrays
-- @param array1 Lua Table
-- @param array2 Lua Table
-- @return ary difference Table with Key 
utils.difference = function(array1, array2)

    local ary = {}

    if type(array1) ~= "table" then
        turbo.log.warning("utils.intersect : array1 is not a table!")
        array1 = {}
    end
    if type(array2) ~= "table" then
        turbo.log.warning("utils.intersect : array2 is not a table!")
        array2 = {}
    end

    for k1,v1 in pairs(array1) do

        if not turbo.util.is_in(k1, array2) then
            table.insert(ary, k1)
        end

    end

    return ary
end

--- Utility to get both intersection and difference of keys from two arrays
-- @param array1 Lua Table
-- @param array2 Lua Table
-- @return ary_in intersect Table with Key 
-- @return ary_diff difference Table with key 
utils.intersect_and_diff = function(array1, array2)

    local ary_in = {}
    local ary_diff = {}

    if type(array1) ~= "table" then
        turbo.log.warning("utils.intersect : array1 is not a table!")
        array1 = {}
    end
    if type(array2) ~= "table" then
        turbo.log.warning("utils.intersect : array2 is not a table!")
        array2 = {}
    end

    for k1,v1 in pairs(array1) do

        if turbo.util.is_in(k1, array2) then
            table.insert(ary_in, k1)
        else
            table.insert(ary_diff, k1)
        end

    end

    return ary_in, ary_diff
end

--- Utility to yield execution to turbo IOLoop until 'm_timeout' milliseconds have passed
-- Non-callback version of turbo's IOLoop:add_timeout()
-- @param m_timeout Duration of the yield (in milliseconds)
-- @param caller Optional string to show who is initiating the yield
utils.turbo_sleep = function(m_timeout, caller)
    if type(m_timeout) == "number" then
        local s_timeout = m_timeout / 1000
        local ioloop = turbo.ioloop.instance()
        local timestamp = turbo.util.gettimemonotonic() + m_timeout

        local caller = tostring(caller) or "turbo_sleep() called"
        turbo.log.warning(caller .. ": yielding to turbo.IOLoop for " .. s_timeout .. " seconds...")

        local result = coroutine.yield(turbo.async.task(ioloop.add_timeout, ioloop, timestamp))

        turbo.log.warning(caller .. ": resumed by turbo.IOLoop after " .. s_timeout .. " seconds...")
    end
end

--- filepath must be in lua require format. eg. dir.filename or dir.dir.filename
-- it must be only include subfolders under the oem folder. 
-- eg. if oem/ami/route.lua to be required. use oem_require('route')
-- eg.2  if oem/ami/system/system-collection.lua to be required. use oem_require('system.system-collection')
utils.oem_require = function(filepath)

end

--- Utility to return the timestamp of when a file or directory was last modified
-- @param filepath Path of the file
-- @return filestat object containing timestamp
-- @return filestat.mtime Time stamp
-- @return -1 (on failure) 
utils.fileTime = function(filepath)
    local filestat = posix.stat(filepath)
    return filestat and filestat.mtime or -1
end

--- Utility function to recursively merge two tables
-- @param t1 Table 1
-- @param t2 Table 2
-- @return t1 Table 1 after recursive marge with table 2
utils.recursive_table_merge = function(t1, t2)
    for k,v in pairs(t2) do
        if type(v) == "table" then
            if type(t1[k] or false) == "table" then
                utils.recursive_table_merge(t1[k] or {}, t2[k] or {})
            else
                if v == "nil" then	
					v = nil
				end	
                t1[k] = v
            end
        else
            if v == "nil" then	
			    v = nil
			end	
            t1[k] = v
        end
    end
    
    return t1
end

--- This function will add an event to the database that will trigger the EventService to send an event
-- @param db Instance of Redis database used for database operations
-- @param log_service_prefix Redis database key prefix for the log service. Example: Redfish:Managers:Self:LogServices:SEL
-- @param reg_name Name of Message Registry that contains the message for the event. Example: Base.1.0.0
-- @param msg_id ID of message for the event. Example: ResourceAtUriUnauthorized
-- @param msg_args The arguments that are needed for the given message. Example: {"/redfish/v1/Systems", "Invalid Authentication"}
-- @param[opt] entry_type The EntryType for the generated event entry. This is the EntryType in the LogEntry schema. Example: Event
-- @param[opt] entry_code The EntryCode for the generated event entry. This is the EntryCode in the LogEntry schema. Example: Informational
-- @param[opt] origin The OriginOfCondition for the generated event entry. This is the OriginOfCondition in the LogEntry schema. Example: Redfish:Systems:Self:Name
-- @param[opt] sensor_type The SensorType for the generated event entry. This is the SensorType in the LogEntry schema. Example: Fan
-- @param[opt] sensor_num The SensorNumber for the generated event entry. This is the SensorNumber in the LogEntry schema. Example: 5
-- @param[opt] event_id The EventId for the generated event entry. This is the EventId in the Event schema. Example: 12345
-- @param[opt] event_type The EventType for the generated event entry. This is the EventType in the Event schema. Example: Alert
utils.add_event_entry = function(db, log_service_prefix, reg_name, msg_id, msg_args, entry_type, entry_code, origin, sensor_type, sensor_num, event_id, event_type)
    local success
    success, reg = pcall(dofile, "/usr/local/redfish/message_registries/" .. reg_name .. ".lua")
    if not success then
        print("In add_event_entry(): Message Registry: '" .. reg_name .. "' not found!")
        return nil
    end

    if not db then
        print("In add_event_entry(): Invalid database")
        return nil
    end

    local msg_template = reg.Messages[msg_id]

    if type(msg_args) == "string" then
        msg_args = msg_args:split(",")
    elseif type(msg_args) == "number" then
        msg_args = {msg_args}
    end

    local msg_args_count = msg_args and #msg_args or 0
    if msg_args_count ~= msg_template.NumberOfArgs then
        print("In add_event_entry(): Wrong number of MessageArgs provided")
    end

    for i=1,msg_template.NumberOfArgs do
        if type(msg_args[i]) ~= msg_template.ParamTypes[i] then
            print("In add_event_entry(): MessageArg #"..i..
                            " - Expected '"..msg_template.ParamTypes[i]..
                            "', but found '"..type(msg_args[i]).."'")
        end
    end

    local replacer = function(arg) 
                        local i = tonumber(arg:sub(2))
                        return msg_args and msg_args[i] or whole 
                     end

    local message = string.gsub(msg_template.Message, "(%%%d+)", replacer)

    local reg_id = reg.Id:match("(.-%.%d+%.%d+)")

    local enabled = yield(db:get(log_service_prefix .. ":ServiceEnabled"))
    local health = yield(db:hget(log_service_prefix .. ":Status", "Health"))
    if enabled ~= "true" or health ~= "OK" then
        return
    end

    local prefix = log_service_prefix .. ":Entries:"

    local index = yield(db:zcard(prefix.."SortedIDs")) or 0

    local max_records = yield(db:get(log_service_prefix .. ":MaxNumberOfRecords"))

    if index == nil or max_records == nil then
        return
    end
    
    -- Checking if the maximum number of records has been exceeded
    if index >= tonumber(max_records) then
        local overwrite = yield(db:get(log_service_prefix .. ":OverWritePolicy"))
        -- Only handles new log entries if the overwrite policy is WrapsWhenFull
        if overwrite == "WrapsWhenFull" then
            -- Getting index of most recent entry and incrementing to find index for current entry
            index = tonumber(yield(db:zrange(prefix.."SortedIDs", index - 1, index - 1, "WITHSCORES"))[2]) + 1

            -- Finding oldest entry and deleting entry from set
            local oldest_key = yield(db:zrange(prefix.."SortedIDs", 0, 0))[1]
            yield(db:zrem(prefix.."SortedIDs", oldest_key))

            -- Deleting oldest entry data from database
            local entry_keys = yield(db:keys(oldest_key .. ":*"))
            if entry_keys then
                yield(db:del(entry_keys))
            end
        else
            return
        end
    else
        index = index + 1
    end

    local event_data = {}
    local log_data = {}
    local mset_prefix = prefix .. tostring(index) .. ":"

    if entry_type ~= nil then
        table.insert(event_data, "EntryType")
        table.insert(event_data, entry_type)
        table.insert(log_data, mset_prefix .. "EntryType")
        table.insert(log_data, entry_type)
    end

    if entry_code ~= nil then
        table.insert(event_data, "EntryCode")
        table.insert(event_data, entry_code)
        table.insert(log_data, mset_prefix .. "EntryCode")
        table.insert(log_data, entry_code)
    end

    if sensor_type ~= nil then
        table.insert(event_data, "SensorType")
        table.insert(event_data, sensor_type)
        table.insert(log_data, mset_prefix .. "SensorType")
        table.insert(log_data, sensor_type)
    end

    if sensor_num ~= nil then
        table.insert(event_data, "SensorNumber")
        table.insert(event_data, sensor_num)
        table.insert(log_data, mset_prefix .. "SensorNumber")
        table.insert(log_data, sensor_num)
    end

    if origin ~= nil then
        table.insert(event_data, "OriginOfCondition")
        table.insert(event_data, origin)
        table.insert(log_data, mset_prefix .. "OriginOfCondition")
        table.insert(log_data, origin)
    end

    if event_id ~= nil then
        table.insert(event_data, "EventId")
        table.insert(event_data, event_id)
    end

    if event_type ~= nil then
        table.insert(event_data, "EventType")
        table.insert(event_data, event_type)
    end

    yield(db:zadd(prefix .. "SortedIDs", index, prefix .. tostring(index)))
    yield(db:hmset(prefix .. tostring(index),
        "Name", "Log entry " .. tostring(index),
        "Severity", msg_template.Severity,
        "Created", utils.iso8601_time(os.time(), true),
        "EventTimestamp", utils.iso8601_time(os.time(), true),
        "Message", message,
        "MessageId", reg_id .. "." .. msg_id,
        unpack(event_data)
    ))
    yield(db:expire(prefix .. tostring(index), 30))
    
    yield(db:mset(mset_prefix .. "Name", "Log entry " .. tostring(index),
        mset_prefix .. "Severity", msg_template.Severity,
        mset_prefix .. "Created", utils.iso8601_time(os.time(), true),
        mset_prefix .. "Message", message,
        mset_prefix .. "MessageId", reg_id .. "." .. msg_id,
        unpack(log_data)
    ))

    if msg_args ~= nil then
        yield(db:sadd(mset_prefix .. "MessageArgs", unpack(msg_args)))
    end
end

--- Utility to get difference between two arrays
-- @param array1 Lua Table
-- @param array2 Lua Table
-- @return ary difference table with Key and Value
utils.differenceArray = function(array1, array2)

  local ary = {}

  if type(array1) ~= "table" then
    turbo.log.warning("utils.intersect : array1 is not a table!")
    array1 = {}
  end
  if type(array2) ~= "table" then
    turbo.log.warning("utils.intersect : array2 is not a table!")
    array2 = {}
  end

  for k1,v1 in pairs(array1) do
    if not utils.inTable(array2,k1) then
      --table.insert(ary, k1)
      table.insert(ary, k1)
    end

  end

  return ary
end

--- Utility to get intersect and difference between two arrays
-- @param array1 Lua Table
-- @param array2 Lua Table
-- @return ary_in intersect Table with Key and value
-- @return ary_diff difference Table with key and value
utils.intersect_and_diff_array = function(array1, array2)

  local ary_in = {}
  local ary_diff = {}

  if type(array1) ~= "table" then
    turbo.log.warning("utils.intersect : array1 is not a table!")
    array1 = {}
  end
  if type(array2) ~= "table" then
    turbo.log.warning("utils.intersect : array2 is not a table!")
    array2 = {}
  end

  for k1,v1 in pairs(array1) do

    if utils.inTable(array2,k1) then
      ary_in[k1] = v1
    else
      ary_diff[k1] = v1
    end

  end

  return ary_in, ary_diff
end

--- Utility to check the item in Table
-- @param tbl Any Lua Table
-- @param item key to search
utils.inTable = function(tbl, item)
  for key, value in pairs(tbl) do
    if key == item then 
      return true 
    end
  end
  return false
end


local NULL_VALUE_PROP_CONST = "666$NULLVALUEPROPERTY$666"

--- Utility to get null property list from the request body
-- @param tbl Patch Request body
-- @return nullPropertyTbl Null property Table from request
utils.nullPropertyList = function(tbl)
  --local timestamp = os.time()
  local nullPropertyTbl = {}
  for k, v in pairs(tbl) do
    if v == NULL_VALUE_PROP_CONST then
      nullPropertyTbl[k] = v
    end
  end
  return nullPropertyTbl
end

-- copies values from source to target, while checking for null properties
utils.mergeWithNullProperties = function(source, target)
    local modified = false
    if type(source) ~= "table" then
        if source == NULL_VALUE_PROP_CONST then
            modified = (target ~= nil)
            target = nil
        else
            modified = (target ~= source)
            target = source
        end
    else
        if target == nil and next(source) then
                modified = true
                target = {}
            else
        end

        for key, value in pairs(source) do

            -- merge recursively
            local new_val
            local new_mod
            new_val, new_mod = utils.mergeWithNullProperties(value, target[key])
            target[key] = new_val
            modified = modified or new_mod

        end
    end

    return target, modified
end

utils.ptr = function(t,s,d)
  local ls = s or "  "
  local ld = d or 0
  local indent = string.rep(ls, ld+1)
  if ld == 0 then print('{') end
  for i,v in pairs(t) do
    if type(v) == 'table' then
      print(indent .. i)
      ld = ld + 1
      utils.ptr(v, s, ld)
      ld = ld - 1
    else
      print(indent .. i, v)
    end
  end
  if ld == 0 then print('}') end
end

return utils
