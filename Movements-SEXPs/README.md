# Custom-Movements-SEXPs
Custom sexps and functions for FSO that allow for much easier ship movements and rotations.

See main topic here:
https://www.hard-light.net/forums/index.php?topic=96082.0


TLDR: Release of custom sexps which can make cap ship (or any ship) movements much easier and more natural looking. 

Background
Do you ever get frustrated when trying and get large ship movements to look good? I've found this be especially tricky if you want the ships to act dynamically, if you want big ships to rotate in a way that looks natural, or if you want many big ships to follow a leader ship and stay in a relative formation. Dynamic waypoints provide an invaluable tool, yet ships will stop following a waypoint path once the path is complete or immediately turn around to start the path again. I wanted a single sexp that told a ship to track a waypoint or ship, thus the ship would travel to the waypoint and then move again if the waypoint moved. 

It can be similarly tricky to get large ships to rotate to a certain orientation. The rotation maneuver sexp is useful but you aren't guaranteed that the ship will stop rotating when it reaches the desired orientation. Again, I wanted a single sexp that I could use once that would move a ship to a specified orientation with a natural looking movement. 

To achieve these goals, I developed a suite of custom lua sexps, and hopefully you might find something useful to your own missions! 


Overview
In this release I have included sexps to rotate ships to a specific orientation, have a waypoint track a ship, a ship track a waypoint, and a ship track another ship. Fun things you can do with these sexps is to have entire fleet all rotate to the same orientation, have a battle group of ships follow around a leader command ship, order AI capships to 'attack' an enemy craft by pulling up next to it and rotating 90 degrees to bring broadsides to bear, ordering a ship track a target orientation, and many other things. 


Gritty Details
The following custom lua sexps are included:
 
move-to-orientation
Moves a ship to a given orientation over a specified time duration. This sexp only has to be called once and can be used to make a much more natural looking rotational effect for ships. By default this sexp will issue a play-dead-persistent order with priority 200, but this priority value can be changed and the order can also not be issued. Also by default it will use the ship's tabled rotational velocity to make the rotation look natural. 

early-stop-move-to-orientation
Immediately terminates the custom `move-to-orientation` sexp for a ship. Only use this sexp to prematurely stop `move-to-orientation` for a ship. 

add-waypoint-track-ship
Sets a waypoint to a position relative to a ship continually. This sexp is an easier way to make a dynamic waypoint track a ship location. The waypoint will be moved to the specified coordinates relative to the ship at every time duration. If the ship is not present or destroyed, or departed then the waypoint will not update location. 

remove-waypoint-track-ship
Removes a waypoint tracking of a ship. This sexp removes the effect of 'add-waypoint-track-ship'.

add-ai-goal-track-waypoint
Adds a custom ai-goal for a ship to track a waypoint path. The ship will move to the final point in the waypoint path and remain in that position. If the waypoint path is moved the ship will follow the waypoint path again. Useful for having ships follow dynamic waypoints. Note, this order can only be removed via the sexps 'remove-ai-goal-track-waypoint' or 'clear-goals'.

remove-ai-goal-track-waypoint
Removes a custom `add-ai-goal-Track-Waypoint` goal.

set-idle-track-orientation
Sets an idle/resting orientation for a ship tracking a waypoint, either as an absolute orientation or an orientation relative to a given ship. When a ship that is tracking a waypoint is not moving forward it will move to this idle orientation. If a relative orientation is specified the sexp will get the target ship orientation and then add the pitch, bank, and heading values set in this sexp to create a final idle/resting orientation.

unset-idle-track-orientation
Unsets/removes the idle/resting orientation for a ship tracking a waypoint. This sexp will result in a ship tracking a waypoint to not attempt to change it's orientation when not moving.

add-ai-goal-track-ship
Adds a custom ai-goal for a ship to track another ship. The ordered ship will move to follow the target ship and then once stopped will rotate to the target ship orientation, or a variant to that orientation. This is a higher level sexp that runs 'add-Waypoint-Track-Ship' with 'add-ai-goal-Track-Waypoint' and 'set-Idle-Track-Orientation'.

remove-ai-goal-track-ship
Removes a custom ai-goal for a ship to track another ship. This is a higher level sexp that runs 'remove-waypoint-track-ship' with 'remove-ai-goal-track-waypoint' and 'unset-idle-track-orientation'.


Usage:
Download these two files from https://github.com/wookieejedi/Custom-Movements-SEXPs and then place them in your data/tables folder. Then just open FRED and you will see a new listing called LUA-Movements where all the sexps are located. There are detailed descriptions of each sexp and each argument. 

Important! You need the most recently nightly build for these to work (Dec 2, 2019).

I included an example mission that shows how to use the 'move-to-orientation' and the 'add-ai-goal-track-ship' which is a higher order sexp that runs 'add-waypoint-track-ship' with 'add-ai-goal-track-waypoint' and 'set-idle-track-orientation'.
