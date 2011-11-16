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

module Alarm
  include AlarmInterface
end


module RecurringAlarm
  include Alarm
end
