# Cloak

This script allows both the player and AI to be able to cloak. A config file (included) allows you to tweak the finer details, including if weapons or afterburner will kill the cloak, or if shields remain up. The script also includes a 'Cloaking Device' weapon that you can add to a ship's loadout, if a ship has this in their loadout they will get cloaking automatically. Also included are:

lua-set-cloak-ability: Gives a ship the ability to cloak. If the AI is given this ability, they will use it as well. Firing weapons will force the ship to decloak.

lua-force-cloak: Forces a ship to cloak or uncloak (given they have the cloaking ability set).

lua-is-cloaked: Returns true only if all ships listed are currently cloaked

lua-player-is-cloaked:  Returns true if player is currently cloaked, with lower potential performance cost than lua-is-cloaked

2 sample missions are included