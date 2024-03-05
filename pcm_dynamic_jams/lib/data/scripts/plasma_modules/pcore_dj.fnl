;;;Module locals, avoiding (let []) to avoid indent for whole file
(local {: print : warn_once &as core} (require :plasma_core))
(local span_lib (core:get_module :timespan))
(local DJ (core:get_module_namespace :pcore_dj))
;;;access functionsget_relative_time
(fn state []
  (if
    (not DJ.state)
    (do (print "(state) can't find DJ state") nil)
    DJ.state))

(fn now []
  (let [state (state)] (if state state.clock.elapsed 0)))
;;Local functions
(lambda segment_instance_stream [segment]
  (let [{: segment_name : file_name} segment]
   ; (print (.. "music segment " segment_name " is opening audio stream " file_name "\n"))
    (let [stream (ad.openAudioStream file_name AUDIOSTREAM_EVENTMUSIC)]
      (if (or (= stream nil) (= stream.isValid false))
          (do (print (.. "LOAD FAILED music segment: " segment_name " audio stream file: " file_name "\n")) nil)
          stream))))

;;A little lerping stuff
(lambda get_relative_time [a b point]
  (let [start a
        end b]
    (if (~= a b)
        (/ (- point start) (- end start))
        1)))

(fn decode_span [playing span]
  (if
    (or (= span nil) (not= (length span) 2))
    0
    (let [{: beat : measure : duration} playing
          [unit count] span
          unit_value  (match unit :beat beat :measure measure :full duration :sec 1 :seconds 1 _ (do (print unit) 1))]
      (* count unit_value))))





;;return true if a should be before b in the timeline
(lambda timeline_sort [a b]
  (let [A {:starts (<= 0 a.start)
            :ends (<= 0 a.end)}
        B {:starts (<= 0 b.start)
            :ends (<= 0 b.end)}]
    (if
      (~= a.start b.start)
      (if 
        (and A.starts B.starts)
        (< a.start b.start)
          ;If they don't both start, we want the ones that don't below the ones that do??? this shouldn't be a valid state but just in case
        A.starts)
        ;If both are equal we want to position based on ends
      (if
        (and A.ends B.ends)
        (< a.end b.end)
        A.ends))))

(lambda new_span_from_instance [instance]
  ;(print {:func :new_span_from_instance : instance})
  (let [{: start : end } instance]
    (span_lib:new
      (if (and start (<= 0 start)) start nil)
      (if (and end (<= 0 start end)) end nil))))


(lambda all_playing [self]
  (local list [])
  (each [_ item (ipairs self.state.timeline)]
    (when
      item.playing
      (table.insert list item)))
  list)


(lambda current_playing [self] (. (all_playing self) 1))

(fn [x] (let [{: a : b : c} x] {: a : b : c}))

(fn [x] {: a : b : c} x)

;
;(lambda current_timings [self]
;  (let [current (current_playing self)]
;    (if current_playing
;    (let [{: start : beat : measure :duration} current_playing)]
;        {: start : beat : measure :duration})
;    {:start 0 :beat 1 :measure 1 :duration 1})))

(lambda inst_fade [inst now]
  (let [{: start : end : fadeout : fadein}  inst
        progress (if (<= 0 now start)
                  0
                  (<= start now fadein)
                  (get_relative_time start fadein now)
                  (<= end 0 start now)
                  1
                  (<= fadeout now fadein)
                  1
                  (<= fadeout now end)
                  (- 1  (get_relative_time fadeout end now))
                  (<= start now end)
                  1
                  0)]

    (math.sqrt progress)))


(lambda segment [segment_name]
  (. DJ.config.segments segment_name))

;;;----------------------------------------------------------------------------------------------------
;;Exported/Member functions

(lambda clear_all [self]
  (let [state self.state
        timeline state.timeline]
  (when (and state timeline)
    (each [i v (ipairs timeline)]
      (when v.playing
            (v.stream:stop)
            (v.stream:close))
      (tset timeline i nil)))
  (set state.counters {} )))

