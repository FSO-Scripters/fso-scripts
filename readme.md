# Lafiel's FSO Scripts:
## RadarIcon
Located in ``radaricon/data``.

RadarIcon displays a ships RadarIcon on top of it. It fades however, once the ship gets close enough, is in the center of the player's reticle, or is targeted.
Toggle this on or off in the mission with the lua-radaricon-activate and lua-radaricon-deactivate SEXPs. The activate SEXP takes the teams of which icons shall be rendered as arguments.

To modify which ship is assigned to which radar icon, modify ``radaricon/data/config/radaricon.cfg``. If a ship should not be displayed with it's icon, remove the ship entry.
In a similar fashion, weapons can have icons to be rendered on top of them.

The RadarIcon Config file also defines where the icons start to fade. If a ship is (in flight direction) closer than ``Near`` (in meters), the icon will be transparent. If a ship is further away than ``Far``, it will be Opaque. Inbetween, the transparency is linerarly interpolated.
If a ship is closer to the screen center than ``ReticleNear`` (in factor of screen height), the icon will be transparent. If a ship is further away from the screen center than ``ReticleFar``, it will be Opaque. Inbetween, the transparency is linerarly interpolated.

The RadarIcon-Script uses Axems AxemParse module (though in reduced form, so if you depend on AxemParse, use your version!) for the config, and Svedalrain's radar icons.