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