;;Do not decide anything, only implement.
;;Adds a new track to the timeline with a given set of fadein parameters, sets any existingtracks to stop playing.
(lambda play_internal [state playable fade]
  (let [now (now)
        timeline state.timeline]
    ;(print " * * dj.play * *")
    (when (= fade.start_new nil) (set fade.start_new now))
    (when (= fade.finish_f_in nil) (set fade.finish_f_in fade.start_new))
    (when (= fade.begin_f_out nil) (set fade.begin_f_out fade.start_new))
    (when (= fade.end_old nil) (set fade.end_old (math.max fade.finish_f_in fade.begin_f_out)))
    ;(print fade)
      (each [_ instance (ipairs timeline)]
        (when instance.playing
          (if (< instance.end 0)
            (do 
              (set instance.fadeout fade.begin_f_out) (set instance.end fade.end_old))
            (do
              (set instance.fadeout (math.min instance.fadeout fade.begin_f_out))
              (set instance.end (math.min instance.end fade.end_old))))))
      (set playable.start fade.start_new)
      (set playable.fadein fade.finish_f_in)
      (set playable.end (+ playable.start playable.duration))
      (when (= playable.segment_type :loop)
        (set playable.end -1))
      (set playable.fadeout playable.end)
      (table.insert timeline playable)
      (table.sort timeline timeline_sort)))


(fn get_anchored_time [self playing anchor_time offset]
   (if
    (or
      (= playing nil)
      (= playing.start nil)
      (= offset nil) 
      (not= (length offset) 2)
      (= anchor_time nil))
    (do
      anchor_time)
    (let [now (now)
          {: start : beat : measure : duration} playing
          position (- now start)
          next_end (+ start (* duration (math.ceil (/ position duration))))
          [unit count] (if (= (length offset) 2) offset [:_ 0])]

      (if
        (or (not= (length offset) 2) (= anchor_time nil))
        anchor_time;(do (print "early out\n") anchor_time)
        (let [m (match unit :beat beat :measure measure :_ 0)]
        ;;(print m)
        (+ (* count m) anchor_time))
            ;(+ anchor_time(* count (match unit :beat beat :measure measure _ 0)))
            ))))


(fn get_anchor_point_time [self playing_segment anchor_point minimum]
  (let [now (now)]
    (if 
      (or (= playing_segment nil) (= playing_segment.start nil))
      now
      (let [{: start : playing : beat : measure : duration} playing_segment
            position (- now start)
            safety (decode_span playing_segment minimum)
            next_end (match playing_segment.segment_type
              :loop  (+ start (* duration (math.ceil (/ (+ position safety) duration))))
              _ (+ start duration))]
        (math.max now 
          (match anchor_point
            :instant (+ now safety)
            :measure (+ start (* measure (math.ceil (/ (+ position safety) measure))))
            :beat (+ start (* beat (math.ceil (/ (+ position safety) beat))))
            :end next_end
            :end_minus_beat (- next_end beat)
            :end_minus_measure (- next_end measure)
            _ now))
          ))))



;;---------------------------------------------------------------------
;;; (Used by the)^3 module interface



;;; Makes the segment data structure for the timeline
;;
(lambda playable_segment [config segment_name]
  (let [base (segment segment_name)
        {: file_name
          : beats_in_measure
          : tempo
          : duration
          : segment_type} base
        playable {
          : segment_name
          : file_name
          : beats_in_measure
          : tempo
          : duration
          : segment_type
          :beat (/ 60.0 tempo)
          :measure (* (/ 60.0 tempo) beats_in_measure)
          :playing false
          :fade_data {}}]
    (set playable.stream (segment_instance_stream playable))
    playable))


(lambda fade [fade_name]
  (. DJ.config.fades fade_name))


(fn play_anchored [self playable fade_info]
  (let [fade {}
        {: anchor_point : margin : start_playing_new : end_playing_old } fade_info
        current_playing (current_playing self) 
        anchor_time
          (if 
            (= current_playing nil)
            (now)
            (let [p (self:get_anchor_point_time current_playing anchor_point margin)]
             ; (core.print {: current_playing : anchor_point : margin : p})
              p))]

    (set fade.start_new
        (self:get_anchored_time current_playing anchor_time start_playing_new))

    (set fade.end_old
      (if end_playing_old
        (self:get_anchored_time current_playing anchor_time end_playing_old)
        fade.start_new))

    (set fade.begin_f_out
      (if fade_info.start_fade_old
        (self:get_anchored_time current_playing anchor_time fade_info.start_fade_old)
        fade.start_new))

    (set fade.finish_f_in
      (if fade_info.end_fade_new
        (self:get_anchored_time current_playing anchor_time fade_info.end_fade_new)
        fade.end_old))
    (play_internal self.state playable fade)))


;;---------------------------------------------------------------------
;;; (Used by the)^2 module interface




(lambda handle_clock [clock]
  (let [tick (ba.getRealFrametime)]
    ;This needs to eventually watch what state the game is in and not play advance while paused
    (set clock.frame tick)
    (set clock.elapsed (+ clock.elapsed tick))
    nil))
;



