# Lafiel's FSO Scripts:
## RadarIcon
Located in ``radaricon/data``.

RadarIcon displays a ships RadarIcon on top of it. It fades however, once the ship gets close enough, is in the center of the player's reticle, or is targeted.
Toggle this on or off in the mission with the lua-radaricon-activate and lua-radaricon-deactivate SEXPs. The activate SEXP takes the teams of which icons shall be rendered as arguments.

To modify which ship is assigned to which radar icon, modify ``radaricon/data/config/radaricon.cfg``. If a ship should not be displayed with it's icon, remove the ship entry.
In a similar fashion, weapons can have icons to be rendered on top of them.

The Alpha-Section configures more detail about how the icons are displayed or when they fade out of view.
First off, the ``MaxOpacity`` value determines, how opaque the icons can be.
If a ship is (in flight direction) closer than ``Near`` (in meters), the icon will become transparent. If a ship is further away than ``Far``, it will be Opaque (as defined by ``MaxOpacity``). Inbetween, the transparency is linerarly interpolated.
The ``ClassMultiplier`` list then determines if the Near / Far values should be multiplied for certain types of craft. In the default configuration, it makes fighter and bomber icons be visible closer to the player, and (super) cap icons only visible further away. More types can be added as needed.
``NebulaMultiplier`` has an additional effect on these values, if the mission is in a nebula (only enabled with new-engine flag, see below).
An addition, if a ship is closer to the screen center than ``ReticleNear`` (in factor of screen height), the icon will be transparent. If a ship is further away from the screen center than ``ReticleFar``, it will be Opaque. Inbetween, the transparency is linerarly interpolated.

In a similar fashion to the ``ClassMultiplier`` list, the ``Scale`` list determines the size of the icons by type.

The ``AlwaysOn`` flag determines, if the script should run for all missions (``true``, useful for tacking it onto existing mods), or if it should only run when called by SEXP (``false``, useful for integrating it into a new mod as it allows for finer control of the script).

The ``AtLeastNightly20201222`` flag must be set to false when using an engine prior to nightly 20.1.0-20201222, and should be true otherwise. Setting this flag to true enables the ``NebulaMultiplier``, as well as increases stability on low-end GPUs.

The RadarIcon-Script uses Axems AxemParse module (though in reduced form, so if you depend on AxemParse, use your version!) for the config, and Svedalrain's radar icons. Further thanks to Mito and EatThePath for testing and bugfixing.