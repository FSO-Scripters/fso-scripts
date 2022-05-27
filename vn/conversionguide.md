# Visual Script Versioning Guide
The current version of the script is version 3.1.0
## On Versioning
From version 3.0.0 onwards, the Visual Script follows semantic versioning. This means, a new major version (the first number) represents a new version that is not backwards compatible, and old scripts must be modified. A new minor version (the second number) means that new features were added but the script is still fully backwards compatible, while the patch (the third number) represents bugfixes within the current scope of the API.
## Conversion Guides
Here a list of steps will be listed to make scripts of lower major versions compatible again
### Version 2 to Version 3
- Replace all EIF commands with ELSEIF and all END commands with ENDIF.
- Replace all SETSEXPVAR commands with SETVAR.
- Replace all SHOW commands that have the filename option set with SHOWIMAGE.
- Modify all SETVAR commands to have the target variable as first argument and an arithmetic expression as the following arguments. No explicit assignment operator and no immediate variable modification is possible anymore.
- Modify all SETBG commands to now use the file option for the first argument, the scale option for the second and the time option for the third.
- Modify all SHOWMAP commands by inserting "vnLocation" as the second argument (this was the previously hardcoded result variable for the result of SHOWMAP).
- Modify all SETFLAG commands by prefixing their first argument with "f_"
- For all MENU commands, move argument one to the end of line and set it as the variable option. If there was a SETFLAG command with the value of the variable option before prefixing it with f_, append the new first argument of the SETFLAG command as the flag option to the MENU command.
- For all dialog, if there is a soundfile specified as the third argument, set it as the option voice. If a textspeed is specified, set it as the speed option. If a font is specified, set is as the font option.
- Remove all Interrupts that needed key-based triggers and replace them with button based interrupts.
- Change FILEVERSION 2 to FILEVERSION 3