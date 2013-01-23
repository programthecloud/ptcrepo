require "rubygems"
require "bud"

class Munge
  include Bud
  
  state do
    file_reader :graph_in, "graph.csv"
    scratch :graph, [:key, :val]
    scratch :munged
  end
  
  bloom do
    graph <= graph_in{|i| i.text.split(",")}
    munged <= graph.group([:key], accum(:val))
  end
end

m = Munge.new
m.tick
puts m.munged.to_a.inspect
