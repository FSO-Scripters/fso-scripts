
# VS3 Documentation
## Load a Scene
To load a scene, simply call the SEXP ``lua-vn-load``. As the first argument, pass the filename of the VN script to load from the fiction directory. As a second argument, pass the label from which execution should start. If no label to start execution from is given, the script will start at the top.

## Config
The config for the Visual Novel script is done through the file vs3.cfg. In rare cases, special settings in axmessage.cfg are also required. In general, the basic structure of the vs3.cfg looks like this, with the main sections being Actors, Characters, Graphics, Bases, Displays and Maps. Bases, Displays and Maps are optional and can be omitted if not used in the VN.
```json
{
	"Actors": {
		...
	},
	"Characters": {
		...
	},
	"Graphics": {
		...
	},
	"Bases": {
		...
	},
	"Displays": {
		...
	},
	"Maps": {
		...
	},
	...
}
```
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
Also, all keys that are surrounded with pointed brackets like \<this\> need to be replaced with an appropriate name or value. Which value this needs to be will be explained in context.

### Configuring Graphics
The "Graphics" region of the config specified the general look and feel of the VN. It can feature multiple different configurations for different resolutions. The configuration with the largest minimally required horizontal screen resolution that is smaller than the actual horizontal screen resolution will be selected. Each of those configurations is named for logging purposes. One configuration contains the following (required) elements:
Key | Value | Optional
-|-|-
``Graphics.<name>.MinRes`` | The minimally required horizontal screen resolution for this configuration
``Graphics.<name>.Text.Title.Color[]`` | The R, G, B, A values of the name of the currently speaking character (called title, color can be overridden by the specific character)
``Graphics.<name>.Text.Title.Offset.x`` | The horizontal distance in pixels the title is offset from the top left of the message box (not it's bounding box)
``Graphics.<name>.Text.Title.Offset.y`` | The vertical distance in pixels the title is offset from the top left of the message box (not it's bounding box)
``Graphics.<name>.Text.Title.Font`` | The name of the font (in fonts.tbl) to use for the title
``Graphics.<name>.Text.Message.Color[]`` | The R, G, B, A values of the text for dialog
``Graphics.<name>.Text.Message.Offset.x`` | The horizontal distance in pixels the dialog is offset from the top left of the message box (not it's bounding box)
``Graphics.<name>.Text.Message.Offset.y`` | The vertical distance in pixels the dialog is offset from the top left of the message box (not it's bounding box)
``Graphics.<name>.Text.Message.Font`` | The name of the font (in fonts.tbl) to use for the dialog
``Graphics.<name>.Text.Message.UnderTitle`` | true if the dialog should be additionally vertically offset by the height of the title text (if it exists). false otherwise
``Graphics.<name>.Text.Title.Color[]`` | The R, G, B, A values of the menu choices
``Graphics.<name>.Text.Title.Offset.x`` | The horizontal distance in pixels the menu choices are offset from the top left of the message box (not it's bounding box)
``Graphics.<name>.Text.Title.Offset.y`` | The vertical distance in pixels the menu choices are offset from the top left of the message box (not it's bounding box)
``Graphics.<name>.Text.Title.Font`` | The name of the font (in fonts.tbl) to use for the menu choices
``Graphics.<name>.MsgBox.File`` | The image file used for the message box background (expected in the interface directory)
``Graphics.<name>.MsgBox.Bounding.Top`` | The distance between the top edge of the image and writable text area
``Graphics.<name>.MsgBox.Bounding.Bottom`` | The distance between the bottom edge of the image and writable text area
``Graphics.<name>.MsgBox.Bounding.Left`` | The distance between the left edge of the image and writable text area
``Graphics.<name>.MsgBox.Bounding.Right`` | The distance between the right edge of the image and writable text area
``Graphics.<name>.MsgBox.Position.x`` | The relative x position of the message box (0 to 1)
``Graphics.<name>.MsgBox.Position.y`` | The relative y position of the message box (0 to 1)
``Graphics.<name>.DefaultBase`` | The filename denoting the default base (the background) for actors. ``<filename>_f`` will be shown in the foreground of the actors if it exists | &#x2713;

Note that in JAD and WoD, two such configurations are used. One for screens with a horizontal resolution of more than 1280, and one for the rest.

### Configuring Actors & Characters
The general concept of actors and characters is that each individual person in the VN is a character. Each character can then have multiple actors (for example one dressed in a pilot suit and one dressed in casual clothes). Each actor can then have multiple emotions. However, one actor of a character having an emotion does not necessitate every actor of this character possessing it. For example, a characters casual actor could possess uncertainty as an emotion, while their pilot-suit actor will never have this as an emotion.
First, defining characters. Each of the characters has a name, that will later be used as the ID when using the SHOW command. This name should not contain spaces.
Key | Value | Optional
-|-|-
``Characters.<name>.Name`` | The name of the character displayed in the title bar of the message box (this one can contain spaces)
``Characters.<name>.Color[]`` | The R, G, B, A values of the name of this character in the title bar
``Characters.<name>.DefaultVoice`` | The filename of a voice clip to be played with each line this character speaks. Use this if your characters have generic mumbling sounds | &#x2713;

For the actors, similarly a name must be assigned. This name corresponds to the actor option in the SHOW command. Note that the config never specifies which actor belongs to which character. This can be used to assign an actor to multiple characters in the VN script, but the use cases are limited for this. The actors as defined in the 
Key | Value | Optional
-|-|-
``Actors.<actor>.Base`` | The filename denoting the base (the background) for this actor. ``<filename>_f`` will be shown in the foreground if it exists | &#x2713;

The rest of the actor is only a collection of an arbitrary number of emotions (each with their own name). The default emotion for an actor is expected to be called "neutral".
Key | Value | Optional
-|-|-
``Actors.<actor>.<emote>.File`` | The filename of the image with the actor with this emote. If no Idle file is specified, the Idle file will be assumed to be located at ``<filename>_b``, but if no special idle animation is needed, the idle file does not need to exist.
``Actors.<actor>.<emote>.Idle`` | The filename of the idle file depicting the actor with this emote when the character is not speaking (note that Idle files are only used with animated sprites)  | &#x2713;
``Actors.<actor>.<emote>.Loop`` | _This must ONLY be set for animated sprites!_<br/> This value defines when and which animation of this emotion is played.<br/> See following 

Loop-table:

Loop | Name | Effect
-|-|-
2 | ALWAYS | The animation in File will be permanently played.
1 | TALKING | The animation in File will be played when the character is talking, the animation in Idle otherwise. If no idle animation exists, the talking animation will be paused.
0 | ONCE | The animation in File will be played once starting the moment it is set or changed to this value. When the character stops talking or the animation looped once, the animation will permanently switch to idle until it is changed again. If no Idle animation exists, it will pause.
-1 | FORCEONCE | The animation in File will be played once starting the moment it is set or changed to this value. When the animation looped once, the animation will permanently switch to idle until it is changed again. If no Idle animation exists, it will stop after looping once.
-2 | PAUSED |  The animation in File will be paused and shown permanently.

### Configuring Bases
Defined bases serve as background for images displayed with SHOWICON, but also define the color of the text displayed on these images. Their name is what is referred to in SHOWICON's color option. However, even with no bases needed for the VN, an empty Bases tag should still be provided.
Key | Value | Optional
-|-|-
``Bases.<name>.File`` | The filename of the background to be displayed behind the image shown by SHOWICON
``Bases.<name>.Color[]`` | The R, G, B, A values that the text with this base should be colored in

### Configuring Displays
Displays can be used when an extended amount of text (potentially accompanied by images) needs to be displayed. Their name will be used to refer to the displays in SHOWDISPLAY's type option.
Key | Value | Optional
-|-|-
``Displays.<name>.Background`` | The filename of the background to be displayed
``Displays.<name>.Output[]`` | A list of the elements to be displayed in the display. Detailed information on how objects within Output[] are structured.

Key | Value | Optional
-|-|-
``Text`` | The filename of the background to be displayed
``Graphic.Filename``<br/>``Graphic.X``<br/>``Graphic.Y`` | Filename is the name of the image accompanying this text. X and Y are respective offsets of the location of the text. The whole Graphic block is optional, but must be complete if included | &#x2713;
``X`` | The x position of the text relative to the top left corner of the background image
``Y`` | The y position of the text relative to the top left corner of the background image
``Font`` | The font to render this text in
``Color[]`` | The R, G, B, A this text should be colored in

### Configuring Maps
Maps are used to let the player choose where they go and with which other characters they talk with, or just to provide graphically interesting menus (see [SHOWMAP](#showmap)). A map has a background image, as well as multiple locations, each with a name, an index and a button.
Key | Value | Optional
-|-|-
``Maps.<name>.Bitmap`` | The filename of the background to be displayed
``Maps.<name>.Locations.<location>.Index`` | The index of this location that will be saved to the result variable if this location is selected. The indices should start at 1 and increment from there
``Maps.<name>.Locations.<location>.Bitmap.Filename`` | The filename of the button that corresponds to this location. The file ``<filename>_h`` will be assumed to be the file shown when the button is hovered, and ``<filename>_c`` will be assumed to be the file shown when the button is clicked
``Maps.<name>.Locations.<location>.Bitmap.X`` | The x position of the button
``Maps.<name>.Locations.<location>.Bitmap.Y`` | The y position of the button
### General Settings
This is a list of further general settings used to influence the VN behavior
Key | Value | Optional
-|-|-
``ScaleFactor`` | Scale all characters' sprites accordingly
``IconScaleFactor`` | Scale all Icons' sprites accordingly
``IconFont`` | The font that is used for the text in SHOWICON
``ScaleDownFromRes`` | If the vertical screen resolution is smaller than this value, scale characters and icons accordingly. Use this to support high resolutions, along with the [graphics configuration](#configuring-graphics)
``WidthBasedScale`` | If true, uses the horizontal screen resolution instead of vertical for ScaleDownFromRes | &#x2713;
``YBuffer`` | The vertical space in pixels between the message box and sprites anchored above it
``Anchor`` | If set to "screen", characters will not appear anchored to the top of the message box when their y position is not set, but rather anchored to the bottom of the screen | &#x2713;
``DefaultBGScale`` | Determines if the background is scaled to the required size if not specified for the individual. One of the following: NOSCALEDOWN (will crop the image if too large, and scale up if too small), NOSCALEUP (letterbox if too small and scale down if too large), NOSCALE (will letterbox if too small and crop if too large), BESTFIT (will scale to fit). NOSCALEDOWN by default | &#x2713;
``OverrideFonts.<font>.<graphics>`` | Specifies fonts from the font table that can be used to override the font of individual lines in the script. ``<font>`` is the name that will be used to refer to the font later. For each override font, this value must be set for all [graphics configurations](#configuring-graphics)| &#x2713;
``TextDraw`` | The speed of the scrolling text. A value of 0.03 is fairly normal
``FutureFiles[]`` | Specify names of files here that extend this config (but may not exist). From these files, actors, characters and bases will be imported. Files further down the list overwrite files further up / the base file in case of overlap. Use this feature to create optional content (as for example WoD's 18+ patch) or extend earlier content (such as JAD 2.21 does with config extensions for JAD 2.22 and 2.23) | &#x2713;
``LockByDefault`` | If set and true, will automatically execute a LOCKDOWN command at the start of each VN scene and an UNLOCKDOWN at each end of a VN scene | &#x2713;

### AxMessage Settings
A few rare options may be nessecary to set in the axmessage.cfg file. If you don't need these options set, the whole axmessage.cfg file is entirely optional. If you do however include axmessage.cfg, it needs to be properly set up. For this, refer to [Axem's GitHub](https://github.com/AxemP/AxemFS2Scripts/blob/master/AxMessage/data/config/axmessage.cfg).
Key | Value 
-|-
``Unicode`` | If set to true it will allow displaying non-ASCII characters. Remember to keep this setting consistent with the setting in FSO's game settings table

## Basic Syntax
Explanation of syntax description markings:
- ``<req>`` means that this is a required field that must be replaced by an appropriate expression / literal / variable / etc.
- ``[optional]`` means that this is an optional field that must be replaced by one or more appropriate expressions / literals / variables / etc.
- ``[OPTIONAL]`` means that this is an optional field that either consists of the string ``OPTIONAL`` (in this example case) or is not present.
- A ``[list of options]`` is a space-separated list of optional ``<key>=<value>`` pairs. 

Also note, that each non-number argument, be it a \<required\> or an [optional] one, can only consist of alphanumeric characters and an underscore and may not begin with a number. Any argument that needs to contain spaces, other special characters or begins with a number need to be encapsulated in quotation marks. As an example, ``this one`` would be parsed as two arguments, ``this`` and ``one``, however ``"that one"`` would be parsed as one argument.

First off, lines that start with a # are judged to be a comment and will be ignored.

To write a message to the screen, simply write the ID of the character that speaks (see [SHOW](#show)), followed by the message to send. This message follows FRED message syntax regarding special characters and variables. This can then be followed by a list of optional options, and potentially ended by the keyword AUTO if the line should pass by itself without user interaction. If the ID is "self", it indicates an internal thought that will not display any sender (hint, use ``Self " " AUTO`` to display an empty / clear the message box).
```
<sender> <text> [list of options] [AUTO]
```
option | effect
-|-
voice | If set, plays the specified sound file when showing this line 
font | If set, overrides the text font with the specified font from the OverrideFonts font
speed | If set, overrides the default speed this line is unveiled at


## Variable Access
Visual Novel scripts have access to two types of variables: VN-internal and SEXP variables.
Whenever a command accesses a variable, SEXP Variables take precedence over VN-internal variables. This means that writing to a variable that exists as a SEXP variable will always change the SEXP variable and never create or modify a VN-internal variable with the same name.
Variables can be named with any combination of letters and numbers (with the same restrictions as standard SEXP Variables when accessing those), but must not start with a number. Variable names also must not contain spaces, $, or underscores (as those are reserved for internal variables).
Unless explicitly specified by the command, variables do not need to be prefixed with a $. 

## Boolean and Arithmetic Expressions
Some commands rely on arithmetic or Boolean data as a parameter. In this case, the following rules to evaluate these parameters are used.
### Arithmetic Expression
Arithmetic expressions are expressions that evaluate to a number. They are equivalent to mathematical formulas comprised of +, -, *, /, as well as parenthesis. [Previously defined variables](#variable-access) are usable, as well as numeric literals. Usually known precedence of parenthesis before * and / before + and - applies. In addition to the commonly known operations, these arithmetic expressions define a random operator that returns a random integer x where a ≤ x ≤ b as ``a R b``. This operator has higher precedence than * and /, but less than parenthesis. This means that, for example, ``0 R 1 * 2`` can return 0 and 2, while ``0 R (1 * 2)`` can return 0, 1 and 2.
Spaces inbetween operators and operands are mandatory for arithmetic expressions as ``+1`` is interpreted as the positive number 1, whereas ``+ 1`` means add 1.
A formal definition of these expressions is:
```
A:= A + A | A - A | A * A | A / A | A R A | (A) | <var> | <number>
```

### Boolean Expression
The Boolean expressions can be used to compare results of arithmetic expressions. Available comparison operators are ``a==b`` for a equals b, ``a!=b`` for a does not equals b, ``a<=b`` for a is less or equal than b, ``a<b`` for a is less than b, ``a>=b`` for a is greater or equal than b and ``a>b`` for a is greater than b. These comparators then result in Boolean values that can be congregated with the commonly known operators ``a&b`` for logical and and ``a|b`` for logical or, ``!a`` for not a, as well as parenthesis similar to those in the arithmetic expressions. Not has a higher precedence than logical and, which has a higher precedence than logical or.
A formal definition of these expressions is:
```
B:= B|B | B&B | !B | (B) | CMP
CMP:= A==A | A!=A | A<=A | A<A | A>=A | A>A
```
## Available Commands

### Basic VN Behavior
#### SHOW
The SHOW command adds new characters to the scene. Syntax:
```
SHOW <id> actor=<actor> [list of options]
```
The id is the identifier which denotes this specific character and by which they can be accessed later in the script and modified. If no character with this ID exists, it doubles as this characters name. The ID "all" is reserved and cannot be used.
option | effect | default
-|-|-
actor | The id of the respective actor in the Actors part of the config | -
emote | The id of the respective emote in the config of this Actor | neutral
x | The x position in 0 to 100, with zero being the left edge of the screen and 100 the right edge | 50
y | The y position in 0 to 100, with zero being aligned to the top of the screen and 100 to the bottom | Just above the anchor
xflip | If the image should be mirrored along the x axis |false
yflip | If the image should be mirrored along the y axis |false
layer | The layer on which this character appears. Higher layers overlay lower layers | 3
from | If set the actor does not appear at the designated position but will enter from the specified side, "left" or "right" | -
fadetime | The time it will take the character to fade in in seconds | 0 
alpha | The target transparency for the character | 1
base | If set, will add the the specified file as background for the character, and ``<filename>_f`` as the foreground if it exists | - 
repeat | Overrides the configs Loop value of the selected sprite if set. See the Name column of the [Loop-table](#configuring-actors--characters) | -
scale | The value by which the image dimensions are scaled | 1
scalewithbg | If set, scales the image to the size of the background | false

#### SHOWIMAGE
The SHOWIMAGE command adds generic images to the scene. Syntax:
```
SHOWIMAGE <id> file=<filename> [list of options]
```
Note, that this ID is shared with the ID of SHOW and SHOWICON. The file ``<filename>_b`` will be assumed to be an idle file (if it exists). This is needed, because generic images share IDs with SHOW and can thus technically speak.
The following options from SHOW are available and behave comparably:
``x``, ``y``, ``xflip``, ``yflip``, ``layer``, ``from``, ``fadetime``, ``alpha``, ``base``, ``repeat``, ``scale``, ``scalewithbg``.


#### MOVE
The MOVE command can modify some options of a character (mostly positional) set by it's SHOW command or a previous MOVE command. The time in seconds over which the options get applied (i.e. the time the actor needs to move to the new target) is specified by the additional option ``time``, which is 1 by default. ``xflip`` and ``yflip`` are exceptions to this, as they are applied at the start of the move. Syntax:
```
MOVE <id> [time=<time>] [list of options]
```
Available options to change: ``x``, ``y``. ``xflip``, ``yflip``, ``scale``, ``alpha``.
The most common use of this command is to move the actors on the screen.
#### CHANGE
The CHANGE command can modify most other options of a character set by it's SHOW command or a previous CHANGE command. All changes by the CHANGE command happen instantly. Syntax:
```
CHANGE <id> [list of options]
```
Available options to change: ``actor``, ``emote``. ``xflip``, ``yflip``, ``layer``, ``base``, ``repeat``.
The most common use of this command is to change the emotions of actors in-between lines.

#### SHOWICON
SHOWICON works similarly to SHOW but is instead used to display briefing icons with text. The file to be displayed is expected in the hud, interface or cbanims directory. Syntax:
```
SHOWICON <id> file=<filename> [list of options]
```
The following options are available and equivalent to their SHOW counterpart: ``x``, ``y``, ``xflip``, ``yflip``, ``layer``, ``scale``.
In addition, two further options are available:
option | effect | default
-|-|-
text | The text to display on top of the icon | -
color | If set, will add the base with the specified id from the Bases part of the config to the icon. Will also color the text in the color specified in the config | -

#### HIDE
HIDE can hide specific (by ID) or all previously shown actors and icons shown with SHOW and SHOWICON. In addition, it is possible to specify the hiding should happen smoothly over the period of half a second or instantly by specifying "now" as a third argument. Syntax:
```
HIDE <id> [NOW]
HIDE ALL [NOW]
```

#### ACTION
The ACTION command can be used to directly influence VN behavior. It's first parameter determines which action is to be performed, while the usage of the following parameters depends on the action.
List of actions:
Action | Result & Usage
-|-
FADEIN | Fades the screen from a solid color to the current image. The first parameter after the  FADEIN is the time in seconds (0 by default), the following three the color in RGB (black by default). Syntax:<br> ```ACTION FADEIN [time] [colorR] [colorG] [colorB]```
FADEOUT | Fades the screen the current image to a solid color. Parameters equivalent to FADEIN. Syntax:<br> ```ACTION FADEOUT [time] [colorR] [colorG] [colorB]```
LOCKDOWN | Locks the players ship (disables weapons, afterburner, ETS, gets taken over by AI with play dead command, as well as increases deceleration by a thousand). With the everything flag set, it will also set the ship flags immobile, protect-ship, afterburners-locked, primaries-locked and secondaries-locked. Syntax:<br> ```ACTION LOCKDOWN [EVERYTHING]```
UNLOCKDOWN | Undoes the player lock. Syntax:<br> ```ACTION UNLOCKDOWN```
ENDMISSION | Ends the VN sequence and the mission. Syntax:<br> ```ACTION ENDMISSION```
ENDSCENE | Ends the VN sequence and returns to the active mission. Can return to the VN via SEXP (the VN-internal variables will stay set). Use this after setting a trigger SEXP-variable to tell FRED the VN segment is over. Syntax:<br> ```ACTION ENDSCENE```
HIDECURSOR | Hides the player's cursor. Syntax:<br> ```ACTION HIDECURSOR```
SHOWCURSOR | Unhides the player's cursor. Syntax:<br> ```ACTION SHOWCURSOR```
HIDEBOX | Hides the dialog box. Syntax:<br> ```ACTION HIDEBOX```
SHOWBOX | Unhides the dialog box. Syntax:<br> ```ACTION SHOWBOX```

#### WAIT
The WAIT command pauses execution of the VN script for a specified duration of time in seconds. With four exceptions, all commands don't take time to execute and the script will continue evaluating the next lines even if the initiated result of a command (for example a MOVE command) is not yet finished. These exceptions are:
- The ``ACTION FADEIN`` and ``ACTION FADEOUT`` commands block the script for their duration.
- A player choice opened by a ``MENU`` command or a ``SHOWMAP`` command will block until player input
- Dialog will stay on the screen and block the script until the screen is clicked after the entirety of the message  was printed.
- Dialog annotated with the AUTO option will stay on the screen and block the script until it has passed.
- The ``WAIT`` command will block the script for the specified duration.

Syntax:
```
WAIT <time>
```

### User Interaction
#### MENU
Menus can be used to provide a simple choice between 1 to 5 choices to the player with the MENU command. Their first 1 to 5 arguments are the text of each choice. As this text will probably contain spaces, remember to encapsulate the choices in quotation marks. In addition, if the text starts with a $, it will be interpreted as a variable name (however, as VN-internal variables can only store numbers, this only really makes sense with SEXP variables). The option "variable" will be used to save which choice has been picked by the player. Note that, this being lua, the result will be 1 to 5. The option "flag" can be used to determine a variable from is read which choices are available to the player (there may be situations where for example the destruction of a ship previously prohibits certain choices). This flag variable will be read bitwise, with bit n being set implying the choice number n is disabled (to set this flag conveniently, refer to SETFLAG). Syntax:
```
MENU <choice1> [choice2] [choice3] [choice4] [choice5] variable=<variable> [flag=<flag>]
```

#### SETFLAG
SETFLAG can be used to easily control the bitfields needed for the MENU command. It toggles (so not only sets!) individual bits of a variable. Count for the least significant bit starts at bit 1, not bit 0, because lua. Bit 1 also is the one that corresponds to choice 1. The first argument is the name of the variable to be changed (created and initialized to 0 if it does not exist). The second is the number of the bit to be changed, or a the name of a variable specifying the bit number. Syntax:
```
SETFLAG <variable> <bit number>
```

### Control Flow
#### LABEL
The LABEL command marks it's position in the script. It can be used to jump to this position from a GOTO command or enter the VN script there from a SEXP. If placed within an IF, ELSEIF or ELSE block, the remaining ELSEIF and ELSE blocks for this IF will be skipped, as if the condition of the block encapsulating the LABEL had naturally been fulfilled. Syntax:
```
LABEL <label name>
```

#### GOTO
GOTO can be used to skip to any previously defined LABEL. Be careful to not create infinite Loops, especially if there is no blocking command to stop the script from creating a stack overflow. Syntax:
```
GOTO <label name>
```

#### IF | ELSEIF | ELSE | ENDIF
The IF command can be used to create conditional dependencies the likes of "if condition then do".
The syntax of the IF command is 
```
IF <condition>
...
ENDIF
```
The conditions are Boolean expression as detailed in [here](#boolean-expression).
"if condition then do (else if condition then do) else do" constructs are also possible with an arbitrary number of "else if condition then do" segments (including 0):
```
IF <condition 1>
...
ELSEIF <condition 2>
...
ELSE
...
ENDIF
```
Each IF statement must have exactly one corresponding ENDIF statement. Every ELSEIF and ELSE statement must follow an IF statement that has not been closed by an ENDIF statement. If further ELSEIF or ELSE statements follow an ELSE statement before a closing ENDIF, they will not be evaluated.
It is possible to nest an IF statement (with corresponding ENDIF) within the do part of another IF statement.

### Appearances and Audio
#### SETBG
The SETBG command set the image displayed in the background. If no background is set or the background is cleared, the current mission camera perspective is shown. This can be used to have a VN scene on top of a cutscene. Syntax:
```
SETBG [list of options]
```
The following options are available:
option | effect | default
-|-|-
file | The file (expected in hud, interface or cbanims) to display. If BLACK, a solid black background is shown. If NONE, the background is cleared | NONE
scaling | Determines if the background is scaled to the required size. One of the following: NOSCALEDOWN, NOSCALEUP, NOSCALE, BESTFIT and DEFAULT (the latter is only allowed when a default is defined in the config). | Config's DefaultBGScale or NOSCALEDOWN if not set.
time | The time it will take to crossfade this and the previous background in seconds. | 0 

#### SHOWDISPLAY
This command adds a Display (see [Configuring Displays](#configuring-displays) for details) to the scene. Syntax:
```
SHOWDISPLAY <id> type=<type> [list of options]
```
The id is the identifier by which this specific display can be accessed later in the script. Freely choosable. The type specifies the name of the display in the config.
option | effect | default
-|-|-
x | The x coordinate of the display relative to the screen size. | 0.5
y | The y coordinate of the display relative to the screen size. | 0.5
align | Where the x coordinate refers to on the display. Can be LEFT (edge of it's background image), RIGHT (edge of it's background image) or CENTER. | LEFT

#### HIDEDISPLAY
HIDEDISPLAY hides a previously shown display with a defined ID. Syntax:
```
HIDEDISPLAY <id>
```

#### SETFONT
The SETFONT command can set the font for the text in the message box. If the argument for the name of the font is not set, it will default to the font set in the config. If no font is defined in the config, it will be the third font in your fonts table. Syntax:
```
SETFONT [font name]
```

#### PLAY
PLAY is a command that is used to play various kinds of audio. It's first argument defines if it is music, a game sound or an interface sound. If music is to be played, the argument ONCE can be appended to specify that the music should not loop. In addition, playing music will make sure that music previously started by the PLAY command is stopped. Music is played by filename, while game and interface sounds are played by their table IDs
Syntax for music:
```
PLAY MUSIC <filename> [ONCE]
```
Syntax for game sounds:
```
PLAY GAMESOUND <id>
```
Syntax for interface sounds:
```
PLAY INTERFACESOUND <id>
```

#### STOPMUSIC
This command stop music started by the PLAY command. Syntax:
```
STOPMUSIC
```

### Maps
Maps are classically used in Visual Novels to give the player a choice where they want to go or what they want to do, thus resulting in interaction with different characters. WoD makes extensive use of maps for this reason. In addition, Maps can be used to provide more graphical menus (compared to the MENU command).

#### LOADMAP
This command loads a [map from the config](#configuring-maps) but not yet displays it. The first argument is the name of the map in the config. The second optional argument can be set to the room the player is currently in, in case this information should be conveyed to the player in form of an icon set by SETMAPICON. Syntax:
```
LOADMAP <map name> [player starting position]
```

#### SETMAPICON
SETMAPICON can be used to add icons on top of the images of individual rooms of a map. This is most commonly used to show the player which dialog options are available in each room. The first parameter is the ID of the icon. If this ID is "self", then this refers to the players icon. Their location will be the place set as default starting position in LOADMAP, or whichever room was the players choice since the last SHOWMAP. If the position was not set during LOADMAP, the players icon will not be shown until a new position was set during SHOWMAP. One option to be set is the filename of the icon. If the ID is not "self", another option determines the position of the icon. Syntax:
```
SETMAPICON SELF file=<filename>
SETMAPICON <id> file=<filename> location=<location>
```

#### HIDEMAPICON
HIDEMAPICON simply removes previously set icons from the map. This is important, since showing a map does not clear the icons. If you want to remove or change the icons in-between showing the map multiple times, you need to manually remove and replace icons that are to be changed. Syntax:
```
HIDEMAPICON <id>
```

#### SHOWMAP
The SHOWMAP command is what actually shows the map and blocks the script until the player made an input. It's first argument defines which variable will contain the index of the room the player clicked on. SHOWMAP can be called multiple times with the same map. This does not need multiple calls to LOADMAP. Do note though, that the position of the player icon (if it is displayed with SETMAPICON) will change to whichever room the player clicked last if SHOWMAP is called again. An optional second parameter can be NOFADE to indicate that the map should not fade out after it. The flag option defined which buttons are clickable, equivalent to MENU. Note that this only works to up to 32 buttons. Currently, the buttons only get activated after 0.5 seconds after displaying the map to avoid accidental clicking. Syntax:
```
SHOWMAP <target variable> [NOFADE] [flag=<flag>]
```

### Interrupts
Interrupts are a method to create a separate VN scene that the player can voluntarily jump to. This can be used in a number of situations. For example, this could be used to create an event where the player can enter the interrupt to hear an inner monologue that explains the current situation. Another use is seen in JAD 2.22, where the player has to identify an impostor in the known cast. The player themselves can choose when they think they know who it is by triggering the interrupt. This is combined with SETVAR so that how far in the dialog they trigger the interrupt has actual significance for the following dialog.

#### SETINT
SETINT sets up and (if applicable) displays the interrupt button. The first argument defines the interrupt trigger.
This mode can be one of the following:
Mode | Effect
-|-
NONE | This makes the interrupt exclusively triggerable by code with FORCEINT
``"@<button filename>"`` | This displays a button to trigger the interrupt. The button will be the specified filename, with (as with all buttons) ``<filename>_h`` being the image to be displayed if the button is hovered and ``<filename>_c`` the image to be displayed when the button is clicked.
PAUSE | This hides the button until an INTRETURN command. This is recommended to execute at the beginning of an interrupt, as clicking the interrupt when already in an interrupt will overwrite the return position, trapping the player in an infinite loop in the interrupt.
NULL | This clears the interrupt. Note that this only means the interrupt cannot be called anymore, but the player will stay in the interrupt until an INTRETURN command

Except for NULL and PAUSE, all SETINT modes take the interrupt target label as the second argument. The third argument is where the player returns to after an INTRETURN, in relative line offset to the position where the interrupt was triggered. By default this is 1, meaning that after an INTRETURN, the script will continue executing with the first line that had not been executed by the time the interrupt was triggered. 
Note that only one interrupt can be active at any one time. Syntax:
```
SETINT <mode> <target label> [return offset]
SETINT NULL
SETINT PAUSE
``` 

#### FORCEINT
This command forcibly triggers the currently set. Syntax:
```
FORCEINT
```

#### INTRETURN
The INTRETURN command returns the script to where the interrupt was called from + the offset defined in SETINT. Note that there may be situations in which you don't want to return from an interrupt and instead continue the script from there. In this case, there is no need to include any INTRETURN command in your interrupt. Syntax:
```
INTRETURN
```

### Miscellaneous
#### SETVAR
SETVAR sets the value of a variable to the result of an [arithmetic expression](#arithmetic-expression). If a SEXP variable with the specified name exist, it will be changed. Otherwise a VN-internal variable with this name will be modified accordingly (or created if necessary).
Syntax:
```
SETVAR <variable> <arithmetic expression>
```
#### FILEVERSION
The FILEVERSION command is a meta-command that defines which (major) version of the Visual Novel script is expected to parse the file. The first argument should be the major version number. A VN script file should start with this command.
On Versions:
Major&nbsp;Version | Notes
-|-
Version&nbsp;3 | This is the version this documentation is about. It is not backwards compatible, so only files tagged with FILEVERSION 3 will be parsed. See [conversion guide](conversionguide.md) for more details.
Version&nbsp;2 | This is the version most commonly known as it was shipped with WoD and JAD. It is backwards compatible to version 1, but only enables features of version 2 with FILEVERSION 2.
Version&nbsp;1 | This version was entirely implemented in SEXPs and thus feature the FILEVERSION command, thus no FILEVERSION command will imply a version 1 script.

Syntax:
```
FILEVERSION <major version number>
```
## Errata
- Changing the alpha of something while a fade is ongoing does not work
- Placing a plus or a minus directly in front of a number causes it to sign the number and not evaluate as an operator. So while ``x + y`` evaluates properly. ``x+y`` would fail to and evaluate to x.
- On rare occasions, hovering buttons in Maps removes the background.
