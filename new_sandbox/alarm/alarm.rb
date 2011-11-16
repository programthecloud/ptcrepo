# @abstract AlarmInterface is an abstract interface for setting alarms and receiving alerts.
# An alarm implementation should subclass AlarmInterface.
module AlarmInterface
  state do
    # Used to set up a new alarm for a given duration.
    # @param [Number] ident a unique for an alarm
    # @param [Number] duration the duration of the alarm, in tenths of a second
    interface input, :set_alarm, [:ident] => [:duration]
    
    # Used to terminate an alarm before it completes.
    # @params [Number] ident a unique for an alarm
    interface input, :stop_alarm, [:ident] => []
    
    # Completed alarms are indicated by messages in this output.
    # @params [Number] ident a unique for an alarm
    interface output, :alarm, [:ident] => []
  end
end

# Alarm is a simple, straightfoward implementation of AlarmInterface.
# It sets up alarms, alerts at the end of the specified duraton, and cancels alarms upon request.
# @see Alarm implements AlarmInterface
module Alarm
  include AlarmInterface
  
  state do
    # internal clock, through which the passage of time is simulated
    periodic :ticker, 0.1
    
    # the set of all alarms currently running, with their idents and remaining durations
    table :countdowns, set_alarm.schema
  end
  
  bloom :setup do
    countdowns <= set_alarm
    countdowns <- (countdowns * stop_alarm).lefts(:ident => :ident)
  end
  
  bloom :alarm_logic do
    countdowns <+- (countdowns * ticker).lefts { |c| [c.ident, c.duration - 1] }
    alarm <= countdowns { |c| [c.ident] if c.duration <= 0 }
  end
  
  bloom :cleanup do
    countdowns <- (countdowns * alarm).lefts(:ident => :ident)
  end
end

# RecurringAlarm not only does everything that Alarm does, but it also resets alarms, so that they continue to alert after each consecutive duration, unless the are terminated.
# @see RecurringAlarm extends Alarm
module RecurringAlarm
  include Alarm
  
  state do
    # an additional set of all uncanceled alarms with their original durations
    table :countdown_durations, set_alarm.schema
    #table :countdown_durations, [:duration]
  end
  
  bloom :store_duration do
    countdown_durations <= set_alarm
    countdown_durations <- stop_alarm
  end
  
  bloom :cleanup do
    countdowns <+- (countdown_durations * alarm).lefts(:ident => :ident)
  end
end
