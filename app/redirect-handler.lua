-------------
-- Redirect-Handler module
-- @module RedirectHandler
-- @author AMI MegaRAC
-- @license AMI
-- @copyright AMI 2015


local turbo = require("turbo")
local CONFIG = require("config")

local RedfishHandler = require("redfish-handler")

local RedirectHandler = class("RedirectHandler", RedfishHandler)

--- function to perform the get operation and redirect when "/" present.
function RedirectHandler:get()
	local url_given = type(self.options) == "string"

	local PATH = url_given and self.options or self.request.headers:get_url_field(turbo.httputil.UF.PATH)
	local QUERY = self.request.headers:get_url_field(turbo.httputil.UF.QUERY)

	local redirect_path = url_given and PATH or PATH:gsub("/+$", "")
	local redirect_location = QUERY and redirect_path..'?'..QUERY or redirect_path
	self:redirect(redirect_location)
end

--- function to perform the post operation and redirect when "/" present.
function RedirectHandler:post()
  local url_given = type(self.options) == "string"
	local PATH = url_given and self.options or self.request.headers:get_url_field(turbo.httputil.UF.PATH)
	local redirect_path = url_given and PATH or PATH:gsub("/+$", "")
	local redirect_location = QUERY and redirect_path..'?'..QUERY or redirect_path
  self:set_status(307)
  self:set_header("Location", redirect_location)
  
end

--- function to perform the put operation and redirect when "/" present.
function RedirectHandler:put()
  local url_given = type(self.options) == "string"
	local PATH = url_given and self.options or self.request.headers:get_url_field(turbo.httputil.UF.PATH)
	local redirect_path = url_given and PATH or PATH:gsub("/+$", "")
	local redirect_location = QUERY and redirect_path..'?'..QUERY or redirect_path
  --set the http status to 301 - permanently redirected
  self:redirect(redirect_location, true)
end

--- function to perform the patch operation and redirect when "/" present.
function RedirectHandler:patch()
  local url_given = type(self.options) == "string"
	local PATH = url_given and self.options or self.request.headers:get_url_field(turbo.httputil.UF.PATH)
	local redirect_path = url_given and PATH or PATH:gsub("/+$", "")
	local redirect_location = QUERY and redirect_path..'?'..QUERY or redirect_path
  --set the http status to 301 - permanently redirected
  self:redirect(redirect_location, true)
end

--- function to perform the delete operation and redirect when "/" present.
function RedirectHandler:delete()
  local url_given = type(self.options) == "string"
	local PATH = url_given and self.options or self.request.headers:get_url_field(turbo.httputil.UF.PATH)
	local redirect_path = url_given and PATH or PATH:gsub("/+$", "")
	local redirect_location = QUERY and redirect_path..'?'..QUERY or redirect_path
  --set the http status to 301 - permanently redirected
  self:redirect(redirect_location, true)
end

return RedirectHandler