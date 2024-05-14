
(comment "Plasma Core FSO script management library
  This system has the following objectives
 * Streamline common aspects of FSO scripting
 * Gently encourage a consistent structure for modules so I'll stop
     reinventing the wheel every time I make a new one
 * Support interactive development with the live reloading of modules
     following that structure

 This code deliberately breaks with Fennel style and uses snake_case
   exclusively. Amoung other reasons this is intended to make the
   compiled code somewhat more approachable.")

(comment "Usage
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
                  (core.add_hook(self :clear_all \"On Mission About To End\" ))
                  (core.add_hook(self :message_send \"On Message Received\")))
               or in lua
                local function hook(self, core)
                  core.add_hook(self, 'clear_all', 'On Mission About To End')
                  core.add_hook(self, 'message_send', 'On Message Received')
                end
")

(comment requirements)
(local reqver (require :reqver))
(reqver:install [1 0 0])
(local plasma_version [1 0 0])

(comment General utility functions)


(fn print [output ?label]
  (comment "A safe wrapper around the engine print function, prints each on its own line")
  (let [label (if (= nil ?label) "" ?label)
        t (type output)
        has_label (< 0 (length label))
        core _G.plasma_core]
  (match (type output)
    :table (core.recursive_table_print label output)
    :userdata (ba.print (.. "*: " label (if has_label " " "")  "is userdata\n"))
    :string (ba.print (.. "*: " label (if has_label " " "")  output "\n"))
    :Nil (ba.print (.. "*: " label (if has_label " " "")  "is nil" "\n"))
    :_ (ba.print (.. "*: " label (if has_label " " "") "type " t ":" (tostring output) "\n")))))


(lambda warn_once [id text memory]
  (comment "Show a warning the first time something errors
  Must be passed a memory table and index into that table. Calling code is responsible for storing that state")
  (let [last (?. memory id)]
    (if last
      (values)
      (ba.warning text))
    (tset memory id true)))

(lambda safe_subtable [t name]
  (comment "Get a table from inside a table, even if it doesn't exist")
  (when (= (. t name) nil)
    (tset t name {}))
  (. t name))

(lambda safe_global_table [name]
  (comment "Get a global table, even if it doesn't exist")
  (safe_subtable _G name))

(lambda recursive_table_print [name item ?d]
  (comment "Prints a whole table recursively, in a loosely lua table format")
  (when
    (and (~= name :_TRAVERSED) (~= name :metadata))
    (let [t (type item)
          depth (if (= ?d nil) 0 ?d)]
      (ba.print "\n-")
      (when (type depth :number) (for [i 1 depth] (ba.print "  ")))
      (ba.print (.. name " = " ))
      (if
        (= t "table")
        (if (= item._TRAVERSED true)
          (ba.print "Circular ref" )
          (do
            (ba.print "{")
            (set item._TRAVERSED true)
            (each [key value (pairs item)]
              (when
                (and (~= nil key)
                     (~= nil value))
                (recursive_table_print key value (+ depth 1))))
            (ba.print "\n*")
            (for [i 1 depth] (ba.print "  "))
            (ba.print "}")
            (set item._TRAVERSED nil)))
        (~= t "userdata")
        (ba.print (.. (tostring item)))
        (ba.print (.. "//" (tostring t)))))))

(fn maybe_make_attach_function [module method_name optional]
  (comment "an internal function to build functions for hook and attach" )
  (if
    (and module method_name (. module method_name) (= (type method_name) :string ))
    (let [f (fn [...] ((. module method_name) module ...))] f)
    (when (not optional)
      (comment "error checking")
      (if 
       (not= (type method_name) :string)
    (ba.error (.. "plasma_core.add_hook requires the method paramater to be a name. Ensure you are not passing a function reference. Was passed " (tostring method_name) " (" (type method_name) ")"))
    ;; If bad module reference...
    (or (= (. module method_name) nil) (not= (type (. module method_name)) :function))
    (ba.error (.. "plasma_core.add_hook could not find function named " method_name))
      ))))

(lambda add_order [module order_name enter_n frame_n ?still_valid_n ?can_target_n]
  (comment "currently not well tested, a helper to attach all the functions of a luaorder")
  (let [order (. _G.mn.LuaAISEXPs order_name)
      enter (maybe_make_attach_function module enter_n)
      frame (maybe_make_attach_function module enter_n)
      still_valid (maybe_make_attach_function module ?still_valid_n true)
      can_target (maybe_make_attach_function module ?can_target_n true)]
    (tset order :ActionEnter enter)
    (tset order :ActionFrame frame)
    (when still_valid (tset order :Achievability module still_valid))
    (when can_target (tset order :TargetRestrict module can_target))))

(lambda add_sexp [module method_name sexp_name]
  (comment "Helper for making reloadable luasexps.
    Pass the module table and the name of the function to attach to the sexp.
    Action functions attached in this way will always be called as member methods,
      being passed their module table.")
  (let [sexp (. _G.mn.LuaSEXPs sexp_name)
        action (maybe_make_attach_function module method_name)]
    (tset sexp :Action action)))


(lambda add_hook [module method_name hook ?conditions ?override_name]
  (comment "Helper for making reloadable hook functions.
    Pass the module table and the name of the function to attach to the hook. 
    The function name must be a valid index into the module table.
    Optionally can be take a table of conditions and the name of an overrude function.
    Action and overrude functions attached in this way will always be called as member 
      methods, being passed their module table.")
  (let [conditions (if ?conditions ?conditions [])
        method (maybe_make_attach_function module method_name)
        override (maybe_make_attach_function module ?override_name true)]
    (if
      override
      (engine.addHook hook method conditions override)
      (engine.addHook hook method conditions))))

(lambda get_module_namespace [self file_name]
  (comment "Gets access to a module table, even if the module has not yet been
    loaded. Useful for allowing local functions to access the module state
    without adding syntactic bloat")
  (let [modules (self:safe_subtable :modules)
        temp (self:safe_subtable :preinit_modules)
        mod (. self.modules file_name)
        ns (self.safe_subtable temp file_name)]
        (if mod mod ns)))
        ;(if mod (do (self.print :namespace_mod) mod) (do (self.print :new_namespace) ns))))

(lambda module_setup [self module file_name first_load reload reset]
  (comment "internal function to encapsulate some get_module stuff and make for
    potential future refactoring")
  ;(self.print {:function :module_setup : file_name : first_load : reload : reset}
  (when
    (and (or first_load reload reset) (?. module :configure))
    (ba.println (.. "Module " file_name " running configure"))
    (module:configure self))
  (when
    (and (or first_load reset) (?. module :initialize))
    (ba.println (.. "Module " file_name " running init"))
    (module:initialize self))
  (when
    (and first_load (?. module :hook))
    (ba.println (.. "Module " file_name " running hook"))
    (module:hook self))
  (ba.println (.. "done setting up " file_name "")))


(lambda get_module [self file_name ?reload ?reset ?version_spec ?optional]
  (comment "Gets or loads a module by filename.
  Method
    Params
    file_name, string.
    reload, bool, optional. Pass true to reload the module's functions and configuration
    reset, bool, optional. Pass true to reset the module's state.
    version_spec, table, optional. Version specification table per reqver module, to check the loaded table. Version check will be skipped if omitted.
    optional, bool, optional. Is passed to reqver check if there is a version specification. Assumed false if omitted.
  Neither reloads or resets will rerun hook attachment. Use add_hook to create
    reloadable hooks, and use the repl to add new ones at runtime if needed.")
  (let [modules (self:safe_subtable :modules)
        preinit_modules (self:safe_subtable :preinit_modules)
        old_mod (. modules file_name)
        first_load (not old_mod)
        reload (if ?reload ?reload false)
        reset (if ?reset ?reset false)
        lua_managed (?. _G.package.loaded file_name)
        optional (if ?optional ?optional false)]
    ;(self.print {: file_name : first_load : reload : reset})
    ;(self.print file_name)
    ;(self.print (. _G.package file_name))
    (when
      (and lua_managed
        (or ;Loaded previously, reload now
          reload
          ;;Errored on previous load, sentinal value needs clearing
          (= (type lua_managed) :userdata)
          (= (type lua_managed) :bool)))
      (tset _G.package.loaded file_name nil))
    (when
      (or first_load reload)
    ;;Require will now do what is needed in either case
      (let [new_mod (if ?version_spec (reqver.require_version file_name ?version_spec) (require file_name))
            preload (. preinit_modules file_name)]
        (if
          (and first_load preload)
          (do
            (self.print (.. "Module " file_name "First load with preload"))
            (tset modules file_name preload)
            (self:merge_tables_recursive new_mod (. modules file_name) true))
          ;;If this is the first load and no preloading, we can safely just put it in our modules table
          first_load
          (do
            (self.print (.. "Module " file_name "First load"))
            (tset modules file_name new_mod))
          ;;Else replace all the functions in an existing entry to the modules table
          (when new_mod ;require returns false rather than table if load fails
            (self.print (.. "Module " file_name " already loaded, merging"))
            (self:merge_tables_recursive new_mod (. modules file_name) true [:config :state])))))
    (let [loaded_mod (. modules file_name)]
      (if (and loaded_mod (= (type loaded_mod) :table))
        (do (self:module_setup loaded_mod file_name first_load reload reset) loaded_mod)
        (ba.print (.. "problem loading " file_name))))))

(lambda reload_modules [self]
  (comment "Internal module reload function, reloads but does not reset everything")
  (let [modules (self:safe_subtable :modules)]
    (each [file_name module (pairs modules)]
      (when (= (type module) :table)
        ;(print (.. " Plasma Core is reloading module: " file_name))
        (self:get_module file_name true)))))

(lambda reload [self]
  (comment "Reloads the core functions, then reloads all other modules.")
  (set _G.package.loaded.plasma_core nil)
  (let [new_self (require :plasma_core)]
    (self:merge_tables_recursive new_self self true [:modules]))
  (self:reload_modules))

(lambda is_value_in [self value list]
  (comment "Somewhat redundant with find, to be removed")
  (if
    (= (type list) :table)
    (do 
      (var found false)
      (when
        (not= 0 (length list))
        (each [_ v (pairs list) :until found]
          (when (= v value) (set found true))))
      found)
  false))

(lambda verify_table_keys [t required optional ?label]
  (comment "
    Checks a table to ensure only a valid set of keys is present and/or enforce a set of required keys.
      Useful to guard against typos in config tables.
      Optional label parameter is used for debug output")
  (let [preamble (.. "table verification error" 
                      (if ?label (.. " for " ?label " ") ""))
        missing_required {}
        missing_optional {}
        found_unknown []
        errors []]
    (each [_ key (ipairs required)] (tset missing_required key true))
    (each [_ key (ipairs optional)] (tset missing_optional key true))
    ;Look at what keys are in the table...
    (each [key _ (pairs t)]
      (if 
        (. missing_required key)
        (tset missing_required key false)
        (. missing_optional key)
        (tset missing_optional key false)
        (table.insert found_unknown key)))
    ;handle missing reqirements...
    (each [key missing (pairs missing_required)]
      (when missing
        (table.insert errors (.. "missing key \"" key "\""))))
    (each [_ key (ipairs found_unknown)]
      (table.insert errors (.. "unknown key \"" key "\"")))
    (when (< 0 (length errors))
      (var message preamble)
      (each [_ err (ipairs errors)]
        (set message (.. message "\n\t" err)))
      (when (< 0 (length required))
        (set message (.. message "\nrequired keys: "))
        (each [_ key (ipairs required)] (set message (.. message key " "))))
      (when (< 0 (length optional))
        (set message (.. message "\noptional keys: "))
        (each [_ key (ipairs optional)] (set message (.. message key " "))))
     ; (print {: t : required : optional : missing_required : missing_optional : found_unknown})
      (ba.error message))))

(lambda merge_tables_recursive [self source target ?replace ?ignore]
  (comment "
    Combines two tables.
    Leaves overlapping non-table members alone unless
    replace is set. Always merges members that are tables
    ignore takes an array of keys to leave alone.")
  (let [ignore (if (= ?ignore nil) [] ?ignore)
        replace (if (= ?replace nil) false ?replace)]
    (each [k v (pairs source)]
      (when
        (and (not (self:is_value_in k ignore)))
        (if
          (= (. target k) nil)
          (tset target k v)
          (= (type v) :table)
          (self:merge_tables_recursive v (. target k) replace ignore)
          replace
          (tset target k v))))))

(lambda scan_load_modules [self ?b]
  (ba.println "")
  (comment "
    Scans for any lua or fennel files in data/scripts/plasma_modules/
    and loads them as modules.
    Supports at least one level of subdirectory within the modules folder.")
  (ba.println (string.format "plasma core scan started"))
  (let [file_names {}
        lua_files (cf.listFiles "data/scripts/plasma_modules/" "*/*.lua")
        lua_files2 (cf.listFiles "data/scripts/" "plasma_modules/*.lua")
        fennel_files (cf.listFiles "data/scripts/plasma_modules/" "*/*.fnl")
        fennel_files2 (cf.listFiles "data/scripts/" "plasma_modules/*.fnl")
        scan (fn [t]
                (each [i f (ipairs t)]
                  ;(ba.println (string.format "f %s" f))
                  (let [pf (string.sub f 1 15)
                        n (string.sub f 16 -5)
                        ns (string.gsub n ".*\\" "")]
                    ;(ba.println (string.format "f %s pf %s n %s ns %s" f pf n ns))
                    (when (= pf :plasma_modules\) (tset file_names ns true)))))]
    ;(ba.println :l1)
    (scan lua_files)
    ;(ba.println :l2)
    (scan lua_files2)
    ;(ba.println :f1)
    (scan fennel_files)
    ;(ba.println :f2)
    (scan fennel_files2)
    (each [k _ (pairs file_names)]
      (ba.println (string.format "plasma core scan attempting to load %s\n" k))
      (self:get_module k ?b)))
    (ba.println (string.format "plasma core scan done")))


(comment "On modular configs
;;  This method is pased a function so it ca be set up to use any file format
;;  you please. Functions are provided for fennel tables and lua tables. The
;;  only requirement for a loading function is that it take a file name and
;;  returns a table, anything else is fair game.
;;               example:
;;                (let [fade_config (core:load_modular_configs :dj-f- :cfg core.config_loader_fennel)
;;                      segment_config (core:load_modular_configs :dj-s- :cfg core.config_loader_lua)]")
(lambda load_modular_configs [self prefix ext loader]
  (comment "Builds and returns a table by evaluating files of a given prefix")
  (comment "takes a prefix to search for, a file extension to load, and a function")
  (comment "that will load the files")
  (let [config {}
        files (icollect [_ file_name (ipairs (cf.listFiles :data/config (.. :* ext)))]
                (if (= (string.sub file_name 1 (length prefix)) prefix)
                file_name))
        holding (icollect [_ file_name (ipairs files)]
                  (let [m_table (loader (.. file_name :. ext))]
                    (if 
                      (= (type m_table) :table)
                      (do 
                        (when 
                          (= m_table.priority nil)
                          (set m_table.priority 1))
                        m_table)
                      (values))))]
    (table.sort holding (fn [l r] (< l.priority r.priority)))
    (each [_ mod (ipairs holding)] 
      (self:merge_tables_recursive mod config true [:priority]))
    config))

;;Note that this only works if the fennel compiler is available.
(lambda config_loader_fennel [file_name]
  (let [fennel (require :fennel)
        full_file_name file_name
        file (cf.openFile full_file_name :r :data/config)
        text (file:read :*a)]
    (let [this_table
        (if
          (= text nil)
          (do (print "nil file") {})
          (not= (type text) :string)
          (do (print (.. "bad text type " (type text))) {})
          (= (length text) 0)
          (do (print (.. "Empty file " file_name)) {})
          (do
            (print (.. " loading modular fennel config from " file_name))
            (fennel.eval text)))]
    (file:close)
    this_table)))

(lambda config_loader_lua [file_name]
  (let [full_file_name file_name
        file (cf.openFile full_file_name :r :data/config)
        text (file:read :*a)]
    (let [this_table
        (if
          (= text nil)
          (do (print "nil file") {})
          (not= (type text) :string)
          (do (print (.. "bad text type " (type text))) {})
          (= (length text) 0)
          (do (print (.. "Empty file " file_name)) {})
          (do
            (print (.. " loading modular lua config from " file_name))
            (when (and (= (type text) :string) (< 0 (length text)))
              (print text)
              (case (loadstring text)
                (nil err) (print err)
                r (r)))))]
    (file:close)
    this_table)))

;;Attach this module to the library, and return the module
(local core {
            :-reqver-version-info plasma_version
            : safe_subtable
            : safe_global_table
            : recursive_table_print
            : module_setup
            : reload
            : reload_modules
            : add_order
            : add_sexp
            : load_modular_configs
            : merge_tables_recursive
            : is_value_in
            : get_module
            : config_loader_fennel
            : config_loader_lua
            : print
            : warn_once
            : get_module_namespace
            : add_hook
            : scan_load_modules
            : verify_table_keys})

(local corelib (core.safe_global_table :plasma_core))

(core:merge_tables_recursive core corelib true [:modules])
corelib
