--[[ "This module implements a very minimal interpertation of https://semver.org/

See reqver-readme.md for full documentation." ]]
local function is_a(t, v)
  return (type(v) == t)
end

local function assert_version_check(self, mod_name, vers_spec, mod_vers)
  assert((nil ~= mod_vers), "Missing argument mod_vers for assert_version_check() at reqver.lua:8")
  assert((nil ~= vers_spec), "Missing argument vers_spec for assert_version_check() at reqver.lua:8")
  assert((nil ~= mod_name), "Missing argument mod_name for assert_version_check() at reqver.lua:8")
  assert((nil ~= self), "Missing argument self for assert_version_check() at reqver.lua:8")
  local outcome, message = self:version_check(vers_spec, mod_vers)
  message = "version request for module " .. mod_name .. ": " .. message
  assert(outcome, message)
  ba.println(message)
  return outcome
end

local function permissive_version_check(self, mod_name, vers_spec, mod_vers)
  assert((nil ~= mod_vers), "Missing argument mod_vers for permissive_version_check() at reqver.lua:20")
  assert((nil ~= vers_spec), "Missing argument vers_spec for permissive_version_check() at reqver.lua:20")
  assert((nil ~= mod_name), "Missing argument mod_name for permissive_version_check() at reqver.lua:20")
  assert((nil ~= self), "Missing argument self for permissive_version_check() at reqver.lua:20")
  local outcome, message = self:version_check(vers_spec, mod_vers)
  ba.println("version request for module " .. mod_name .. ": " .. message)
  return outcome
end

local function version_check(self, vers_spec, mod_vers)
  assert((nil ~= mod_vers), "Missing argument mod_vers for version_check() at reqver.lua:30")
  assert((nil ~= vers_spec), "Missing argument vers_spec for version_check() at reqver.lua:30")
  assert((nil ~= self), "Missing argument self for version_check() at reqver.lua:30")
  local mod_x,mod_y,mod_z = mod_vers[1],0,0
  if mod_vers[2] then
    mod_y = mod_vers[2]
  end
  if mod_vers[3] then
    mod_z = mod_vers[3]
  end

  local spec_x,spec_y,spec_z = vers_spec[1],0,0
  if vers_spec[2] then
    spec_y = vers_spec[2]
  end
  if vers_spec[3] then
    spec_z = vers_spec[3]
  end

  if not is_a("number", mod_x) then
    return false, ("module major version is neither nil or a number")
  elseif not is_a("number", mod_y) then
    return false, ("module minor version is neither nil or a number")
  elseif not is_a("number", mod_z) then
    return false, ("module bugfix version is neither nil or a number")
  elseif not is_a("number", spec_x) then
    return false, ("specification major version is neither nil or a number")
  elseif not is_a("number", spec_y) then
    return false, ("specification minor version is neither nil or a number")
  elseif not is_a("number", spec_z) then
    return false, ("specification bugfix version is not a number")
  elseif not (spec_x == mod_x) then
    return false, ("requested major version " .. spec_x .. ", found " .. mod_x)
  elseif not (spec_y <= mod_y) then
    return false, ("requested minor version " .. spec_y .. ", found " .. mod_y)
  --[[ "fix version test only applies if minor is equal, if minor is higher then fix number is irrelevant"]]
  elseif not (spec_y < mod_y or (spec_z <= mod_z)) then
    return false, ("requested bugfix version " .. spec_z .. ", found " .. mod_z)
  else
    return true, ("requested " .. spec_x .. "." .. spec_y .. "." .. spec_z .. ", loaded " .. mod_x .. "." .. mod_y .. "." .. mod_z .. ".")
  end
end

local function require_version(mod_name, vers_spec)
  assert((nil ~= vers_spec), "Missing argument vers_spec for require_version at reqver.lua:74")
  assert((nil ~= mod_name), "Missing argument mod_name for require_version at reqver.lua:74")
  assert(is_a("string", mod_name), ("require_version was not passed a string for the module name, was passed " .. type(mod_name) .. " instead"))
  assert(is_a("table", vers_spec), ("require_version was not passed a table for the version spec, was passed " .. type(vers_spec) .. " instead"))
  local _self = require("reqver")
  local mod = require(mod_name)
  assert(is_a("table", mod), ("require_version for " .. mod_name .. " could not load any table for the module"))
  if mod then
    local mod_vers = mod ["-reqver-version-info"]
    assert(is_a("table", mod_vers), ("require_version for " .. mod_name .. " loaded module but found no version info"))
    _self:assert_version_check(mod_name, vers_spec, mod_vers)
    return mod
  end
end

local function request_version(mod_name, vers_spec)
  assert((nil ~= vers_spec), "Missing argument vers-spec for request_version at reqver.lua:90")
  assert((nil ~= mod_name), "Missing argument mod-name for request_version at reqver.lua:90")
  assert(is_a("string", mod_name), ("request_version was not passed a string for the module name, was passed " .. type(mod_name) .. " instead"))
  assert(is_a("table", vers_spec), ("request_version was not passed a table for the version spec, was passed " .. type(vers_spec) .. " instead"))
  local _self = require("reqver")
  local mod = require(mod_name)
  local mod_vers = nil
  if not mod then
    ba.println(("request_version for " .. mod_name .. " found no module\nThis oculd mean the module is present but does not return a table on require. If so, any side effects of loading it can still take place."), flase)
    return
  else
    mod_vers = mod["-reqver-version-info"]
    if not is_a("table", mod_vers) then
      ba.println(("request_version for " .. mod_name .. " found module but no version info"), flase)
    else
      if _self:permissive_version_check(mod_name, vers_spec, mod_vers) then
        ba.println("request_version for " .. mod_name .. " succeded")
        return mod
      else
        ba.println("request_version for " .. mod_name .. " found module but failed check")
        return false
      end
    end
  end
end

local function install(self, _opt_vers_spec, _opt_optional)
  assert((nil ~= self), "Missing argument self for install at reqver.lua:117")
  local a = "reqver"
  local b= self["-reqver-version-info"]
  local c = _opt_vers_spec
  local strict = not _opt_optional
  --[[ "if a version is specified, check if we pass a version check. Otherwise install always." ]]
  local install = true
  if _opt_vers_spec then
    if strict then
      install = self:assert_version_check(a, b, c)
    else
      install = self:permissive_version_check(a, b, c)
    end
  end
  if install then
    _G.require_version = self.require_version
    _G["require-version"] = self.require_version
    _G.request_version = self.request_version
    _G["request-version"] = self.request_version
    ba.println("reqver installed")
    return self
  else
    ba.println("reqver not installed")
    return false
  end
end

return {
    ["-reqver-version-info"] = {1, 0, 0},
    require_version = require_version,
    request_version = request_version,
    install = install,
    version_check = version_check,
    assert_version_check = assert_version_check,
    permissive_version_check = permissive_version_check}