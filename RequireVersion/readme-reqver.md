This module implements a very minimal interpretation of https://semver.org/, and provides a system to check the version of upstream scripts on loading them.

The module assumes versions of MAJOR.MINOR.PATCH, following these rules:

Patch will be increased for bugfixes, never for new functionality.
Minor will be increased for new additions but should never be used for breaks in backwards compatibility.
Major will be increased for any removals or changes of existing behavior, or any other compatibility breaks.
Increases to Minor should reset Patch to zero, and increases to Major should reset Minor and Patch to 0

For simplicity, the pre-release specifiers of semver are not currently supported. In my experience attempting to use them in semver implementations is relatively frequent source of headaches. Also omitted is semver's special handling of major version 0, and it is suggested that any released script should start on major version 1 to avoid confusion.

# Activation

Reqver provides alternatives to `require` that check versioning. To put them into the global scope, you can use this lua:

```lua
require("reqver"):install()
```

This places require_version and request_version functions in the globals table. The usage of them is documented lower down.

You can also also check that the expected version of reqver is present, with:

```lua
require("reqver"):install({1, 0, 0})
```

It is recommended to use this version checking, in case a future revision to reqver uses different check methods.

# Usage

To be loaded with reqver, a module must return a table when `require`ed, and that table must contain a key named "-reqver-version-info" with the script's current information. Example:

```lua
--reqver module
local function install()
  --...
end

return {
    --version 1.0.0
    ["-reqver-version-info"] = {1, 0, 0},
    install = install
}
```
or alternatively,
```lua
--reqver module
local reqver {["-reqver-version-info"] = {1, 0, 0}}

function reqver:install()
  --...
end

return reqver{}
```

Minor or patch values can be omitted, and will be treated as 0 if so. This is true of all version specifiers in reqver.

To load a module there are two modes that can be used, require and request. Require throws an error when the version check can't be satisfied, request merely returns false. With request you can set up scripts that can work with multiple versions of a dependency, or have optional dependancies entirely.

A script using reqver might look like this:

```lua
--install reqver v1
require('reqver'):install({1})
--load plasma core v1.21
local plasma = require_version("plasma_core",{1, 21})
--try to load custom data reader v2.0, optionally, but load 1.0.2 if 2 is not available.
local custom = request_version("cd_load",{2, 0})
if type(custom) == "nil" or custom == false then
  custom = require_version("cd_load",{1, 0, 2})
end
```

## Interface

### require_version, request_version (mod_name, vers_spec)
* mod_name: Required. String name of module, as you would provide to the standard lua `require`.
* vers_spec: Required. A version number specifier table.

Both return the module table if succesesful, and prints a log message about the outcome.

Require will error if the module can't be found, doesn't have version information, or doesn't match the specified versioning.

Request will return nil when the module can't be found, and false if it otherwise fails to meet conditions.

### install(self, _opt_vers_spec, _opt_optional)
* self: this function takes self and must be called as a method (using `:`) or passed the reqver module.
* _opt_vers_spec: Optional version specifier table. Installed version will not be checked if this is not passed.
* _opt_optional: Boolean, if true the self-version check will be done as a `request_version` rather than `require_version`. Assumed false if omitted.

Places require_version and request_version versions into the globals table, so they can be called without referring to the module. Can check reqver's version on install, which is considered best practice.

### assert_version_check, permissive_version_check (self, mod_name, vers_spec, mod_vers)
* self: this function takes self and must be called as a method (using `:`) or passed the reqver module.
* mod_name: Required. String name used for log prints.
* vers_spec: Required. The version number being requested, as a version specifier table.
* mod_vers: Required. The version number to check, as a version specifier table.

Both check a version number, write log prints, and returns true or false depending on the result of the check. Useful if you want to use the modules version checking outside the provided `require_version` or `request_version` for whatever reason.

The assert variant will error if the check does not pass, while the permissive version will return false.

### version_check(self, vers_spec, mod_vers)
* self: this function takes self and must be called as a method (using `:`) or passed the reqver module.
* vers_spec: Required. The version number being requested, as a version specifier table.
* mod_vers: Required. The version number to check, as a version specifier table.

Checks a version number, and returns two values.
* A boolean indicating if the check was passed.
* A string containing the requested and provided version on success, or otherwise the first test the provided version failed.

This is the check method used by all version checks the module performs, but does not print it's messages to the log by itself.
