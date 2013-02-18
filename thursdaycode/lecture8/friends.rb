require 'rubygems'
require 'bud'

class Friends
  include Bud

  state do
    table :friends, [:name]
    table :happiness, [] => [:cnt] # empty key: at most one item in collection
  end

  bloom do
    # my happiness equals the number of friends I have.
    # empty grouping columns: all items in same group
    happiness <= friends.group([], count)
    
    stdio <~ happiness
  end
end

f = Friends.new(:port=>12345, :trace=>true)
f.friends <+ [['pat'], ['leslie'], ['sam']]
f.tick
