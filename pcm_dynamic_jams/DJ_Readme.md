# Dynamic Jams(DJ) system

This module creates a middle ground between direct FRED event managed music and FSO's dynamic music system. DJ SEXPs allows for aligning mission event and musical transitions to the beat, and with the right music files this enables FREDers to get the cinematic effect that timing a mission to a static track can create without the mission rigidity or creation tedium that would normally entail.

# Configuration

Configuration files must be named `dj-*.cfg` and placed in data/configs. They are formatted with [fennel table syntax](https://fennel-lang.org/tutorial#tables), with example files included to pattern off of.

# Transitions

Transitions control how the system switches from one track to another. They have three components.

## Alignment

Alignment, `:align`, defines the point in time the rest of the transition will be relative to.

Possible values:
* `:instant` plays immediately
* `:beat` aligns to the next beat of the currently playing track
* `:measure` aligns to the next completed measure of the currently playing track
* `:end` aligns to the end, or the next loop, of the currently playing track.
* `:end_minus_beat` as the name implies, one beat before the end of the current track. Useful for crossfading in some cases.
* `:end_minus_measure` as above, but one measure instead of one beat
   * Any other value is treated as instant.

## Fade
Fade definition allows you to define a crossfade between two tracks. Volume is managed with the assumption that one is fading in at the same time as the other is fading out, but you can define both periods separately if you want.

Each value of the fade is defined as `[:unit value]`. Valid units are, `:beat`,  `:measure`, `:sec`, or `:full` for the full duration of the track. These are relative to the currently playing track. All fade values are relative to the alignment point, so `[:measure -0.5]` is one half measure before the alignment.

Definable values:
* `:newstart` When to start playing the new track. Negative values do allow starting the track earlier than the alighment point. Defaults to 0s.
* `:endold` When to stop playing the old track. Defaults to 0s.
* `:newfade` optional time to start fading out the old track. Defaults to equal `newstart`
* `:oldfade` optional time to finish fading in the new track. Defaults to equal `endold`

Fade definition is optional.

## Margin
`:margin` lets you set a minimum time that must pass before the anchor point, and is defined the same way as the fade periods. If the anchor point would fall inside the margin it is moved forward to the next valid anchor point.

## Examples

A slow fade over two measures, activated instantly. Useful for fading in from silence to music.
```lisp
:LongFadeI   {:align :instant :newstart [:measure 0] :oldend [:measure 2]}
```

A similar fade anchored to measures, useful for instance for fading out from music to silence 
```lisp
:LongFadeM   {:align :measure :newstart [:measure 0] :oldend [:measure 2]}
```

A crossfade straddling a beat-long transition at a measure. This makes for a slightly noticable dip in the existing loop before the new track kicks in, which may or may not be desirable. The margin setting ensures at least 6 seconds pass before the transition, regardless of the measure length.
```lisp
:ExitLoop6s   {:align :measure :newstart [:beat 0] :oldend [:beat 0.5] :newfade [:beat -0.5] :oldfade [:beat 0.5] :margin [:sec 6]}
```
# Tracks

A track is defined with the following properties. All must be present for a valid track.

* `:file` The filename with extension for the actual music file.
* `:bpmeasure` Beats per measure, the length of a measure in beats.
* `:bpminute` Beats per minute, the tempo of the music.
* `:dur` Duration, the length of the music in seconds
* `:type` Set as `:loop` if the track is looping, any other value for non-looping tracks.

## Examples

A piece of music that is 10s of silence. You may need multiple of these with different beat and measure settings if you want to crossfade into music with different timings.
```lisp
:10s {:file :silent10s.ogg :bpmeasure 4 :bpminute 96 :duration 10 :type :loop}
```

# Usage
Sexps have in-FRED documentation for details, but the following is an overview of the tools and what they were created to do.

## SEXP: (dj-queue "trackname" "transitionname")

This sexp tells the system you want to play a named track, using a named transition. Names are case sensitive. If no track is already playing then the new track will always start immediately.

If a track is already queued when you queue a new track, the previous queued track will be forgotten.

## SEXP: (dj-check-time-span "segment_name" "high_bound" "low_bound")

Used to check if the named track was playing, or is scheduled to change, in the specified band of time. Time is always in seconds, and is added to the current time. The bounds can be left blank, in which case they will be set to the end and start of the timeline respectively.

Expected use is to line events up to musical transitions or to chain together segments.

## SEXP: (dj-time-from-mark "return_unit" "return_type" "mark_check" "offset_amount" "offset_unit")

Returns distance to a point in the musical structure in thousandths of a second, measure or beat. Highly configurable, see the in-FRED documentation for details.

Expected use is to line events up to the musical structure within a track.