;;anchor point defines the center
;;each further one is a unit and a count
(fn play_new [self segment_name fade_name]
  ;(print (.. "DJ attempting to play " segment_name))
  (let [segment (playable_segment self.config segment_name)
        fade (fade fade_name)]
    (if
      (= segment nil)
      (ba.error (.. "DJ system could not find segment " segment_name "\n"))
      (= fade nil)
      (ba.error (.. "DJ system could not find fade " fade_name "\n"))
      (do (self:play_anchored segment fade)))))


(fn nearest_interval_count [start_time interval_size ref_time]
  (let [position (/ (- ref_time start_time) interval_size)
        low (math.floor position)
        high (+ low 1)
        near (if (< (- position low) (- high position)) low high)]
    {: low : high : near}))

(fn nearest_interval_time [start_time interval_size ref_time]
  (let [{: high : near : low} (nearest_interval_count start_time interval_size ref_time)]
    {:high (+ (* interval_size high) start_time)
     :low (+ (* interval_size low) start_time)
     :near (+ (* interval_size near) start_time)}))

(lambda check_play_span [self target_segment_name check_span]
  "assumes check span is in mission time already"
  ;(print {:func :check_play_span : target_segment_name : check_span})
  (var found false)
  (each [_index instance (ipairs self.state.timeline) :until found]
    (when (= instance.segment_name target_segment_name)
      (let [segment_span (new_span_from_instance instance)]
        (set found (segment_span:overlaps check_span)))))
  found)

(fn round [num num_decimal_places]
  (let [mult (^ 10 (or num_decimal_places 0))]
    (/ (math.floor (+ (* num mult) 0.5)) mult)))

(fn pretty_time [input] (string.format "%+07.2f" input))

(lambda instance_to_string [instance]
  ;(print instance)
  (let [start (pretty_time instance.start)
        fadein (pretty_time instance.fadein)
        fadeout (pretty_time instance.fadeout)
        end (pretty_time instance.end)]
  (if 
    (< 0 instance.end)
    (string.format "\t%8s\t\t%s\t%s\t%s\t%s\t%s" instance.segment_name start fadein fadeout end (if instance.playing "playing" ""))
    (string.format "\t%8s\t\t%s\t%s\t%s" instance.segment_name start fadein (if instance.playing "playing" "")))))

(lambda debug [self]
  (gr.drawString (.. "DJ status at time " (pretty_time (now))) 100 300)
  (let [playing (current_playing self)]
    (when playing
      (gr.drawString (string.format "currently playing %s" playing.segment_name))
      (gr.drawString (string.format
          "time till next beat: %s s \tmeasure: %s s\t loop/end: %s s" 
        (pretty_time (. (nearest_interval_time playing.start playing.beat (now)) :high))
        (pretty_time (. (nearest_interval_time playing.start playing.measure (now)) :high))
        (pretty_time (. (nearest_interval_time playing.start playing.duration (now)) :high))))
      (gr.drawString (.. (string.format "name \t start \t fadein \t fadeout \t end \t")))
      (let [timeline self.state.timeline]
        (each [_ i (ipairs timeline)]
          (gr.drawString (instance_to_string i))
        )
    ;  (gr.drawString (.. "Music system status at time " (tostring self.state.clock.elapsed)) 400 300)
      (values)))))
;;---------------------------------------------------------------------
;;; Hook methods

;;;So what the frame needs to do
;  loop through the timeline to see if there's any tracks it needs to start or stop
;  set the volumes on the playing tracks
(lambda frame [self]
  (handle_clock self.state.clock)
  (var counter 0)
  ;(self:debug) ;;UNCOMMENT FOR ON-SCREEN DEBUG INFO
  (let [timeline self.state.timeline
        now (now)
        relevant {}]
    (each [_ inst (ipairs timeline)]
      (when
        (or (< inst.end 0) (< now inst.end) inst.playing)
        (table.insert relevant inst)))
    (each [_ segment (ipairs relevant)]
      (let [{: playing : start : end : segment_name : stream : segment_type} segment]
        (if playing
            ;if playing, check if we are past the end of this track
            (if (and (<= 0 end) (< end now))
                (do ;(print (.. "\t\tstopping " segment_name "\n"))
                    (set segment.playing false)
                    (stream:stop)
                    (stream:close)))
            ;else, when not playing, start playing
            (if (< start now)
                (do
                  ;(print (.. "\t\tstarting " segment.segment_name "\n"))
                  (set segment.playing true)
                  (stream:play 0 (= segment_type :loop)))))))
    (each [_ playable (ipairs (all_playing self))]
      (let [newvol (inst_fade playable now)
            safevol (math.min 1 (math.max 0 newvol))]
        (playable.stream:setVolume (* _G.ad.MasterEventMusicVolume safevol)))))
    (values))


