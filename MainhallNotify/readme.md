
# Mainhall Notifications
Provides a system and sexps to offer custom popup notifications at the mainhall between missions or at the start of a campaign. Notifications that have been seen are saved to a player file in %appdata%.

NOTE: Requires SCPUI assets and scripts  
NOTE: Disables mainhall tips entirely

## Config file
It should be named "notices_CAMPAIGNFILENAME.cfg" in data\config. An example file is included. The config lists notices that will be shown to the player on campaign start.

The config is JSON format. Each object includes "Text" and "Title". The data format accepts an XSTR; ("string", ####)

## Sexps are found in Change -> Mission and Campaign

### send-main-hall-notice
Send a low-priority notification to the player. The notification will be displayed the next time the player views the main hall. Since strings in FRED have a maximum length of 32 charactrs, the text of the notification is taken from a mission message instead. (If the message is configured for localization, the notice will localize as well.) HTML markup is supported in the notification text, although libRocket only understands a few tags - consult the SCPUI documentation for more information. As a special case, the notification will not be displayed if the player quits to the main hall without continuing the campaign (either because they failed the mission, or because they chose not to accept the mission outcome).
