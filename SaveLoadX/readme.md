# SaveLoadX

A streamlined checkpoint and savestate system.

## Notes

- Support ships are never saved.  A ship is treated as a support ship when its class has the `Support` ship type (objecttypes.tbl); the `Support` name prefix is only used as a fallback for ships whose handles can no longer be resolved at save time.  The save log names which route made the decision.
- Loading is tolerant of saves that no longer match the mission.  A ship class, weapon class, or team that no longer exists, or a subsystem or weapon-bank count that has changed, is logged in `fs2_open.log` and skipped; the rest of the ship's data is still applied.  A save file that fails to parse is treated as empty.
- Save slots are stored under string keys in the JSON file.  A file that stores its slots as a JSON array is read as well, and is rewritten with string keys on the next save.
- Mission names passed to `lua-savestate-load-external`, `lua-savestate-load-external-var`, and `lua-savestate-check` may be given with or without the `.fs2` extension and are matched case-insensitively.
- Subsystem data is saved with each subsystem's canonical model name and restored by name: at load for ships already present, and on arrival for ships that had not arrived yet.  A saved subsystem without a name is matched by position instead, and the log says so.
- `lua-savestate-shipstatus` returns true for a ship that has no entry in the save state.  A ship that had not arrived when the checkpoint was taken has no entry, so a ship whose arrival cue uses this SEXP arrives normally after a load.
- Once a save state is loaded, it holds for the rest of the mission.  Clearing or re-saving that slot changes the save file but not the loaded state, so `lua-savestate-shipstatus` and the data applied to arriving ships still follow what was loaded.  Asking `lua-savestate-shipstatus` about an index that has no save state returns true.
- A ship that was not in the mission when the checkpoint was taken is left entirely alone when it arrives, so the arrival state FRED set up for it is preserved.
