# Codekeys module for Plasma Core 0.11.0
This module enables the attachment of code to hotkeys to facilitate interactive development. 

Actions are defined in `.cfg` files, supporting both pure lua and fennel syntax. prefix lua files with `ckl-` and fennel with 'ckf-' and place them in data/config. Examples of each are provided. So long as a properly named config is indexed by the engine it will be reloaded on every keypress.

If a key is used in more than one config file, only one will be used. lua files have precedence over fennel files.

Reloading the configs every keypress could, if there's lots of code, potentially cause performance issues. Removing the module or clearing your config files before releasing a mod is recommended.

# Installing

 * Ensure Plasma Core 0.11.0 is present in your mod.
 * If you intend to use fennel actions, include the add-fennel for fennel version 1.3.0.
 * Place either codekeys.fnl or codekeys.lua into your mod's data/scripts/plasma_modules
 * put any configs in data/config.

Both codekeys.fnl and codekeys.lua are provided. .fnl is how the module was developed, but using the .lua may provide easier debugging if issues arise, even if you have fennel available. There are some weird constructions in the lua due to it's nature as compiler output, these have largely been left in place to ensure equivilent logic.