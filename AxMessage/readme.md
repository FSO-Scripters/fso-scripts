
# AxMessage Documentation
AxMessage is configured through the use of a json config file, axmessage.cfg.

A note on the shorthand for JSON that will be used from now on:
The statement "``x.y.z`` is set to w" is essentially equivalent to the following JSON (with w being it's respective data type obviously):
```json
{
	"x": {
		"y": {
			"z": w
		}
	}
}
```
In addition, the statement "``x.y.z[]`` is set to w and v" is essentially equivalent to the following JSON:
```json
{
	"x": {
		"y": {
			"z": [
				w,
				v
			]
		}
	}
}
```

## List of configuration options

|Key|Value|Optional|
|---|---|---|
|``MinVersion``|The minimal version of AxMessage you require for this configuration||
|``Resolutions[]``|The graphics configuration for different monitor resolutions. For exact definition of each element per entry, see [below](#resolution-configuration)||
|``Default.Speed``|The speed at which the text of a message is revealed. 0.03 by default.|&#x2713;|
|``Default.Length``|A factor for determining how long a message without associated audio will be visible. 0.07 by default|&#x2713;|
|``Default.AfterVoice``|If a message has an associated audio file that is not a GenericFile, the message will be visible for the audio duration plus this value. 1.5 by default|&#x2713;|
|``Default.TitleColor[]``|The RGBA values of the color that the message sender should be displayed in. FSO HUD green by default.|&#x2713;|
|``Default.TextColor[]``|The RGBA values of the color that the message should be displayed in. FSO HUD green by default.|&#x2713;|
|``Monochrome``|Whether the whole of AxMessage should be rendered in monochrome. Automatically sets the color to the configured HUD color if used. False by default|&#x2713;|
|``GenericFiles[]``|An array of voice files that are used as generic audio for messages. Unlike other audio associated with messages, these do not influence the time the message is on screen. Empty by default|&#x2713;|

### Resolution configuration

|Key|Value|Optional|
|---|---|---|
|``MinHRes``|The minimal horizontal screen resolution required for this configuration. The first resolution with a MinHRes below the actual horizontal screen resolution will be picked.||
|``TitleFont``|The font used to display the message sender.||
|``TextFont``|The font used to display the message||
|``Image``|The filename for the message box image. "messagebox" by default.|&#x2713;|
|``ImageScale``|How much the message box image should be scaled. 1 by default|&#x2713;|
|``Position.Origin[]``|The relative x,y-position of the message box. If an offset is defined later, it specifies the upper-left corner, otherwise, it specifies the upper center. If not specified, the message box will be centered at 0.7 of the screen height.|&#x2713;|
|``Position.Offset[]``|The absolute upper-left x,y-offset of the message box in addition to the origin. Only used if origin is defined. 0,0 by default|&#x2713;|
|``Position.X``|The x-position of the upper left corner of the message box. Only used if origin is not defined|&#x2713;|
|``Position.Y``|The y-position of the upper left corner of the message box. Only used if origin is not defined|&#x2713;|
|``Offsets.Sender[]``|The x,y-offset by which the name of the sender is offset compared to the message box's upper left corner. 7,3 by default|&#x2713;|
|``Offsets.Text[]``|The x,y-offset by which the message text is offset compared to the message box's upper left corner. 10,15 by default|&#x2713;|
|``Backlog.Enabled``|Whether past messages should be displayed in a backlog. False by default|&#x2713;|
|``Backlog.Height``|The maximum height of the backlog in pixels. 50 by default.|&#x2713;|
|``Backlog.MaxSize``|The maximum number of messages in the backlog. 4 by default.|&#x2713;|
|``Backlog.Font``|The font to be used in the backlog.||
|``Backlog.Origin[]``|The relative upper-left x,y-position of the backlog. If not specified, the backlog's upper-left corner will be at 15, 50|&#x2713;|
|``Backlog.Offset[]``|The absolute upper-left x,y-offset of the backlog in addition to the origin. Only used if origin is defined. 0,0 by default|&#x2713;|
