--[[ "Plasma Core FSO script management library
;;  This system has the following objectives
;; * Streamline common aspects of FSO scripting
;; * Gently encourage a consistent structure for modules so I'll stop
;;     reinventing the wheel every time I make a new one
;; * Support interactive development with the live reloading of modules
;;     following that structure
;;
;; This code deliberately breaks with Fennel style and uses snake_case
;;   exclusively. Amoung other reasons this is intended to make the
;;   compiled code somewhat more approachable." ]]--
--[[ "Usage
;; A module designed from plasma core should be a file that returns a table of
;;   all it's functions
;; A few member names are special. All function members should have a self
;;   paramter and a paramter for the core library, which will be passed in by
;;   the library's loading function.
;;
;;  * table state: contain all gameplay state in here. It is protected from most reloads
;;  * table config: a table of all the configuration values set in user files. This is updated on reloads, but otherwise shouldn't change
;;  * fn initalize: sets up the initial state. Ideally it should also clean up
;;                    any existing state on reloads, when that state includes
;;                    things like active engine handles
;;  * fn configure: reads all configuration files and populates the config
;;                    table. Should use the load_modular_configs member of this
;;                    module configure can also set up any SEXP actions, as it
;;                    is safe to re-assign those.
;;  * fn hook: Create any hooks not specified in the -sct.tbm. Since we can't
;;               remove or replace hooks, this is only run on the initial load.
;;               hooks should thus likely call a member function that does the
;;               actual work, so that can be reloaded too.
;;               example:
;;                (fn repl.hook [self core]
;;                  (engine.addHook " On Key Pressed "
;;                    (fn [] (self:key_hook))))
" ]]--
--[[ General utility functions ]]--
local function print(output, opt_label)
  --[[ "A safe wrapper around the engine print function, prints each on it's own line" ]]--
  local label
  if (nil == opt_label) then
    label = ""
  else
    label = opt_label
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
local function warn_once(id, text, memory)
  --[[ "Show a warning the first time something errors" ]]--
  --[[ "Must be passed a memory table and index into that table. Calling code is responsible for storing that state" ]]--
  local last
  do
    local t_8_ = memory
    if (nil ~= t_8_) then
      t_8_ = (t_8_)[id]
    else
    end
    last = t_8_
  end
  if last then
  else
    ba.warning(text)
  end
  memory[id] = true
  return nil
end
local function safe_subtable(t, name)
  --[[ "Get a table from inside a table, even if it doesn't exist" ]]--
  if (t[name] == nil) then
    t[name] = {}
  else
  end
  return t[name]
end
local function safe_global_table(name)
  --[[ "Get a global table, even if it doesn't exist" ]]--
  return safe_subtable(_G, name)
end
local function recursive_table_print(name, item, opt_d)
  --[[ "Prints a whole table recursively, in a loosely lua table format" ]]--
  if ((name ~= "_TRAVERSED") and (name ~= "metadata")) then
    local t = type(item)
    local depth
    if (opt_d == nil) then
      depth = 0
    else
      depth = opt_d
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
local function add_order(name, host, enter, frame, opt_still_valid, opt_can_target)
  --[[ "Attaches functions to a LuaAI SEXP's action hooks." ]]--
  local order = _G.mn.LuaAISEXPs[name]
  order.ActionEnter = function(...)
    return enter(host, ...)
  end
  order.ActionFrame = function(...)
    return frame(host, ...)
  end
  if opt_still_valid then
    order.Achievability = function(...)
      return opt_still_valid(host, ...)
    end
  else
  end
  if opt_can_target then
    order.TargetRestrict = function(...)
      return opt_can_target(host, ...)
    end
    return order.TargetRestrict
  else
    return nil
  end
end
local function add_sexp(name, host, action)
  --[[ "Attaches functions to a Lua SEXP's action hook." ]]--
  local sexp = _G.mn.LuaSEXPs[name]
  sexp.Action = function(...)
    return action(host, ...)
  end
  return 
end
local function get_module(self, file_name, opt_reload, opt_reset)
  --[[ "Gets or loads a module by filename." ]]--
  --[[ "If reload is true, it will reload the module's functions and configuration" ]]--
  --[[ "If reset is true, the module's state will also be reinitalized" ]]--
  --[[ "Will only attach a module's hooks on first load, as there is currently no way to replace existing hooks. Module should design hooks around this limitation." ]]--
  local modules = self:safe_subtable("modules")
  local first_load = (nil == modules[file_name])
  local reload
  if opt_reload then
    reload = opt_reload
  else
    reload = false
  end
  local reset
  if opt_reset then
    reset = opt_reset
  else
    reset = false
  end
  self.print({file_name = file_name, first_load = first_load, reload = reload, reset = reset})
  self.print(file_name)
  self.print(_G.package[file_name])
  local function _21_()
    local t_22_ = _G.package.loaded
    if (nil ~= t_22_) then
      t_22_ = (t_22_)[file_name]
    else
    end
    return t_22_
  end
  if (_21_() and (reload or (type(_G.package.loaded[file_name]) == "userdata"))) then
    _G.package.loaded[file_name] = nil
  else
  end
  local mod = require(file_name)
  if first_load then
    modules[file_name] = mod
  else
    if mod then
      self:merge_tables_recursive(mod, modules[file_name], true, {"config", "state"})
    else
    end
  end
  local mod0 = modules[file_name]
  if mod0.configure then
    mod0:configure(self)
  else
  end
  if ((first_load or reset) and mod0.initialize) then
    mod0:initialize(self)
  else
  end
  if (first_load and mod0.hook) then
    mod0:hook(self)
  else
  end
  return mod0
end
local function reload_modules(self)
  --[[ "Internal module reload function, reloads but does not reset everything" ]]--
  local modules = self:safe_subtable("modules")
  for file_name, module in pairs(modules) do
    if (type(module) == "table") then
      self:get_module(file_name, true)
    else
    end
  end
  return nil
end
local function reload(self)
  --[[ "Reloads the core functions, then reloads all other modules." ]]--
  _G.package.loaded.plasma_core = nil
  do
    local new_self = require("plasma_core")
    self:merge_tables_recursive(new_self, self, true, {"modules"})
  end
  return self:reload_modules()
end
local function is_value_in(self, value, list)
  --[[ "Somewhat redundant with find, to be removed" ]]--
  if (type(list) == "table") then
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
  else
    return false
  end
end
local function merge_tables_recursive(self, source, target, opt_replace, opt_ignore)
  --[[ "Combines two tables." ]]--
  --[[ "Leaves overlapping non-table members alone unless" ]]--
  --[[ "replace is set. Always merges members that are tables" ]]--
  --[[ "ignore takes an array of keys to leave alone." ]]--
  local ignore
  if (opt_ignore == nil) then
    ignore = {}
  else
    ignore = opt_ignore
  end
  local replace
  if (opt_replace == nil) then
    replace = false
  else
    replace = opt_replace
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
--[[ "On modular configs
;;  This method is pased a function so it ca be set up to use any file format
;;  you please. Functions are provided for fennel tables and lua tables. The
;;  only requirement for a loading function is that it take a file name and
;;  returns a table, anything else is fair game.
;;               example:
;;                (let [fade_config (core:load_modular_configs :dj-f- :cfg core.config_loader_fennel)
;;                      segment_config(core:load_modular_configs :dj-s- :cfg core.config_loader_lua)]" ]]--
local function load_modular_configs(self, prefix, ext, loader)
  --[[ "Builds and returns a table by evaluating files of a given prefix" ]]--
  --[[ "takes a prefix to search for, a file extension to load, and a function" ]]--
  --[[ "that will load the files" ]]--
  local config = {}
  local files
  do
    local tbl_15_auto = {}
    local i_16_auto = #tbl_15_auto
    for _, file_name in ipairs(cf.listFiles("data/config", ("*" .. ext))) do
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
        local m_table = loader((file_name .. "." .. ext))
        if (m_table.priority == nil) then
          m_table.priority = 1
        else
        end
        val_17_auto = m_table
      end
      if (nil ~= val_17_auto) then
        i_16_auto = (i_16_auto + 1)
        do end (tbl_15_auto)[i_16_auto] = val_17_auto
      else
      end
    end
    holding = tbl_15_auto
  end
  local function _42_(l, r)
    return (l.priority < r.priority)
  end
  table.sort(holding, _42_)
  for _, mod in ipairs(holding) do
    self:merge_tables_recursive(mod, config, true, {"priority"})
  end
  return config
end
local function config_loader_fennel(file_name)
  local fennel = require("fennel")
  local full_file_name = file_name
  local file = cf.openFile(full_file_name, "r", "data/config")
  local text = file:read("*a")
  local this_table
  if (text == nil) then
    print("nil file")
    this_table = {}
  elseif (type(text) ~= "string") then
    print(("bad text type " .. type(text)))
    this_table = {}
  elseif (#text == 0) then
    print(("Empty file " .. file_name))
    this_table = {}
  else
    print((" loading modular config from " .. file_name))
    this_table = fennel.eval(text)
  end
  file:close()
  return this_table
end
local function config_loader_lua(file_name)
  local full_file_name = file_name
  local file = cf.openFile(full_file_name, "r", "data/config")
  local text = file:read("*a")
  local this_table
  if (text == nil) then
    print("nil file")
    this_table = {}
  elseif (type(text) ~= "string") then
    print(("bad text type " .. type(text)))
    this_table = {}
  elseif (#text == 0) then
    print(("Empty file " .. file_name))
    this_table = {}
  else
    print((" loading modular config from " .. file_name))
    this_table = loadstring(("return " .. text))()
  end
  file:close()
  return this_table
end
local core = {safe_subtable = safe_subtable, safe_global_table = safe_global_table, recursive_table_print = recursive_table_print, reload = reload, reload_modules = reload_modules, add_order = add_order, add_sexp = add_sexp, load_modular_configs = load_modular_configs, merge_tables_recursive = merge_tables_recursive, is_value_in = is_value_in, get_module = get_module, config_loader_fennel = config_loader_fennel, config_loader_lua = config_loader_lua, print = print, warn_once = warn_once}
local corelib = core.safe_global_table("plasma_core")
core:merge_tables_recursive(core, corelib, true, {"modules"})
return corelib