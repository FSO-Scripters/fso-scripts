# Tracking Device

This script and its sexps allow the user to designate a weapon and an associated ship as a tracking device.  From a gameplay standpoint, the tracking device is launched as a conventional missile and adheres to any ship that it impacts.  In reality, the missile is destroyed upon impact just like any other weapon, and a new ship is instantaneously spawned at the impact point.  This "ship" typically uses the same POF model as its associated weapon, although the script does not enforce this.

When the tracking device adheres to a target ship, that target is considered "tracked".  This is a status managed by the script and is independent of TAGging.  When a target ship is destroyed or departs the area, any affixed tracking devices will explode or depart along with it.

Potential use cases for this script include tracking ships during reconnaissance or stealth missions, or performing special actions for tracked ships during conventional missions.

This script requires 23.2, but the .21_0 version of the script will run on 21.0 (and possibly earlier builds).
