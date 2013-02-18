require 'rubygems'
require 'bud'

class Friends
  include Bud

  state do
    lset :friends
    lmax :happiness
  end
  
  bloom do
    # my happiness equals the number of friends I have.
    happiness <= friends.size()
    stdio <~ [[happiness.inspect]]
  end
end

f = Friends.new(:port=>12345, :trace=>true)
f.friends <+ [['pat'], ['leslie'], ['sam']]
f.tick