;(lambda do_counts [self]
;  (let [now (now)
;        counters self.state.counters]
;  (each [_ {: increment : next_tick : ticks} counter (pairs counters)]
;    
;    ))

(lambda sexp_dj_queue [self segment_name fade_name]
  (self:play_new segment_name fade_name))

(lambda sexp_dj_check_span [self segment_name high low]
  ;(ba.println (.. "check span segments " (tostring self.config.segments) " timeline " (tostring self.timeline) " checkspan " (tostring self.check_play_span)))
  (if
    (= nil (. self.config.segments segment_name))
    (do (warn_once segment_name (.. "DJ tried to check for invalid segment named " segment_name) self.state.error_memory)
      false)
    ;if valid segment name, main logic.
    (let [now (now)
          h (if (= high "") span_lib.high_val (+ now (tonumber high)))
          l (if (= low "") span_lib.low_val (+ now (tonumber low)))
          span (span_lib:new l h)]
      (self:check_play_span segment_name span)))) 


(lambda sexp_dj_check_mark [self s_return_unit s_return_type s_mark_check ?s_offset_amount ?s_offset_unit]
  (let [s_offset_amount (if ?s_offset_amount ?s_offset_amount "0")
        s_offset_unit (if ?s_offset_unit ?s_offset_unit "s")
        playing (. (all_playing self) 1)] 
    ;(ba.println (.. "check_mark() " (tostring self.sexp_dj_check_mark) "  self[] " (tostring self) " playing() " (tostring playing) " all_playing " (tostring all_playing)))
    (if (not playing)
      (do 
        (warn_once :bad_check_span "DJ tried to check segment when no music playing" self.state.error_memory) 0)
      (let [{: beat : measure : start : duration : start} playing
             return_unit (match s_return_unit :s 1 :b beat :m measure
              :_ (do
                (warn_once :check_mark_return_unit  (.. "DJ sexp bad return unit" s_return_unit) self.state.error_memory)
                1))
            offset_unit (match s_offset_unit :s 1 :b beat :m measure
              :_ (do
                (warn_once :check_mark_offset_unit  (.. "DJ sexp bad offset unit" s_offset_unit) self.state.error_memory)
                1))
            offset_amount (tonumber s_offset_amount)
            ref_time (+ (now) (* offset_amount offset_unit))
            interval (match s_mark_check :beat beat :meas measure :seg duration :_ beat)
            {: high : low : near} (nearest_interval_time start interval ref_time)
            r
            (/ (match s_return_type
              :abs  (math.abs (- near ref_time))
              :diff (- near ref_time)
              :next (- high ref_time)
              :last (- ref_time low)
              :_ 0)
                ;;returing thousandths because fred only knows ints
           (/ interval 1000))]
          ;(print (.. :r= r))
          (math.floor r)))))



;;---------------------------------------------------------------------
;;; Module Interface methods
;;---------------------------------------------------------------------

(lambda initialize [self core]
  (set self.state
        {:clock {:elapsed 0 :frame 0}
        :timeline {}
        :queue {}
        :played {}
        :playing {}
        :error_memory {}
        :counters {}}))



(lambda configure [self core]
  (core.add_sexp self :sexp_dj_queue :dj-queue)
  (core.add_sexp self :sexp_dj_check_span :dj-check-time-span)
  (core.add_sexp self :sexp_dj_check_mark :dj-time-from-mark)
  (let [raw_config (core:load_modular_configs :dj- :cfg core.config_loader_fennel)]
    (set self.config {})
    (set self.config.fades
      (collect [fade_name {:align anchor_point
                           :newstart start_playing_new
                           :oldend end_playing_old
                           :newfade start_fade_old
                           :oldfade end_fade_new
                           : margin} (pairs raw_config.fades)]
        (values fade_name {: anchor_point
                           : start_playing_new
                           : end_playing_old
                           : start_fade_old
                           : end_fade_new
                           : margin})))
  (set self.config.segments
      (collect [seg_name {:file file_name
                          :bpmeasure beats_in_measure
                          :bpminute tempo
                          :dur duration
                          :type segment_type} (pairs raw_config.segments)]
        (values seg_name {: file_name
                          : beats_in_measure
                          : tempo
                          : duration
                          : segment_type})))))



(lambda hook [self core]
  (core.add_hook self :frame "On Frame")
  (core.add_hook self :clear_all "On Mission About To End"))


{
  : get_anchored_time
  : get_anchor_point_time
  : play_anchored
  : play_new
  : debug
  : check_play_span
  : sexp_dj_queue
  : sexp_dj_check_span
  : sexp_dj_check_mark
  : clear_all
  : frame
  : initialize
  : hook
  : configure
}