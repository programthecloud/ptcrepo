require 'rubygems'
require 'bud'

module PathMod
  state do
    table :link, [:from, :to] => []
    table :path, [:from, :to, :the_nodes]
    scratch :path_lengths, [:from, :to, :length_p]
  end

  bloom :reachability do
    path <= link {|l| [l.from, l.to, l]} # 1-hopper
    # path <= (link * link).pairs(:to => :from) # 2-hoppers
    # path <= (link * link * link).pairs(...) # 3-hoppers
    # ...
    path <= (link * path).pairs(link.to => path.from) do |l,p|   # (n+1)-hopper
      [l.from, p.to, [l.from] | p.the_nodes]
    end
    path_lengths <= path {|p| [p.from, p.to, p.the_nodes.length-1]}
    stdio <~ path_lengths {|p| [p.inspect] if p.from == "a" and p.to == "d"}
  end
end

class Paths
  include Bud
  include PathMod
end

p = Paths.new
p.link <+ [["a","b"], ["b", "c"], ["b","e"], ["c","d"], ["e","d"], ["d", "a"], ["a", "d"]]
p.tick
puts "done!"
