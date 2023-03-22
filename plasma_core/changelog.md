# 0.11.0 2023-03-07
 
 * Fennel version now requires fennel compiler 1.3.0
 * Design now fully oriented around auto-loading modules and entirely forgoing `-sct.tbm` files for modules
 * internal changes to `add_hook` and related functions to improve reload resiliancy
 * provided lua modular config loader no-longer appends 'return' to the start of the lua file. Usage found that some occasionally needed table structures are incompatible with this, so lua modular configs are now expected to explicity return themselves.
 * added verify_table_keys for config error checking.
 * removed internal-only functions from the readme listing, as they are not relevant to users of the system and have internal documenting comments.
 * better error checking in multiple places
 * removed repl module from package in expectation of providing a proper module for this functionality seperately.