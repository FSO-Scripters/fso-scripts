
# Plasma Core FSO Script Management Library
## Version 0.9.0

Plasma Core is intended as a foundational system to keep libraries, modules, and scripted gameplay systems of all stripes tidy and enable live-reloading of their code without restarting the game or wiping state. Plasma Core should work with standard Lua modules just as well as Fennel modules, so long as they are structured for it.

The system has the following objectives:
* Streamline common aspects of FSO scripting
* Gently encourage a consistent structure for modules, so I'll stop
   reinventing the wheel every time I make a new one
* Support interactive development with the live reloading of modules
   following that structure

This code deliberately breaks with Fennel style and with many existing modules and uses snake_case exclusively. Amoung other reasons, this is intended to make the compiled code cleaner and easier for Lua coders to interact with. Besides a few expected names the system does not enforce any style on modules loaded through it.

## Installing
Provided are both .lua and .fennel files for plasma core. If you use the fennel files you must also use the fennel support package included in the fso scripters repository.

The REPL files included are both an example of how a simple module can be structured, and a way to make use of the live development reload capabilties of the module. This workflow works best with features added during the FSO 22.3 development cycle

## Usage
A module designed form plasma core should be a file that returns a table of all it's functions.
A few member names are special. All function members should have a self paramter and a paramter for the core library, which will be passed in by the library's loading function.

>*table* state: 

Contain all gameplay state in this table. It is protected from most reloads.

>*table* config: 

A table of all the configuration values set in user files. This is updated on reloads, but otherwise shouldn't change

>*function* initalize: 

Sets up the initial state. Ideally it should also clean up any existing state on reloads, when that state includes things like active engine handles

> *function* configure: 

Reads all configuration files and populates the config table. Should use the load_modular_configs member of this module configure can also set up any SEXP actions, as it is safe to re-assign those.

> *function* hook: 

Create any hooks not specified in the -sct.tbm. Since we can't remove or replace hooks, this is only run on the initial load. Hooks should thus likely call a member function that does the actual work, so that can be reloaded instead. 

Example:

```lua
function repl:hook(core)
  return engine.addHook(On Key Pressed, (function () self:key_hook() end))
end
```
```clojure
(fn repl.hook [self core]
    (engine.addHook On Key Pressed
        (fn [] (self:key_hook))))
```

If you put any non-function members in the module anywhere but the state or config tables they may not be loaded or reloaded properly.

## Loading
The standard plasma core module's sct.tbm file consists only of this:
```lua
#Conditional Hooks
$Application: FS2_Open
$On Game Init:
[
require 'add_fennel' --omit if using precompilled lua.
local core = require 'plasma_core'
core:get_module('modulename')
]
#end
```
Then it sets up any hooks within the module's hook() function. However, it is perfectly fine and reasonable to set the hooks up in the sct table instead, provided they follow the structure described in the usage section.

A plasma core module should only be loaded with get_module(), and any code that references a module should use a local populated with get_module(), to ensure standard behavior. Internal handling and storage of modules could concievably change in the future, but get_module should always work as it does, so direct access to the plasma_core modules table is strongly discouraged.

# Modular configs

Modular configs are an attempt to mimic FSO's modular tables. The intent is that a parent mod, like for instance the MVPs, can include a script and configure it for the assets they provide, and then downstream mods can modify or agument just like they would normal tables. This system is a bit of a work in progress

Due to the oddities of FSO's cfile filesystem access, currently this must load .cfg files, but it treats them as fennel. cfg files are loaded if they fit a prefix. Care should be taken to avoid collisions between modlues.

Each .cfg should return a table. A value with the key priority in the table controls which config is final in case of overlaps, with higher numbers being the final say.. The cfile api functions don't expose the ordering typically provided by mod load order, so order is undefined if priority is not provided.

Future plans call for the code to support cfgs of different formats transparently, but there's some bumps in that road I haven't ironed out yet.

# Function listing
In accordance with fennel style, anything marked with a ? is an optional parameter that can be nil. Anything else will cause an error if nil.

# General utility functions

## print
>*string* message

>*string* ?label

A safe wrapper around the engine print function, prints each on it's own line.

## safe_subtable
> *table* parent

> *string* key

Get a table from inside a table, even if it doesn't exist.

## safe_global_table

> *string* key

Get a global table, even if it doesn't exist.

## recursive_table_print
> *string* tablename

> *table* to_print

> *number* ?depth

Prints a whole table recursively, in a loosely lua table format. Depth should never be passed in and is only for recursion purposes.

## is_value_in
> *table* self

> *any* value

> *table* target

This function shouldn't be used as it is redundant with a core library function and will be removed once I clean up the code that uses it.

## merge_tables_recursive
> *table* self

> *table* source

> *table* target

> *bool* ?replace

> *array* ?ignore

Combines two tables.
Leaves overlapping non-table members alone unless replace is set. Always merges members that are tables.
Ignore takes an array of keys to skip.

# FSO interface helpers

## add_order

> *string* name

> *table* host

> *function* enter

> *function* frame

> *function* ?still_valid

> *function* ?can_target

Attaches functions to a LuaAI SEXP's action hooks.
Host is the self of the module that the attached function belongs to. Consequently all functions being used should be ones with a self paramter.

## add_sexp

> *string* name

> *table* host

> *function* action

  Attaches functions to a Lua SEXP's action hook
Host is the self of the module that the attached function belongs to. Consequently all functions being used should be ones with a self paramter.

# Module management functions

## get_module 

> *table* self

> *string* file_name

> *bool* ?reload

> *bool* ?reset

Gets or loads a module by filename.

If reload is true, it will reload the module's functions and configuration

If reset is true, the module's state will also be reinitalized

get_module only attaches a module's hooks on first load, as there is currently no way to replace existing hooks. Modules should design hooks around this limitation. Actions for orders and sexps are re-attached each load as that is a safe replacement.

## reload_modules

> *table* self

Internal module reload function, reloads everything but does not reset. Not intended to be externally called.

## reload

> *table* self

Reloads the core functions, then reloads all modules.

## load_modular_configs

> *table* self

> *string* prefix

Builds and returns a table by evaluating files of a given prefix.
