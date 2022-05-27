
#Briefing Audio Hooks

BRiefing Audio Hook, allows a non-voice sound file to begin playing at a certain briefing stage defined with lua-brah.tbm or \*-bah.tbm. Can be made to loop and not stop until its cleared or the mission starts or exit to main menu.
	
Table File Layout:
```
	#Briefing Hooks

	$Name: Mission Filename
	$Stage: Stage Number
	$File: Sound Filename
	$Repeat: (true/[false]) (optional, defaults to false)
	$Clear: (true/[false]) (optional, defaults to false) Will stop all other sounds from
	playing with this script before starting this one.

	#End
```