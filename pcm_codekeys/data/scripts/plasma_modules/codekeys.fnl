(comment "Module for Plasma Core 0.11.0
  Allows configurable and live-updated association between hotkeys and code actions to facilitate interactive development.")

(local core (require :plasma_core))
(fn hook [self core]
  (engine.addHook 
    "On Key Pressed"
    (fn [] (self:key_hook))))

(fn key_hook [self]
  (comment "the objective is live development, so configure runs every keypress")
  (self:configure core)
  (comment "actions now a table of functions")
  (let [func (. self.config.actions _G.hv.Key)]
    (when func (func))))

(fn configure [self core]
  (set self.config {:actions {}})
  (let [lconfig (core:load_modular_configs :ckl- :cfg core.config_loader_lua)
        fconfig (core:load_modular_configs :ckf- :cfg core.config_loader_fennel)]
        ;(core.print lconfig :lconfig)
        ;(core.print fconfig :fconfig)
        (each [k f (pairs fconfig)]
          (tset self.config.actions k f))
        (each [k f (pairs lconfig)]
          (tset self.config.actions k f))))

{: key_hook : hook : configure}