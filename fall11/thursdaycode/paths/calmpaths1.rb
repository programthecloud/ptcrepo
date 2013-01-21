require 'rubygems'
require 'bud'

module CalmPathMod
  state do
    table :link, [:from, :to]
    table :path, [:from, :to]
  end
  
  bootstrap {link <= [['a', 'b'], ['a', 'c'], ['b', 'd']]}

  bloom :reachability do
    path <= link
    path <= (link * path).pairs(:to => :from) {|l,p| [l.from, p.to]}
    stdio <~ path.inspected
  end
end

class Paths
  include Bud
  include CalmPathMod
end

p = Paths.new
p.tick
puts "done!"
