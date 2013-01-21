require 'rubygems'
require 'bud'

module CalmPathMod
  state do
    table :link, [:from, :to] 
    table :hates, [:me, :you]
    scratch :path, [:from, :to]
    scratch :path_buf, [:from, :to]
    scratch :enemies, [:me, :you]
  end
  
  bootstrap do
    link <= [['a', 'b'], ['b', 'c'], ['c', 'd'], ['a', 'e'], ['a','f']]
    hates <= [['b', 'e'], ['e', 'c']]
  end
  
  bloom :reachability do
    path <= link {|p| p unless enemies.include? p}
    path_buf <= (link * path).pairs(:to => :from) {|l,p| [l.from, p.to]}
    path <= path_buf {|p| p unless enemies.include? p}
    enemies <= hates
    enemies <= (enemies*hates).pairs(:you=>:me) {|e,h| [e.me, h.you]}
    stdio <~ path.inspected
  end
end

class Paths
  include Bud
  include CalmPathMod
end

p = Paths.new()
p.tick
puts "done!"
