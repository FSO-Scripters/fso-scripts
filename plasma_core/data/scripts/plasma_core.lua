local function print(output, _3flabel)
  local label
  if (nil == _3flabel) then
    label = ""
  else
    label = _3flabel
  end
  local t = type(output)
  local has_label = (0 < #label)
  local core = _G.plasma_core
  local _2_ = type(output)
  if (_2_ == "table") then
    return core.recursive_table_print(label, output)
  elseif (_2_ == "userdata") then
    local function _3_()
      if has_label then
        return " "
      else
        return ""
      end
    end
    return ba.print(("*: " .. label .. _3_() .. "is userdata\n"))
  elseif (_2_ == "string") then
    local function _4_()
      if has_label then
        return " "
      else
        return ""
      end
    end
    return ba.print(("*: " .. label .. _4_() .. output .. "\n"))
  elseif (_2_ == "Nil") then
    local function _5_()
      if has_label then
        return " "
      else
        return ""
      end
    end
    return ba.print(("*: " .. label .. _5_() .. "is nil" .. "\n"))
  elseif (_2_ == "_") then
    local function _6_()
      if has_label then
        return " "
      else
        return ""
      end
    end
    return ba.print(("*: " .. label .. _6_() .. "type " .. t .. ":" .. _G.totring(output) .. "\n"))
  else
    return nil
  end
end
local function safe_subtable(t, name)
  _G.assert((nil ~= name), "Missing argument name on plasma_core.fnl:53")
  _G.assert((nil ~= t), "Missing argument t on plasma_core.fnl:53")
  if (t[name] == nil) then
    t[name] = {}
  else
  end
  return t[name]
end
local function safe_global_table(name)
  _G.assert((nil ~= name), "Missing argument name on plasma_core.fnl:59")
  return safe_subtable(_G, name)
end
local function recursive_table_print(name, item, _3fd)
  _G.assert((nil ~= item), "Missing argument item on plasma_core.fnl:63")
  _G.assert((nil ~= name), "Missing argument name on plasma_core.fnl:63")
  if ((name ~= "_TRAVERSED") and (name ~= "metadata")) then
    local t = type(item)
    local depth
    if (_3fd == nil) then
      depth = 0
    else
      depth = _3fd
    end
    ba.print("\n-")
    for i = 1, depth do
      ba.print("  ")
    end
    ba.print((name .. " = "))
    if (t == "table") then
      if (item._TRAVERSED == true) then
        return ba.print("Circular ref")
      else
        ba.print("{")
        item._TRAVERSED = true
        for key, value in pairs(item) do
          if ((nil ~= key) and (nil ~= value)) then
            recursive_table_print(key, value, (depth + 1))
          else
          end
        end
        ba.print("\n*")
        for i = 1, depth do
          ba.print("  ")
        end
        ba.print("}")
        item._TRAVERSED = nil
        return nil
      end
    elseif (t ~= "userdata") then
      return ba.print(tostring(item))
    else
      return ba.print(("//" .. tostring(t)))
    end
  else
    return nil
  end
end
local function add_order(name, host, enter, frame, _3fstill_valid, _3fcan_target)
  _G.assert((nil ~= frame), "Missing argument frame on plasma_core.fnl:94")
  _G.assert((nil ~= enter), "Missing argument enter on plasma_core.fnl:94")
  _G.assert((nil ~= host), "Missing argument host on plasma_core.fnl:94")
  _G.assert((nil ~= name), "Missing argument name on plasma_core.fnl:94")
  local order = _G.mn.LuaAISEXPs[name]
  order.ActionEnter = function(...)
    return enter(host, ...)
  end
  order.ActionFrame = function(...)
    return frame(host, ...)
  end
  if (_3fstill_valid ~= nil) then
    order.Achievability = function(...)
      return _3fstill_valid(host, ...)
    end
  else
  end
  if (_3fcan_target ~= nil) then
    order.TargetRestrict = function(...)
      return _3fcan_target(host, ...)
    end
    return order.TargetRestrict
  else
    return nil
  end
end
local function add_sexp(name, host, action)
  _G.assert((nil ~= action), "Missing argument action on plasma_core.fnl:106")
  _G.assert((nil ~= host), "Missing argument host on plasma_core.fnl:106")
  _G.assert((nil ~= name), "Missing argument name on plasma_core.fnl:106")
  local sexp = _G.mn.LuaSEXPs[name]
  sexp.Action = function(...)
    return action(host, ...)
  end
  return 
end
local function get_module(self, file_name, _3freload, _3freset)
  _G.assert((nil ~= file_name), "Missing argument file_name on plasma_core.fnl:112")
  _G.assert((nil ~= self), "Missing argument self on plasma_core.fnl:112")
  local modules = self:safe_subtable("modules")
  local first_load = (nil == modules[file_name])
  local reload
  if (_3freload == nil) then
    reload = false
  else
    reload = _3freload
  end
  local reset
  if (_3freset == nil) then
    reset = false
  else
    reset = _3freset
  end
  self.print(file_name)
  self.print(_G.package[file_name])
  if ((_G.package.loaded[file_name] ~= nil) and (reload or (type(_G.package.loaded[file_name]) == "userdata"))) then
    _G.package.loaded[file_name] = nil
  else
  end
  local mod = require(file_name)
  if first_load then
    modules[file_name] = mod
  else
    self:merge_tables_recursive(mod, modules[file_name], true, {"config", "state"})
  end
  local mod0 = modules[file_name]
  if (nil ~= mod0.configure) then
    mod0:configure(self)
  else
  end
  if ((first_load or reset) and (nil ~= mod0.initialize)) then
    mod0:initialize(self)
  else
  end
  if (first_load and (nil ~= mod0.hook)) then
    mod0:hook(self)
  else
  end
  return mod0
end
local function reload_modules(self)
  _G.assert((nil ~= self), "Missing argument self on plasma_core.fnl:147")
  local modules = self:safe_subtable("modules")
  for file_name, module in pairs(modules) do
    if (type(module) == "table") then
      print((" Plasma Core is reloading module: " .. file_name))
      self:get_module(file_name, true)
    else
    end
  end
  return nil
end
local function reload(self)
  _G.assert((nil ~= self), "Missing argument self on plasma_core.fnl:155")
  _G.package.loaded.plasma_core = nil
  do
    local new_self = require("plasma_core")
    self:merge_tables_recursive(new_self, self, true, {"modules"})
  end
  return self:reload_modules()
end
local function is_value_in(self, value, list)
  _G.assert((nil ~= list), "Missing argument list on plasma_core.fnl:162")
  _G.assert((nil ~= value), "Missing argument value on plasma_core.fnl:162")
  _G.assert((nil ~= self), "Missing argument self on plasma_core.fnl:162")
  local found = false
  if (0 ~= #list) then
    for _, v in pairs(list) do
      if found then break end
      if (v == value) then
        found = true
      else
      end
    end
  else
  end
  return found
end
local function merge_tables_recursive(self, source, target, _3freplace, _3fignore)
  _G.assert((nil ~= target), "Missing argument target on plasma_core.fnl:171")
  _G.assert((nil ~= source), "Missing argument source on plasma_core.fnl:171")
  _G.assert((nil ~= self), "Missing argument self on plasma_core.fnl:171")
  local ignore
  if (_3fignore == nil) then
    ignore = {}
  else
    ignore = _3fignore
  end
  local replace
  if (_3freplace == nil) then
    replace = false
  else
    replace = _3freplace
  end
  for k, v in pairs(source) do
    if not self:is_value_in(k, ignore) then
      if (target[k] == nil) then
        target[k] = v
      elseif (type(v) == "table") then
        self:merge_tables_recursive(v, target[k], replace, ignore)
      elseif replace then
        target[k] = v
      else
      end
    else
    end
  end
  return nil
end
local function load_modular_configs(self, prefix)
  _G.assert((nil ~= prefix), "Missing argument prefix on plasma_core.fnl:198")
  _G.assert((nil ~= self), "Missing argument self on plasma_core.fnl:198")
  local fennel = require("fennel")
  local config = {}
  local files
  do
    local tbl_15_auto = {}
    local i_16_auto = #tbl_15_auto
    for _, file_name in ipairs(cf.listFiles("data/config", "*.cfg")) do
      local val_17_auto
      if (string.sub(file_name, 1, #prefix) == prefix) then
        val_17_auto = file_name
      else
        val_17_auto = nil
      end
      if (nil ~= val_17_auto) then
        i_16_auto = (i_16_auto + 1)
        do end (tbl_15_auto)[i_16_auto] = val_17_auto
      else
      end
    end
    files = tbl_15_auto
  end
  local holding
  do
    local tbl_15_auto = {}
    local i_16_auto = #tbl_15_auto
    for _, file_name in ipairs(files) do
      local val_17_auto
      do
        local file = cf.openFile(file_name, "r", "data/config")
        local text = file:read("*a")
        local table = fennel.eval(text)
        print((" loading modular config from " .. file_name))
        file:close()
        if (table.priority == nil) then
          table.priority = 1
        else
        end
        val_17_auto = table
      end
      if (nil ~= val_17_auto) then
        i_16_auto = (i_16_auto + 1)
        do end (tbl_15_auto)[i_16_auto] = val_17_auto
      else
      end
    end
    holding = tbl_15_auto
  end
  local function _34_(l, r)
    return (l.priority < r.priority)
  end
  table.sort(holding, _34_)
  for _, mod in ipairs(holding) do
    self:merge_tables_recursive(mod, config, true, {"priority"})
  end
  return config
end
local core = {safe_subtable = safe_subtable, safe_global_table = safe_global_table, recursive_table_print = recursive_table_print, reload = reload, reload_modules = reload_modules, add_order = add_order, add_sexp = add_sexp, load_modular_configs = load_modular_configs, merge_tables_recursive = merge_tables_recursive, is_value_in = is_value_in, get_module = get_module, print = print}
local corelib = core.safe_global_table("plasma_core")
core:merge_tables_recursive(core, corelib, true, {"modules"})
return corelib