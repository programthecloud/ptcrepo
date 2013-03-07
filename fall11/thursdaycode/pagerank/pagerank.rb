require 'rubygems'
require 'bud'
require 'backports'

module MapProtocol
  state do
    interface input, :map_in, [:key, :val]
    interface output, :map_out, [:key, :val]
  end
end

module ReduceProtocol
  state do
    interface input, :reduce_in, [:key, :val]
    interface output, :reduce_out, [:key, :val]
  end
end

module Mapper
  include MapProtocol
  
  state do
    scratch :map_unpacked, [:ident, :pagerank, :adjacencyList]
  end
  
  bloom do
    # bug: dups in map_out get lost!!
    map_out <= map_in
    map_unpacked <= map_in{|m| [m.key, m.val[0], m.val[1]]}
    map_out <= map_unpacked.flat_map do |i|
      i.adjacencyList.map{|n| [n, [(i.pagerank.to_f)/(i.adjacencyList.length), nil]]} unless i.adjacencyList.nil?
    end
  end
end
  
module Reducer
  include ReduceProtocol
  
  state do
    scratch :red_unpacked_weights, [:ident, :pagerank]
    scratch :red_unpacked_adjs, [:ident, :adjacencyList]
    scratch :flat_reduce, [:ident, :pagerank]
  end
  
  bloom do
    # bug: you're losing the previous pagerank of each node; need to sum it in!
    red_unpacked_weights <= reduce_in{|m| [m.key, m.val[0]] if m.val and m.val[1].nil?}
    red_unpacked_adjs <= reduce_in{|m| [m.key, m.val[1]] unless m.val.nil? or m.val[1].nil?}
    flat_reduce <= red_unpacked_weights.group([:ident], sum(:pagerank))
    reduce_out <= (flat_reduce*red_unpacked_adjs).pairs(:ident=>:ident) do |r,a| 
      [r.ident, [r.pagerank, a.adjacencyList]]
    end
  end
end

class SimpleMapReduce
  include Bud
  include Mapper
  include Reducer
  
  state do
    file_reader :graph_txt, "graph.csv"
    scratch :graph_in, [:key, :adj]
    scratch :graph_adj, [:key, :adj_list]
    table :graph, [:ident, :val]
    scratch :result, [:ident, :pagerank, :adjacencyList]
  end
  
  bootstrap do
    graph_in <+ graph_txt{|l| puts "L is #{l}"; l.last.split(',')}
  end

  bloom do
    graph_adj <= graph_in.group([:key], accum(:adj))
    # graph_in is a scratch fed only by bootstrap, so dealt with exactly once
    graph <= graph_adj{|g| [g.key, [1.0] + [g.adj_list.to_a.sort]]}

    map_in <= graph
    reduce_in <= map_out
    graph <+- reduce_out
    result <= reduce_out{|r| [r.key, r.val[0], r.val[1]]}
  end
end

s = SimpleMapReduce.new
s.run_bg
STDOUT.sync = true
10.times {print "."; s.sync_do}
puts
puts s.result.inspected

    
