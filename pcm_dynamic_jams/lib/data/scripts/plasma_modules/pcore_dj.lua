--Compiled from pcore_dj.fnl
--Minimal alterations made for readability, but the compilation process makes
--for fairly ugly code in spots and doesn't preserve all comments
--so in some cases it may be worth looking at the original instead.
local _local_1_ = require("plasma_core")
local print = _local_1_["print"]
local warn_once = _local_1_["warn_once"]
local core = _local_1_
local span_lib = core:get_module("timespan")
local DJ = core:get_module_namespace("pcore_dj")
local function state()
  if not DJ.state then
    print("(state) can't find DJ state")
    return nil
  else
    return DJ.state
  end
end

local function now()
  local state0 = state()
  if state0 then
    return state0.clock.elapsed
  else
    return 0
  end
end

local function segment_instance_stream(segment)
  local _let_4_ = segment
  local segment_name = _let_4_["segment_name"]
  local file_name = _let_4_["file_name"]
  local stream = ad.openAudioStream(file_name, AUDIOSTREAM_EVENTMUSIC)
  if ((stream == nil) or (stream.isValid == false)) then
    print(("LOAD FAILED music segment: " .. segment_name .. " audio stream file: " .. file_name .. "\n"))
    return nil
  else
    return stream
  end
end

local function get_relative_time(a, b, point)
  local start = a
  local _end = b
  if (a ~= b) then
    return ((point - start) / (_end - start))
  else
    return 1
  end
end

