--[[ "Module for Plasma Core 0.11.0

  Allows configurable and live-updated association between hotkeys and code actions to facilitate interactive development." ]]
  local core = require("plasma_core")
  local function hook(self, core0)
    local function _1_()
      return self:key_hook()
    end
    return engine.addHook("On Key Pressed", _1_)
  end
  local function key_hook(self)
    --[[ "the objective is live development, so configure runs every keypress" ]]
    self:configure(core)
    --[[ "actions now a table of functions" ]]
    local func = self.config.actions[_G.hv.Key]
    if func then
      return func()
    end
  end
  local function configure(self, core0)
    self.config = {actions = {}}
    local lconfig = core0:load_modular_configs("ckl-", "cfg", core0.config_loader_lua)
    local fconfig = core0:load_modular_configs("ckf-", "cfg", core0.config_loader_fennel)
    for k, f in pairs(fconfig) do
      self.config.actions[k] = f
    end
    for k, f in pairs(lconfig) do
      self.config.actions[k] = f
    end
  end
  return {key_hook = key_hook, hook = hook, configure = configure}