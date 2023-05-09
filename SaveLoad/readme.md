# SaveLoad

The original ship save/load script.  Based on Admiral MS's script released [here](https://www.hard-light.net/forums/index.php?topic=74716.0), subsequently upgraded by Goober5000 [here](https://www.hard-light.net/forums/index.php?topic=96939.0). Subsequently upgraded again by MjnMixael.

This script can be used to persist data for checkpoints in a mission, or even between missions.  In contrast to SaveLoadX, this script does not attempt to save the entire mission state; instead it only saves what you explicitly tell it to.  Also in contrast to SaveLoadX, this script can save not only ship data, but variable data as well.  By explicitly specifying a file name, SaveLoad can load data from a previous mission, providing an alternative to FSO's red-alert system.

The script will save all checkpoint data to a single JSON file with separate save sections for each player. "filenames" within the sexps refer to saves within the JSON file and not physical files on the hard disk.

NOTE: You must modify the top of the script file to set a save file name. It is highly recommended you choose something unique to avoid possible mod save data collisions. If you want to absolutely avoid save data collisions, change it from saving to 'data/players' to saving to 'data/config'.