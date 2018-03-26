package.path = package.path .. ";./libs/?;./libs/?.lua;"

local settings = require('settings')

settings.apply(arg[1])