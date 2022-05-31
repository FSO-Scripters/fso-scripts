
# In Mission Jump Multi SEXPs
These sexps are for doing in-mission jumps for one or more ships simultaneously. For player ships, they will perform all the associated effects for a jump including the warp effect and the subspace tunnel. For non player ships, they will perform warp outs, move the ships far away and set them as untargettable, and then return them at the appropriate time with a warp effect.

You can jump multiple ships with a single sexp and they will be placed a set distance apart from each other at the target waypoint upon emerging from subspace.

These sexps can also handle docked ships by using the register-cargo sexp before using the jump sexps.

## These SEXPs can be found in Change -> In-Mission Jumps

### in-mission-jump
Initiates a subspace jump for some ship(s) to a given waypoint. Upon arrival, these ships are spread out around the target waypoint in a reasonable formation for a fighter wing. The destination can also be offset from the target waypoint; to jump multiple groups of ships to the same waypoint, simply call this once for each group and set different offsets each time. This operator generates appropriate graphics for capital ships as well. Jump graphics will NOT be drawn for ships more than 40,000 meters away from the player; this can be used in conjunction with hud-set-max-targeting-range to represent multiple disparate mission zones. LIMITATIONS: Using this operator may remove ships from the escort list, or cause them to resume their initial orders(!) upon arrival. Subspace is represented by the point (0, -100000, 0) and below; using that region for anything else in the mission runs the risk of accidental collisions. Lastly, see register-cargo before using this operator with ships that may be docked to other ships.
### in-mission-jump-leave
Send some ships to subspace. These ships may be returned to realspace later by calling in-mission-jump-return. This operator is subject to the same limitations as in-mission-jump.
### in-mission-jump-leave-together
Send some ships to subspace. Instead of the usual subspace calculation, the ships arrive at a waypoint list, interpreted as by in-mission-jump. This may be useful for battles in subspace.
### in-mission-jump-return
Returns some ships that had been sent to subspace with (either version of) in-mission-jump-leave. The ships arrive at a waypoint list, interpreted as by in-mission-jump.
### register-cargo
Notifies in-mission-jump that one ship might be docked to another. Failing to use this operator (or calling it with the arguments in the wrong order) before docked ships jump will cause strange and highly visible effects in the mission! This operator merely notifies the script that it should check if ships are docked; it may be safely used on ships that are not docked yet, ships that may undock later, 
### warp-in
Call the warpIn scripting function to play a ship's arrival animation. This is mostly useful for the player's wing at mission start.