local function decode_span(playing, span)
  if ((span == nil) or (#span ~= 2)) then
    return 0
  else
    local _let_7_ = playing
    local beat = _let_7_["beat"]
    local measure = _let_7_["measure"]
    local duration = _let_7_["duration"]
    local _let_8_ = span
    local unit = _let_8_[1]
    local count = _let_8_[2]
    local unit_value
    do
      local _9_ = unit
      if (_9_ == "beat") then
        unit_value = beat
      elseif (_9_ == "measure") then
        unit_value = measure
      elseif (_9_ == "full") then
        unit_value = duration
      elseif (_9_ == "sec") then
        unit_value = 1
      elseif (_9_ == "seconds") then
        unit_value = 1
      elseif true then
        local _ = _9_
        print(unit)
        unit_value = 1
      else
        unit_value = nil
      end
    end
    return (count * unit_value)
  end
end

local function timeline_sort(a, b)
  local A = {starts = (0 <= a.start), ends = (0 <= a["end"])}
  local B = {starts = (0 <= b.start), ends = (0 <= b["end"])}
  if (a.start ~= b.start) then
    if (A.starts and B.starts) then
      return (a.start < b.start)
    else
      return A.starts
    end
  else
    if (A.ends and B.ends) then
      return (a["end"] < b["end"])
    else
      return A.ends
    end
  end
end

local function new_span_from_instance(instance)
  local _let_15_ = instance
  local start = _let_15_["start"]
  local _end = _let_15_["end"]
  local _16_
  if (start and (0 <= start)) then
    _16_ = start
  else
    _16_ = nil
  end
  local function _18_()
    if (_end and (0 <= start) and (start <= _end)) then
      return _end
    else
      return nil
    end
  end
  return span_lib:new(_16_, _18_())
end

local function all_playing(self)
  local list = {}
  for _, item in ipairs(self.state.timeline) do
    if item.playing then
      table.insert(list, item)
    end
  end
  return list
end

local function current_playing(self)
  return all_playing(self)[1]
end

local function _20_(x)
  local _let_21_ = x
  local a = _let_21_["a"]
  local b = _let_21_["b"]
  local c = _let_21_["c"]
  return {a = a, b = b, c = c}
end

local function _22_(x)
  return x
end

local function inst_fade(inst, now0)
  local _let_23_ = inst
  local start = _let_23_["start"]
  local _end = _let_23_["end"]
  local fadeout = _let_23_["fadeout"]
  local fadein = _let_23_["fadein"]
  local progress
  if (0 <= now0) and (now0 <= start) then
    progress = 0
  elseif (start <= now0) and (now0 <= fadein) then
    progress = get_relative_time(start, fadein, now0)
  elseif (_end <= 0) and (0 <= start) and (start <= now0) then
    progress = 1
  elseif (fadeout <= now0) and (now0 <= fadein) then
    progress = 1
  elseif (fadeout <= now0) and (now0 <= _end) then
    progress = (1 - get_relative_time(fadeout, _end, now0))
  elseif (start <= now0) and (now0 <= _end) then
    progress = 1
  else
    progress = 0
  end
  return math.sqrt(progress)
end

local function segment(segment_name)
  return DJ.config.segments[segment_name]
end

local function clear_all(self)
  local state0 = self.state
  local timeline = state0.timeline
  if (state0 and timeline) then
    for i, v in ipairs(timeline) do
      if v.playing then
        do end (v.stream):stop()
        do end (v.stream):close()
      end
      timeline[i] = nil
    end
  end
  state0.counters = {}
  return nil
end

local function play_internal(state0, playable, fade)
  local now0 = now()
  local timeline = state0.timeline
  if (fade.start_new == nil) then
    fade.start_new = now0
  end
  if (fade.finish_f_in == nil) then
    fade.finish_f_in = fade.start_new
  end
  if (fade.begin_f_out == nil) then
    fade.begin_f_out = fade.start_new
  end
  if (fade.end_old == nil) then
    fade.end_old = math.max(fade.finish_f_in, fade.begin_f_out)
  end
  for _, instance in ipairs(timeline) do
    if instance.playing then
      if (instance["end"] < 0) then
        instance.fadeout = fade.begin_f_out
        instance["end"] = fade.end_old
      else
        instance.fadeout = math.min(instance.fadeout, fade.begin_f_out)
        instance["end"] = math.min(instance["end"], fade.end_old)
      end
    end
  end
  playable.start = fade.start_new
  playable.fadein = fade.finish_f_in
  playable["end"] = (playable.start + playable.duration)
  if (playable.segment_type == "loop") then
    playable["end"] = -1
  end
  playable.fadeout = playable["end"]
  table.insert(timeline, playable)
  return table.sort(timeline, timeline_sort)
end

local function get_anchored_time(self, playing, anchor_time, offset)
  if ((playing == nil) or (playing.start == nil) or (offset == nil) or (#offset ~= 2) or (anchor_time == nil)) then
    return anchor_time
  else
    local now0 = now()
    local _let_34_ = playing
    local start = _let_34_["start"]
    local beat = _let_34_["beat"]
    local measure = _let_34_["measure"]
    local duration = _let_34_["duration"]
    local position = (now0 - start)
    local next_end = (start + (duration * math.ceil((position / duration))))
    local function _36_()
      if (#offset == 2) then
        return offset
      else
        return {"_", 0}
      end
    end
    local _let_35_ = _36_()
    local unit = _let_35_[1]
    local count = _let_35_[2]
    if ((#offset ~= 2) or (anchor_time == nil)) then
      return anchor_time
    else
      local m
      do
        local _37_ = unit
        if (_37_ == "beat") then
          m = beat
        elseif (_37_ == "measure") then
          m = measure
        elseif (_37_ == "_") then
          m = 0
        else
          m = nil
        end
      end
      return ((count * m) + anchor_time)
    end
  end
end

local function get_anchor_point_time(self, playing_segment, anchor_point, minimum)
  local now0 = now()
  if ((playing_segment == nil) or (playing_segment.start == nil)) then
    return now0
  else
    local _let_41_ = playing_segment
    local start = _let_41_["start"]
    local playing = _let_41_["playing"]
    local beat = _let_41_["beat"]
    local measure = _let_41_["measure"]
    local duration = _let_41_["duration"]
    local position = (now0 - start)
    local safety = decode_span(playing_segment, minimum)
    local next_end
    do
      local _42_ = playing_segment.segment_type
      if (_42_ == "loop") then
        next_end = (start + (duration * math.ceil(((position + safety) / duration))))
      elseif true then
        local _ = _42_
        next_end = (start + duration)
      else
        next_end = nil
      end
    end
    local function _45_()
      local _44_ = anchor_point
      if (_44_ == "instant") then
        return (now0 + safety)
      elseif (_44_ == "measure") then
        return (start + (measure * math.ceil(((position + safety) / measure))))
      elseif (_44_ == "beat") then
        return (start + (beat * math.ceil(((position + safety) / beat))))
      elseif (_44_ == "end") then
        return next_end
      elseif (_44_ == "end_minus_beat") then
        return (next_end - beat)
      elseif (_44_ == "end_minus_measure") then
        return (next_end - measure)
      elseif true then
        local _ = _44_
        return now0
      else
        return nil
      end
    end
    return math.max(now0, _45_())
  end
end

local function playable_segment(config, segment_name)
  local base = segment(segment_name)
  local _let_48_ = base
  local file_name = _let_48_["file_name"]
  local beats_in_measure = _let_48_["beats_in_measure"]
  local tempo = _let_48_["tempo"]
  local duration = _let_48_["duration"]
  local segment_type = _let_48_["segment_type"]
  local playable = {segment_name = segment_name, file_name = file_name, beats_in_measure = beats_in_measure, tempo = tempo, duration = duration, segment_type = segment_type, beat = (60 / tempo), measure = ((60 / tempo) * beats_in_measure), fade_data = {}, playing = false}
  playable.stream = segment_instance_stream(playable)
  return playable
end

local function fade(fade_name)
  return DJ.config.fades[fade_name]
end

local function play_anchored(self, playable, fade_info)
  local fade0 = {}
  local _let_49_ = fade_info
  local anchor_point = _let_49_["anchor_point"]
  local margin = _let_49_["margin"]
  local start_playing_new = _let_49_["start_playing_new"]
  local end_playing_old = _let_49_["end_playing_old"]
  local current_playing0 = current_playing(self)
  local anchor_time
  if (current_playing0 == nil) then
    anchor_time = now()
  else
    local p = self:get_anchor_point_time(current_playing0, anchor_point, margin)
    anchor_time = p
  end
  fade0.start_new = self:get_anchored_time(current_playing0, anchor_time, start_playing_new)
  if end_playing_old then
    fade0.end_old = self:get_anchored_time(current_playing0, anchor_time, end_playing_old)
  else
    fade0.end_old = fade0.start_new
  end
  if fade_info.start_fade_old then
    fade0.begin_f_out = self:get_anchored_time(current_playing0, anchor_time, fade_info.start_fade_old)
  else
    fade0.begin_f_out = fade0.start_new
  end
  if fade_info.end_fade_new then
    fade0.finish_f_in = self:get_anchored_time(current_playing0, anchor_time, fade_info.end_fade_new)
  else
    fade0.finish_f_in = fade0.end_old
  end
  return play_internal(self.state, playable, fade0)
end

local function handle_clock(clock)
  local tick = ba.getRealFrametime()
  clock.frame = tick
  clock.elapsed = (clock.elapsed + tick)
  return nil
end

local function play_new(self, segment_name, fade_name)
  local segment0 = playable_segment(self.config, segment_name)
  local fade0 = fade(fade_name)
  if (segment0 == nil) then
    return ba.error(("DJ system could not find segment " .. segment_name .. "\n"))
  elseif (fade0 == nil) then
    return ba.error(("DJ system could not find fade " .. fade_name .. "\n"))
  else
    return self:play_anchored(segment0, fade0)
  end
end

local function nearest_interval_count(start_time, interval_size, ref_time)
  local position = ((ref_time - start_time) / interval_size)
  local low = math.floor(position)
  local high = (low + 1)
  local near
  if ((position - low) < (high - position)) then
    near = low
  else
    near = high
  end
  return {low = low, high = high, near = near}
end

local function nearest_interval_time(start_time, interval_size, ref_time)
  local _let_56_ = nearest_interval_count(start_time, interval_size, ref_time)
  local high = _let_56_["high"]
  local near = _let_56_["near"]
  local low = _let_56_["low"]
  return {high = ((interval_size * high) + start_time), low = ((interval_size * low) + start_time), near = ((interval_size * near) + start_time)}
end

local function check_play_span(self, target_segment_name, check_span)
  local found = false
  for _index, instance in ipairs(self.state.timeline) do
    if found then break end
    if (instance.segment_name == target_segment_name) then
      local segment_span = new_span_from_instance(instance)
      found = segment_span:overlaps(check_span)
    end
  end
  return found
end

local function round(num, num_decimal_places)
  local mult = (10 ^ (num_decimal_places or 0))
  return (math.floor(((num * mult) + 0.5)) / mult)
end

local function pretty_time(input)
  return string.format("%+07.2f", input)
end

local function instance_to_string(instance)
  local start = pretty_time(instance.start)
  local fadein = pretty_time(instance.fadein)
  local fadeout = pretty_time(instance.fadeout)
  local _end = pretty_time(instance["end"])
  if (0 < instance["end"]) then
    local function _58_()
      if instance.playing then
        return "playing"
      else
        return ""
      end
    end
    return string.format("\t%8s\t\t%s\t%s\t%s\t%s\t%s", instance.segment_name, start, fadein, fadeout, _end, _58_())
  else
    local function _59_()
      if instance.playing then
        return "playing"
      else
        return ""
      end
    end
    return string.format("\t%8s\t\t%s\t%s\t%s", instance.segment_name, start, fadein, _59_())
  end
end

local function debug(self)
  gr.drawString(("DJ status at time " .. pretty_time(now())), 100, 300)
  local playing = current_playing(self)
  if playing then
    gr.drawString(string.format("currently playing %s", playing.segment_name))
    gr.drawString(string.format("time till next beat: %s s \tmeasure: %s s\t loop/end: %s s", pretty_time(nearest_interval_time(playing.start, playing.beat, now()).high), pretty_time(nearest_interval_time(playing.start, playing.measure, now()).high), pretty_time(nearest_interval_time(playing.start, playing.duration, now()).high)))
    gr.drawString(string.format("name \t start \t fadein \t fadeout \t end \t"))
    local timeline = self.state.timeline
    for _, i in ipairs(timeline) do
      gr.drawString(instance_to_string(i))
    end
    return 
  else
    return nil
  end
end

local function frame(self)
  handle_clock(self.state.clock)
  local counter = 0
  do
    local timeline = self.state.timeline
    local now0 = now()
    local relevant = {}
    for _, inst in ipairs(timeline) do
      if ((inst["end"] < 0) or (now0 < inst["end"]) or inst.playing) then
        table.insert(relevant, inst)
      end
    end
    for _, segment0 in ipairs(relevant) do
      local _let_63_ = segment0
      local playing = _let_63_["playing"]
      local start = _let_63_["start"]
      local _end = _let_63_["end"]
      local segment_name = _let_63_["segment_name"]
      local stream = _let_63_["stream"]
      local segment_type = _let_63_["segment_type"]
      if playing then
        if ((0 <= _end) and (_end < now0)) then
          segment0.playing = false
          stream:stop()
          stream:close()
        end
      else
        if (start < now0) then
          segment0.playing = true
          stream:play(0, (segment_type == "loop"))
        end
      end
    end
    for _, playable in ipairs(all_playing(self)) do
      local newvol = inst_fade(playable, now0)
      local safevol = math.min(1, math.max(0, newvol))
      do end (playable.stream):setVolume((_G.ad.MasterEventMusicVolume * safevol))
    end
  end
  return 
end

local function sexp_dj_queue(self, segment_name, fade_name)
  return self:play_new(segment_name, fade_name)
end

local function sexp_dj_check_span(self, segment_name, high, low)
  if (nil == self.config.segments[segment_name]) then
    warn_once(segment_name, ("DJ tried to check for invalid segment named " .. segment_name), self.state.error_memory)
    return false
  else
    local now0 = now()
    local h
    if (high == "") then
      h = span_lib.high_val
    else
      h = (now0 + tonumber(high))
    end
    local l
    if (low == "") then
      l = span_lib.low_val
    else
      l = (now0 + tonumber(low))
    end
    local span = span_lib:new(l, h)
    return self:check_play_span(segment_name, span)
  end
end

local function sexp_dj_check_mark(self, s_return_unit, s_return_type, s_mark_check, _3fs_offset_amount, _3fs_offset_unit)
  local s_offset_amount
  if _3fs_offset_amount then
    s_offset_amount = _3fs_offset_amount
  else
    s_offset_amount = "0"
  end
  local s_offset_unit
  if _3fs_offset_unit then
    s_offset_unit = _3fs_offset_unit
  else
    s_offset_unit = "s"
  end
  local playing = all_playing(self)[1]
  if not playing then
    warn_once("bad_check_span", "DJ tried to check segment when no music playing", self.state.error_memory)
    return 0
  else
    local _let_72_ = playing
    local beat = _let_72_["beat"]
    local measure = _let_72_["measure"]
    local start = _let_72_["start"]
    local duration = _let_72_["duration"]
    local return_unit
    do
      local _73_ = s_return_unit
      if (_73_ == "s") then
        return_unit = 1
      elseif (_73_ == "b") then
        return_unit = beat
      elseif (_73_ == "m") then
        return_unit = measure
      elseif (_73_ == "_") then
        warn_once("check_mark_return_unit", ("DJ sexp bad return unit" .. s_return_unit), self.state.error_memory)
        return_unit = 1
      else
        return_unit = nil
      end
    end
    local offset_unit
    do
      local _75_ = s_offset_unit
      if (_75_ == "s") then
        offset_unit = 1
      elseif (_75_ == "b") then
        offset_unit = beat
      elseif (_75_ == "m") then
        offset_unit = measure
      elseif (_75_ == "_") then
        warn_once("check_mark_offset_unit", ("DJ sexp bad offset unit" .. s_offset_unit), self.state.error_memory)
        offset_unit = 1
      else
        offset_unit = nil
      end
    end
    local offset_amount = tonumber(s_offset_amount)
    local ref_time = (now() + (offset_amount * offset_unit))
    local interval
    do
      local _77_ = s_mark_check
      if (_77_ == "beat") then
        interval = beat
      elseif (_77_ == "meas") then
        interval = measure
      elseif (_77_ == "seg") then
        interval = duration
      elseif (_77_ == "_") then
        interval = beat
      else
        interval = nil
      end
    end
    local _let_79_ = nearest_interval_time(start, interval, ref_time)
    local high = _let_79_["high"]
    local low = _let_79_["low"]
    local near = _let_79_["near"]
    local r
    local function _81_()
      local _80_ = s_return_type
      if (_80_ == "abs") then
        return math.abs((near - ref_time))
      elseif (_80_ == "diff") then
        return (near - ref_time)
      elseif (_80_ == "next") then
        return (high - ref_time)
      elseif (_80_ == "last") then
        return (ref_time - low)
      elseif (_80_ == "_") then
        return 0
      else
        return nil
      end
    end
    r = (_81_() / (interval / 1000))
    return math.floor(r)
  end
end

local function initialize(self, core0)
  self.state = {clock = {elapsed = 0, frame = 0}, timeline = {}, queue = {}, played = {}, playing = {}, error_memory = {}, counters = {}}
  return nil
end

local function configure(self, core0)
  core0.add_sexp(self, "sexp_dj_queue", "dj-queue")
  core0.add_sexp(self, "sexp_dj_check_span", "dj-check-time-span")
  core0.add_sexp(self, "sexp_dj_check_mark", "dj-time-from-mark")
  local raw_config = core0:load_modular_configs("dj-", "cfg", core0.config_loader_fennel)
  self.config = {}
  do
    local tbl_14_auto = {}
    for fade_name, _84_ in pairs(raw_config.fades) do
      local _each_85_ = _84_
      local anchor_point = _each_85_["align"]
      local start_playing_new = _each_85_["newstart"]
      local end_playing_old = _each_85_["oldend"]
      local start_fade_old = _each_85_["newfade"]
      local end_fade_new = _each_85_["oldfade"]
      local margin = _each_85_["margin"]
      local k_15_auto, v_16_auto = fade_name, {anchor_point = anchor_point, start_playing_new = start_playing_new, end_playing_old = end_playing_old, start_fade_old = start_fade_old, end_fade_new = end_fade_new, margin = margin}
      if ((k_15_auto ~= nil) and (v_16_auto ~= nil)) then
        tbl_14_auto[k_15_auto] = v_16_auto
      end
    end
    self.config.fades = tbl_14_auto
  end
  do
    local tbl_14_auto = {}
    for seg_name, _87_ in pairs(raw_config.segments) do
      local _each_88_ = _87_
      local file_name = _each_88_["file"]
      local beats_in_measure = _each_88_["bpmeasure"]
      local tempo = _each_88_["bpminute"]
      local duration = _each_88_["dur"]
      local segment_type = _each_88_["type"]
      local k_15_auto, v_16_auto = seg_name, {file_name = file_name, beats_in_measure = beats_in_measure, tempo = tempo, duration = duration, segment_type = segment_type}
      if ((k_15_auto ~= nil) and (v_16_auto ~= nil)) then
        tbl_14_auto[k_15_auto] = v_16_auto
      end
    end
    self.config.segments = tbl_14_auto
  end
  return nil
end

local function hook(self, core0)
  core0.add_hook(self, "frame", "On Frame")
  return core0.add_hook(self, "clear_all", "On Mission About To End")
end
return {get_anchored_time = get_anchored_time, get_anchor_point_time = get_anchor_point_time, play_anchored = play_anchored, play_new = play_new, debug = debug, check_play_span = check_play_span, sexp_dj_queue = sexp_dj_queue, sexp_dj_check_span = sexp_dj_check_span, sexp_dj_check_mark = sexp_dj_check_mark, clear_all = clear_all, frame = frame, initialize = initialize, hook = hook, configure = configure}