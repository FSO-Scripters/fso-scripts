#Debug Tools

A few scripts meant to help you, the modder, with any sort of issues that may arise when making a mission or mod.

While in a mission pressing ``5`` will toggle a display of SEXP variables. ``6`` will inform you of their type, ``7`` will append bitmask information to the sexp variables. ``8`` will give some very verbose data about your current target. ``9``will give that same batch of verbose data about the player's ship.

Also included is a ``PrintDebug()`` lua function for helping debug lua scripts. By inserting a table into the function, the function will recursively list the entire contents of the table. This is good to see what exactly your lua script is doing.