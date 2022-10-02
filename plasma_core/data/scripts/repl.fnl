;;; REPL Module
;; This module does not yet provide a true Read-Eval-Print Loop enviroment,
;;  instead the do_keys runs code based on what key was pushed
;;  and output is visible in the fso debug log.
;;  as such, the niceties of the fennel REPL have not been ported 

(local core (require :plasma_core))
(fn hook [self core]
  (engine.addHook 
    "On Key Pressed"
    (fn [] (self:key_hook))))

(fn key_hook [self] 
  (let [newself (core:get_module :repl true)]
    (newself:do_keys)))

(fn do_keys [self]
    ;(local dj (core:get_module :etps-dj))
    (match hv.Key
      ;:1 (dj:play_new :DawnWave1Loop :HardMeasure)
      ;:2 (dj:play_new :DawnWave2Main :ExitLoop)
      :8 (core:reload)
      ;:9 (core.recursive_table_print :state dj)
      :0 (engine.restartLog)
    )
)

{: do_keys : key_hook : hook}