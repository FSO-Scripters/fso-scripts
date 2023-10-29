# Capship Command V3

This is a complete rewrite of the CSC script included in BP. The main upgrades offered by this version over the previous are,
* A new graphical UI powered by AXUI
* Mouse Control
* An external config file -- no more messing with the script needed to add ships
* Fully customisable turret groups

## Playing

![](/images/screen0001.png)
For the player the scripts functionality is almost identical to the previous version. Holding down `Alt` frees the mouse which lets the player click on the buttons next to the Weapons setting there Mode, The 4 Modes Are from left to right,
* Auto - Turret is under AI Control.
* Track - Turret will shoot at the players target. 
* Lock - Turret will continue to shoot at current target even if tageting in changed.
* Offline - Turret will not shoot.

By using the buttons nxt to the group Name the player can set targeting parameters for the whole group.

## Config Format

### Config
Ships are defined in csc.cfg in the mods config folder. Ships are retrived by there name in the Ships.tbl or tbms, if the ship is not present the script will error.

Inside the ship definiton is the `WeaponGroups` section, a group is a JSON Object. the id of the object doesn't matter hear so long as it is unique in this ship and recognizable to you.
The first option for the group is `Name` which will be the groups dispaky name on the UI so try t make it informative to the player.
`Colour` Contains the RGBA value which is used for the group on the UI and brackets.
`Turrets` An array the list of turrets in to be added to the group. Should use the Subsystem name from the table. Script will error if a turret is present in this list and not the model.
`PlayerControl` A boolean, if true the group will appear in the UI and be under player control. If false the group will not appear in the UI but will still show targeting brackets of the groups colour

## Script
In the script file there are only two real options. In the `CSCUI:Init()` function of `cscui-sct.tbm` there are `self.startX` and `self.startY` which can be used to adjsut the UI's posistion.

## Interface
In here are the files used by the UI they should be 64x64 image files.
* `*.dds` The base image for th button
* `*hover.dds` The image for the button when it is hovered over.
* `*filled.dds` The image for the button when it is active.
