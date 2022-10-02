local core = require("plasma_core")
local function hook(self, core0)
  local function _1_()
    return self:key_hook()
  end
  return engine.addHook("On Key Pressed", _1_)
end
local function key_hook(self)
  local newself = core:get_module("repl", true)
  return newself:do_keys()
end
local function do_keys(self)
  local dj = core:get_module("etps-dj")
  local _2_ = hv.Key
  if (_2_ == "1") then
    return dj:play_new("DawnWave1Loop", "HardMeasure")
  elseif (_2_ == "2") then
    return dj:play_new("DawnWave2Main", "ExitLoop")
  elseif (_2_ == "8") then
    return core:reload()
  elseif (_2_ == "9") then
    return core.recursive_table_print("state", dj)
  elseif (_2_ == "0") then
    return engine.restartLog()
  else
    return nil
  end
end
return {do_keys = do_keys, key_hook = key_hook, hook = hook}