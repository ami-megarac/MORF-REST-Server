-- [See "config.lua"](/config.html)
local config = require("config")
-- [See "underscore.lua"](https://mirven.github.io/underscore.lua/)
local _ = require("underscore")
-- [See "utils.lua"](./utils.html)
local utils = require("utils")
-- [See "luaposix"](https://github.com/luaposix/luaposix)
local posix_present, posix = pcall(require, "posix")

local constants = require("default_constants")

-- Loading in other route extensions
local files, errstr, errno = posix.dir("./extensions/constants")
if files then
    for fi, fn in ipairs(files) do
        if fn ~= "." and fn ~= ".." then
            local constants_exists, constants_extension =  pcall(dofile, "extensions/constants/" .. fn)
            if constants_exists and constants_extension ~= nil then
                constants = utils.recursive_table_merge(constants, constants_extension)
            end
        end
    end
end

local oem_dirs = utils.get_oem_dirs()
for oi, on in ipairs(oem_dirs) do

    local oem_exists, oem_constants =  pcall(require, on .. ".constants")

    if oem_exists then
        constants = utils.recursive_table_merge(constants, oem_constants)
    end

end

return constants