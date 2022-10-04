# What is Fennel
Fennel is a programming language that runs within Lua. It belongs to the Lisp family of languages. Fennel code compiles to Lua code and then is run as any other Lua code would be. As a result data and functions within Lua code and Fennel code can reference each other freely, it is not an either-or choice for a mod.

For detailed information and documentation see https://fennel-lang.org/

#  Why use Fennel?

I use Fennel because it's a refreshing change from using Lua. There are a few potential good reasons, and some drawbacks.

Some advantages
 * Fennel strongly encourages tight scoping and limited mutability, perfering local and const variables by default. This can help in general code quality
 * Lisp syntax may be familiar to FREDers
 * Fennel as some core operators and forms that are useful additions to the Lua toolbox.

Disadvantages
 * It's going to be something new for most people to learn.
 * Fennel and Fred events both draw from Lisp, but they are not the same language and they are not compatable. Knowledge from one could potentially confuse the other.
 * Debugging can be made more difficult. See below for details.

 In the end it comes down to aesthetics for me. I like working with Fennel, it's novel and satisfying, so I will continue to do so. It's up to you if yo uwant to or not. 

## How to use Fennel in FSO.

To enable Fennel place the included `add_fennel.lua` and `fennel`.Lua in data/scripts. Then, in a `-sct.tbm` or `.lua` file, use `require 'add-fennel'`.

Once you have done this, any future `require` statements will look first for `.lua` files as normal. If none are found it will proceed to check for `.fnl` files. Just put these in the scripts folder as you would normally and they will be loaded like any other script.

## How to debug Fennel

The distinction between the uncompiled Fennel code and the Lua code it compiles to can be a source of confusion with error messages.

 * Compiler errors are typical basic syntax or error checking, generally happen at game start, and refer to the Fennel line number.
 * Assertions added by the compiler for runtime error checking also refer to Fennel line number
 * Other runtime errors (in my limited experience) refer to the Lua code.
## How to see the compiled code
By default `add_fennel.lua` is configured to write out your compiled code where you can read it, to help with debugging. These are written as `.txt` in the data folder of the mod folder in `%appdata%` that is first in your mod flag. For example:

The mod flag: 
```-mod Warmachine-2.1.1\WMA-Marathon,Warmachine-2.1.1\wm_core,MVPS-4.5.1```

Require is `require 'music-sexps'`, which loads `music-sexps.fnl`

Then compiled code can me found at:

```C:\Users\MyUsername\AppData\Roaming\HardLightProductions\FreeSpaceOpen\Warmachine-2.1.1\WMA-Marathon\data```

## Checking out of engine
At https://fennel-lang.org/see you can quickly check what Fennel code compiles to, and also lets you 'compile' Lua to equivalent Fennel. This environment is not as strict in a few respects as the one set up by here, but it is a good way to check for basic syntax issues

## Limits
At the moment this integration does not support including macros from other files. If you want to venture into the dark art of lisp macros you'll need them defined in the file you're using them in.