;;;Plasma Core FSO script management library
;;  This system has the following objectivs
;; * Streamline common aspects of FSO scripting
;; * Gently encourage a consistent structure for modules, so I'll stop
;;     reinventing the wheel every time I make a new one
;; * Support interactive development with the live reloading of modules
;;     following that structure
;;
;; This code deliberately breaks with Fennel style and uses snake_case
;;   exclusively. Amoung other reasons, this is intended to make the
;;   compiled code somewhat more approachable.

;;; Usage
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
;;                  (engine.addHook "On Key Pressed"
;;                    (fn [] (self:key_hook))))

;;; General utility functions

(fn print [output ?label]
  "A safe wrapper around the engine print function, prints each on it's own line"
  (let [label (if (= nil ?label) "" ?label)
        t (type output)
        has_label (< 0 (length label))
        core _G.plasma_core]
  (match (type output)
    :table (core.recursive_table_print label output)
    :userdata (ba.print (.. "*: " label (if has_label " " "")  "is userdata\n"))
    :string (ba.print (.. "*: " label (if has_label " " "")  output "\n"))
    :Nil (ba.print (.. "*: " label (if has_label " " "")  "is nil" "\n"))
    :_ (ba.print (.. "*: " label (if has_label" " "") "type " t ":" (_G.totring output) "\n")))))

(lambda safe_subtable [t name]
  "Get a table from inside a table, even if it doesn't exist"
  (when (= (. t name) nil)
    (tset t name {}))
  (. t name))

(lambda safe_global_table [name]
  "Get a global table, even if it doesn't exist"
  (safe_subtable _G name))

(lambda recursive_table_print [name item ?d]
  "Prints a whole table recursively, in a loosely lua table format"
  (when
    (and (~= name :_TRAVERSED) (~= name :metadata))
    (let [t (type item)
          depth (if (= ?d nil) 0 ?d)]
      (ba.print "\n-")
      (for [i 1 depth] (ba.print "  "))
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


;;"Host" in this case is the "self" for functions, the module they belong to
;;this is because I don't think I can have this do : without making it a macro
(lambda add_order [name host enter frame ?still_valid ?can_target]
  "Attaches functions to a LuaAI SEXP's action hooks."
  (let [order (. _G.mn.LuaAISEXPs name)]
    (fn order.ActionEnter [...] (enter host ...))
    (fn order.ActionFrame [...] (frame host ...))
    (when ?still_valid
      (fn order.Achievability [...] (?still_valid host ...)))
    (when ?can_target
      (fn order.TargetRestrict [...] (?can_target host ...)))))

;;"Host" in this case is the "self" for functions, the module they belong to
;;this is because I don't think I can have this do : without making it a macro
(lambda add_sexp [name host action]
  "Attaches functions to a Lua SEXP's action hook."
  (let [sexp (. _G.mn.LuaSEXPs name)]
    (fn sexp.Action [...] (action host ...))
    (values)))

(lambda get_module [self file_name ?reload ?reset]
  "Gets or loads a module by filename."
  "If reload is true, it will reload the module's functions and configuration"
  "If reset is true, the module's state will also be reinitalized"
  "Will only attach a module's hooks on first load, as there is currently no way to replace existing hooks. Module should design hooks around this limitation."
  (let [modules (self:safe_subtable :modules)
        first_load (= nil (. modules file_name))
        reload (if (= ?reload nil) false ?reload)
        reset (if (= ?reset nil) false ?reset)]
    (self.print file_name)
    (self.print (. _G.package file_name))
    (when (and (?. _G.package.loaded file_name) 
            (or ;Loaded previously, reload now
              reload
              ;;Errored on previous load, sentinal value needs clearing
              (= (type (. _G.package.loaded file_name)) :userdata)))
          (tset _G.package.loaded file_name nil))
    ;;Require will now do what is needed in either case
    (let [mod (require file_name)]
      (if first_load
        ;;If this is the first load, we can safely just put it in our modules table
        (tset modules file_name mod)
        ;;Else replace all the functions in an existing entry to the modules table
        (when mod ;mod is bool rather than table if load fails
         (self:merge_tables_recursive mod (. modules file_name) true [:config :state])))
    (let [mod (. modules file_name)]
      (when mod.configure
        (mod:configure self))
      (when
        (and (or first_load reset) mod.initialize)
        (mod:initialize self))
      (when
        (and first_load mod.hook)
        (mod:hook self))
      mod))))

(lambda reload_modules [self]
  "Internal module reload function, reloads but does not reset everything"
  (let [modules (self:safe_subtable :modules)]
    (each [file_name module (pairs modules)]
      (when (= (type module) :table)
        ;(print (.. " Plasma Core is reloading module: " file_name))
        (self:get_module file_name true)))))

(lambda reload [self]
  "Reloads the core functions, then reloads all other modules."
  (set _G.package.loaded.plasma_core nil)
  (let [new_self (require :plasma_core)]
    (self:merge_tables_recursive new_self self [:modules] true))
  (self:reload_modules))

(lambda is_value_in [self value list]
  "Somewhat redundant with find, to be removed"
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

(lambda merge_tables_recursive [self source target ?replace ?ignore]
  "Combines two tables."
  "Leaves overlapping non-table members alone unless"
  "replace is set. Always merges members that are tables"
  "ignore takes an array of keys to leave alone."
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

;;;On modular configs
;;  due to the oddities of FSO's cfile filesystem access, currently
;;  this must load .cfg files, but it treats them as fennel.
;;  cfg files are loaded if they fit a prefix. Care should be taken to
;;    avoid collisions between modlues.
;;  Each .cfg should return a table. A :priority keyed value in the table
;;   controls which config is final in case of overlaps. The cfile api
;;   functions don't expose the ordering typically provided by mod load order
;;   so order is undefined if priority is not provided.
(lambda load_modular_configs [self prefix]
  "Builds and returns a table by evaluating files of a given prefix"
  (let [fennel (require :fennel)
        config {}
        files (icollect [_ file_name (ipairs (cf.listFiles :data/config :*.cfg))]
                (if (= (string.sub file_name 1 (length prefix)) prefix)
                file_name))
        holding (icollect [_ file_name (ipairs files)] 
                  (let [file (cf.openFile file_name :r :data/config)
                        text (file:read :*a)
                     ; text))]
                        table (fennel.eval text)]
                    (print (.. " loading modular config from " file_name))
                    (file:close)
                    (when (= table.priority nil) (set table.priority 1))
                    table))]
    (table.sort holding (fn [l r] (< l.priority r.priority)))
    (each [_ mod (ipairs holding)] 
      (self:merge_tables_recursive mod config true [:priority]))
    config))

;;Attach this module to the library, and return the module
(local core {
            : safe_subtable
            : safe_global_table
            : recursive_table_print
            : reload
            : reload_modules
            : add_order
            : add_sexp
            : load_modular_configs
            : merge_tables_recursive
            : is_value_in
            : get_module
            : print})

(local corelib (core.safe_global_table :plasma_core))

(core:merge_tables_recursive core corelib true [:modules])
corelib