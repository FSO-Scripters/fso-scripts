--[[ "Plasma Core FSO script management library
  This system has the following objectives
 * Streamline common aspects of FSO scripting
 * Gently encourage a consistent structure for modules so I'll stop
     reinventing the wheel every time I make a new one
 * Support interactive development with the live reloading of modules
     following that structure

 This code deliberately breaks with Fennel style and uses snake_case
   exclusively. Amoung other reasons this is intended to make the
   compiled code somewhat more approachable." ]]
--[[ "Usage
  A module designed from plasma core should be a file that returns a table of
    functions. Fennel convention is to declare all functions as locals and then
    build a table of all the ones to be exported, but it is equally valid to
    create the table ahead and create the functions as members of it intially.

  Note: You only need to export functions that are going to be called from
    outside the module, such as the framework functions listed below, or ones
    that will be used as sexp, hook or override functions. This is required to
    have them reload properly if changed.

  Outside of those case it is perfectly valid to keep functions local to the
    module and not export them, so long as the above rules are followed.

  If a local function needs to access the module table for some reason and
    you don't want to pass it in, use get_module_namespace to obtain a safe
    reference.

  Special member names:
  All of these members are optional, but if they exist they will be treated in
    specific ways.

  Subtables:
  * state: Expected to contain all runtime state of the module. It is preserved
             durring a reload uunless specifically reset.
  * config: Expected to hold static configuration data for the module, idealy
              using load_modular_configs. This is intended to be rebuilt on
              reloads, so structure your access to it accordingly.

  Functions:
  These are all called by the loading process if they exist, and are passed the
    loading module table and the plasma core module table.
  * initalize: To set up the state table. It should also clean up any existing
                state, such as playing sounds for instance, if a reload is
                called with the reset flag.
  * configure: To read configuration files and populates the config table. This
                 should use the load_modular_configs function if possible.
               Also set SEXP actions in configure, using add_sexp, as they can
                 safely be reassigned on reloads.
  * hook: To create hooks using add_hook. add_hook creates fully reloadable
            hooks if used properly, and has support for all the features of
            -sct.tbm files.
          Hook is only ever run the first time a module is loaded, since the
            engine does not provide a way to remove or replace hooks. Consider
            using the repl if you need to add a new hook at runtime.
          An example of a hook function
                (fn hook [self core]
                  (core.add_hook(self :clear_all "On Mission About To End" ))
                  (core.add_hook(self :message_send "On Message Received")))
               or in lua
                local function hook(self, core)
                  core.add_hook(self, "clear_all", "On Mission About To End")
                  core.add_hook(self, "message_send", "On Message Received")
                end
" ]]
--[[ requirements ]]
local reqver = require("reqver")
reqver:install({1, 0, 0})
local plasma_version = {1, 0, 0}
--[[ General utility functions ]]
local function print(output, opt_label)
  --[[ "A safe wrapper around the engine print function, prints each on its own line" ]]
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
    return ba.print(("*: " .. label .. _6_() .. "type " .. t .. ":" .. tostring(output) .. "\n"))
  else
    return
  end
end
local function warn_once(id, text, memory)
  --[[ "Show a warning the first time something errors
    Must be passed a memory table and index into that table. Calling code is responsible for storing that state" ]]
  local last
  do
    local t_8_ = memory
    if (nil ~= t_8_) then
      t_8_ = (t_8_)[id]
    end
    last = t_8_
  end
  if last then
  else
    ba.warning(text)
  end
  memory[id] = true
  return
end
local function safe_subtable(t, name)
  --[[ "Get a table from inside a table, even if it doesn't exist" ]]
  if (t[name] == nil) then
    t[name] = {}
  end
  return t[name]
end
local function safe_global_table(name)
  --[[ "Get a global table, even if it doesn't exist" ]]
  return safe_subtable(_G, name)
end
local function recursive_table_print(name, item, opt_d)
  --[[ "Prints a whole table recursively, in a loosely lua table format" ]]
  if ((name ~= "_TRAVERSED") and (name ~= "metadata")) then
    local t = type(item)
    local depth
    if (opt_d == nil) then
      depth = 0
    else
      depth = opt_d
    end
    ba.print("\n-")
    if type(depth, "number") then
      for i = 1, depth do
        ba.print("  ")
      end
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
          end
        end
        ba.print("\n*")
        for i = 1, depth do
          ba.print("  ")
        end
        ba.print("}")
        item._TRAVERSED = nil
        return
      end
    elseif (t ~= "userdata") then
      return ba.print(tostring(item))
    else
      return ba.print(("//" .. tostring(t)))
    end
  else
    return
  end
end
local function maybe_make_attach_function(module, method_name, optional)
  --[[ "an internal function to build functions for hook and attach" ]]
  if (module and method_name and module[method_name] and (type(method_name) == "string")) then
    local f
    local function _18_(...)
      return module[method_name](module, ...)
    end
    f = _18_
    return f
  else
    if not optional then
      --[[ "error checking" ]]
      if (type(method_name) ~= "string") then
        return ba.error(("plasma_core.add_hook requires the method paramater to be a name. Ensure you are not passing a function reference. Was passed " .. tostring(method_name) .. " (" .. type(method_name) .. ")"))
      elseif ((module[method_name] == nil) or (type(module[method_name]) ~= "function")) then
        return ba.error(("plasma_core.add_hook could not find function named " .. method_name))
      else
        return
      end
    else
      return
    end
  end
end
local function add_order(module, order_name, enter_n, frame_n, opt_still_valid_n, opt_can_target_n)
  --[[ "currently not well tested, a helper to attach all the functions of a luaorder" ]]
  local order = _G.mn.LuaAISEXPs[order_name]
  local enter = maybe_make_attach_function(module, enter_n)
  local frame = maybe_make_attach_function(module, enter_n)
  local still_valid = maybe_make_attach_function(module, opt_still_valid_n, true)
  local can_target = maybe_make_attach_function(module, opt_can_target_n, true)
  do end (order)["ActionEnter"] = enter
  order["ActionFrame"] = frame
  if still_valid then
    order["Achievability"][module] = still_valid
  end
  if can_target then
    order["TargetRestrict"][module] = can_target
    return
  else
    return
  end
end
local function add_sexp(module, method_name, sexp_name)
  --[[ "Helper for making reloadable luasexps.
      Pass the module table and the name of the function to attach to the sexp.
      Action functions attached in this way will always be called as member methods,
        being passed their module table." ]]
  local sexp = _G.mn.LuaSEXPs[sexp_name]
  local action = maybe_make_attach_function(module, method_name)
  do end (sexp)["Action"] = action
  return
end
local function add_hook(module, method_name, hook, opt_conditions, opt_override_name)
  --[[ "Helper for making reloadable hook functions.
      Pass the module table and the name of the function to attach to the hook. 
      The function name must be a valid index into the module table.
      Optionally can be take a table of conditions and the name of an overrude function.
      Action and overrude functions attached in this way will always be called as member 
        methods, being passed their module table." ]]
  local conditions
  if opt_conditions then
    conditions = opt_conditions
  else
    conditions = {}
  end
  local method = maybe_make_attach_function(module, method_name)
  local override = maybe_make_attach_function(module, opt_override_name, true)
  if override then
    return engine.addHook(hook, method, conditions, override)
  else
    return engine.addHook(hook, method, conditions)
  end
end
local function get_module_namespace(self, file_name)
  --[[ "Gets access to a module table, even if the module has not yet been
      loaded. Useful for allowing local functions to access the module state
      without adding syntactic bloat" ]]
  local modules = self:safe_subtable("modules")
  local temp = self:safe_subtable("preinit_modules")
  local mod = self.modules[file_name]
  local ns = self.safe_subtable(temp, file_name)
  if mod then
    return mod
  else
    return ns
  end
end
local function module_setup(self, module, file_name, first_load, reload, reset)
  --[[ "internal function to encapsulate some get_module stuff and make for
      potential future refactoring" ]]
  local function _27_()
    local t_28_ = module
    if (nil ~= t_28_) then
      t_28_ = (t_28_).configure
    end
    return t_28_
  end
  if ((first_load or reload or reset) and _27_()) then
    ba.println(("Module " .. file_name .. " running configure"))
    module:configure(self)
  end
  local function _31_()
    local t_32_ = module
    if (nil ~= t_32_) then
      t_32_ = (t_32_).initialize
    end
    return t_32_
  end
  if ((first_load or reset) and _31_()) then
    ba.println(("Module " .. file_name .. " running init"))
    module:initialize(self)
  end
  local function _35_()
    local t_36_ = module
    if (nil ~= t_36_) then
      t_36_ = (t_36_).hook
    end
    return t_36_
  end
  if (first_load and _35_()) then
    ba.println(("Module " .. file_name .. " running hook"))
    module:hook(self)
  end
  return ba.println(("done setting up " .. file_name .. ""))
end
local function get_module(self, file_name, opt_reload, opt_reset, opt_version_spec, opt_optional)
  --[[ "Gets or loads a module by filename.
    Method
      Params
      file_name, string.
      reload, bool, optional. Pass true to reload the module's functions and configuration
      reset, bool, optional. Pass true to reset the module's state.
      version_spec, table, optional. Version specification table per reqver module, to check the loaded table. Version check will be skipped if omitted.
      optional, bool, optional. Is passed to reqver check if there is a version specification. Assumed false if omitted.
    Neither reloads or resets will rerun hook attachment. Use add_hook to create
      reloadable hooks, and use the repl to add new ones at runtime if needed." ]]
  local modules = self:safe_subtable("modules")
  local preinit_modules = self:safe_subtable("preinit_modules")
  local old_mod = modules[file_name]
  local first_load = not old_mod
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
  local lua_managed
  do
    local t_41_ = _G.package.loaded
    if (nil ~= t_41_) then
      t_41_ = (t_41_)[file_name]
    end
    lua_managed = t_41_
  end
  local optional
  if opt_optional then
    optional = opt_optional
  else
    optional = false
  end
  if (lua_managed and (reload or (type(lua_managed) == "userdata") or (type(lua_managed) == "bool"))) then
    _G.package.loaded[file_name] = nil
  end
  if (first_load or reload) then
    local new_mod
    if opt_version_spec then
      new_mod = reqver.require_version(file_name, opt_version_spec)
    else
      new_mod = require(file_name)
    end
    local preload = preinit_modules[file_name]
    if (first_load and preload) then
      self.print(("Module " .. file_name .. "First load with preload"))
      do end (modules)[file_name] = preload
      self:merge_tables_recursive(new_mod, modules[file_name], true)
    elseif first_load then
      self.print(("Module " .. file_name .. "First load"))
      do end (modules)[file_name] = new_mod
    else
      if new_mod then
        self.print(("Module " .. file_name .. " already loaded, merging"))
        self:merge_tables_recursive(new_mod, modules[file_name], true, {"config", "state"})
      end
    end
  end
  local loaded_mod = modules[file_name]
  if (loaded_mod and (type(loaded_mod) == "table")) then
    self:module_setup(loaded_mod, file_name, first_load, reload, reset)
    return loaded_mod
  else
    return ba.print(("problem loading " .. file_name))
  end
end
local function reload_modules(self)
  --[[ "Internal module reload function, reloads but does not reset everything" ]]
  local modules = self:safe_subtable("modules")
  for file_name, module in pairs(modules) do
    if (type(module) == "table") then
      self:get_module(file_name, true)
    end
  end
  return
end
local function reload(self)
  --[[ "Reloads the core functions, then reloads all other modules." ]]
  _G.package.loaded.plasma_core = nil
  do
    local new_self = require("plasma_core")
    self:merge_tables_recursive(new_self, self, true, {"modules"})
  end
  return self:reload_modules()
end
local function is_value_in(self, value, list)
  --[[ "Somewhat redundant with find, to be removed" ]]
  if (type(list) == "table") then
    local found = false
    if (0 ~= #list) then
      for _, v in pairs(list) do
        if found then break end
        if (v == value) then
          found = true
        end
      end
    end
    return found
  else
    return false
  end
end
local function verify_table_keys(t, required, optional, opt_label)
  --[[ "
      Checks a table to ensure only a valid set of keys is present and/or enforce a set of required keys.
        Useful to guard against typos in config tables.
        Optional label parameter is used for debug output" ]]
  local preamble
  local function _54_()
    if opt_label then
      return (" for " .. opt_label .. " ")
    else
      return ""
    end
  end
  preamble = ("table verification error" .. _54_())
  local missing_required = {}
  local missing_optional = {}
  local found_unknown = {}
  local errors = {}
  for _, key in ipairs(required) do
    missing_required[key] = true
  end
  for _, key in ipairs(optional) do
    missing_optional[key] = true
  end
  for key, _ in pairs(t) do
    if missing_required[key] then
      missing_required[key] = false
    elseif missing_optional[key] then
      missing_optional[key] = false
    else
      table.insert(found_unknown, key)
    end
  end
  for key, missing in pairs(missing_required) do
    if missing then
      table.insert(errors, ("missing key \"" .. key .. "\""))
    end
  end
  for _, key in ipairs(found_unknown) do
    table.insert(errors, ("unknown key \"" .. key .. "\""))
  end
  if (0 < #errors) then
    local message = preamble
    for _, err in ipairs(errors) do
      message = (message .. "\n\t" .. err)
    end
    if (0 < #required) then
      message = (message .. "\nrequired keys: ")
      for _, key in ipairs(required) do
        message = (message .. key .. " ")
      end
    end
    if (0 < #optional) then
      message = (message .. "\noptional keys: ")
      for _, key in ipairs(optional) do
        message = (message .. key .. " ")
      end
    end
    return ba.error(message)
  else
    return
  end
end
local function merge_tables_recursive(self, source, target, opt_replace, opt_ignore)
  --[[ "
      Combines two tables.
      Leaves overlapping non-table members alone unless
      replace is set. Always merges members that are tables
      ignore takes an array of keys to leave alone." ]]
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
      end
    end
  end
  return
end
local function scan_load_modules(self, opt_b)
  ba.println("")
  --[[ "
      Scans for any lua or fennel files in data/scripts/plasma_modules/
      and loads them as modules.
      Supports at least one level of subdirectory within the modules folder." ]]
  ba.println(string.format("plasma core scan started"))
  do
    local file_names = {}
    local lua_files = cf.listFiles("data/scripts/plasma_modules/", "*/*.lua")
    local lua_files2 = cf.listFiles("data/scripts/", "plasma_modules/*.lua")
    local fennel_files = cf.listFiles("data/scripts/plasma_modules/", "*/*.fnl")
    local fennel_files2 = cf.listFiles("data/scripts/", "plasma_modules/*.fnl")
    local scan
    local function _64_(t)
      for i, f in ipairs(t) do
        local pf = string.sub(f, 1, 15)
        local n = string.sub(f, 16, -5)
        local ns = string.gsub(n, ".*\\", "")
        if (pf == "plasma_modules\\") then
          file_names[ns] = true
        end
      end
      return
    end
    scan = _64_
    scan(lua_files)
    scan(lua_files2)
    scan(fennel_files)
    scan(fennel_files2)
    for k, _ in pairs(file_names) do
      ba.println(string.format("plasma core scan attempting to load %s\n", k))
      self:get_module(k, opt_b)
    end
  end
  return ba.println(string.format("plasma core scan done"))
end
--[[ "On modular configs
;;  This method is pased a function so it ca be set up to use any file format
;;  you please. Functions are provided for fennel tables and lua tables. The
;;  only requirement for a loading function is that it take a file name and
;;  returns a table, anything else is fair game.
;;               example:
;;                (let [fade_config (core:load_modular_configs :dj-f- :cfg core.config_loader_fennel)
;;                      segment_config (core:load_modular_configs :dj-s- :cfg core.config_loader_lua)]" ]]
local function load_modular_configs(self, prefix, ext, loader)
  --[[ "Builds and returns a table by evaluating files of a given prefix" ]]
  --[[ "takes a prefix to search for, a file extension to load, and a function" ]]
  --[[ "that will load the files" ]]
  local config = {}
  local files
  do
    local tbl_17_auto = {}
    local i_18_auto = #tbl_17_auto
    for _, file_name in ipairs(cf.listFiles("data/config", ("*" .. ext))) do
      local val_19_auto
      if (string.sub(file_name, 1, #prefix) == prefix) then
        val_19_auto = file_name
      else
        val_19_auto = nil
      end
      if (nil ~= val_19_auto) then
        i_18_auto = (i_18_auto + 1)
        do end (tbl_17_auto)[i_18_auto] = val_19_auto
      end
    end
    files = tbl_17_auto
  end
  local holding
  do
    local tbl_17_auto = {}
    local i_18_auto = #tbl_17_auto
    for _, file_name in ipairs(files) do
      local val_19_auto
      do
        local m_table = loader((file_name .. "." .. ext))
        if (type(m_table) == "table") then
          if (m_table.priority == nil) then
            m_table.priority = 1
          end
          val_19_auto = m_table
        else
          val_19_auto = nil
        end
      end
      if (nil ~= val_19_auto) then
        i_18_auto = (i_18_auto + 1)
        do end (tbl_17_auto)[i_18_auto] = val_19_auto
      end
    end
    holding = tbl_17_auto
  end
  local function _71_(l, r)
    return (l.priority < r.priority)
  end
  table.sort(holding, _71_)
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
    print((" loading modular fennel config from " .. file_name))
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
    print((" loading modular lua config from " .. file_name))
    if ((type(text) == "string") and (0 < #text)) then
      print(text)
      local _73_, _74_ = loadstring(text)
      if ((_73_ == nil) and (nil ~= _74_)) then
        local err = _74_
        this_table = print(err)
      elseif (nil ~= _73_) then
        local r = _73_
        this_table = r()
      else
        this_table = nil
      end
    else
      this_table = nil
    end
  end
  file:close()
  return this_table
end
local core = {["-reqver-version-info"] = plasma_version, safe_subtable = safe_subtable, safe_global_table = safe_global_table, recursive_table_print = recursive_table_print, module_setup = module_setup, reload = reload, reload_modules = reload_modules, add_order = add_order, add_sexp = add_sexp, load_modular_configs = load_modular_configs, merge_tables_recursive = merge_tables_recursive, is_value_in = is_value_in, get_module = get_module, config_loader_fennel = config_loader_fennel, config_loader_lua = config_loader_lua, print = print, warn_once = warn_once, get_module_namespace = get_module_namespace, add_hook = add_hook, scan_load_modules = scan_load_modules, verify_table_keys = verify_table_keys}
local corelib = core.safe_global_table("plasma_core")
core:merge_tables_recursive(core, corelib, true, {"modules"})
return corelib
