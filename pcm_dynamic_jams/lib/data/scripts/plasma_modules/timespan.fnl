(local {: print &as core} (require :plasma_core))

(lambda new [self ?start ?end ?domain]
  (let [lib self
        {: low_val : high_val } self
        start (if ?start ?start low_val)
        end (if ?end ?end high_val)]
    {
    :start (if (not= start self.mark_low) start low_val)
    :end (if (not= end self.mark_high) end high_val)
    :domain (if ?domain ?domain nil)
    :overlaps (lambda [obj ...] (lib.overlaps lib obj ...))
    :to_string (lambda [obj ...] (lib.to_string lib obj ...))
    :contains (lambda [obj ...] (lib.contains lib obj ...))
    }))


(lambda to_string [self]
  (..
    "( "
    (if self.start (tostring self.start) "..")
    " - "
    (if self.end (tostring self.end) "..")
    " )" ))

(lambda overlaps [self a b]
  ;(print {:func :overlaps : self : a : b})
  ;(print (.. "overlap check: " (self.to_string a) ", " (self.to_string b)))
  (or (self:contains a b.start)
      (self:contains a b.end)
      (self:contains b a.start)
      (self:contains b a.end)))

(lambda contains [self span point]
  ;(print (.. "contains( " (self.to_string span) " , " (if ?point ?point "nil") ")"))
  (let [{: start : end} span]
    (if point
        (<= start point end)
        false;(do (print :ef1) false)
        )))
{: new : overlaps : contains : to_string
  :mark_low "-inf"
  :mark_high "inf"
  :low_val -2147483647
  :high_val 2147483647}