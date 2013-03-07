# simple mapreduce
# run "ruby simple_map.rb 127.0.0.1:12345 ulysses_short_1.txt"
# run "ruby simple_map.rb 127.0.0.1:12346 ulysses_short_2.txt"
require 'rubygems'
require 'bud'
require 'zlib'

# read input rows from an interface, pass to mapper, spray results across reducers
module MapTask
  state do
    interface input, :input_rows, [:lineno, :text]  # input rows to be mapped
    interface input, :reducers, [:lineno, :text]    # list of active reducers
    interface output, :mapfn_in, [:lineno] => [:text]
    interface input, :mapfn_out, [:word, :uniq] => [:cnt]
    scratch     :map_results, [:key, :uniq, :value]
    table       :kvs, [:key, :uniq] => [:value, :hashed]
    interface output, :kvs_addrs, [:key, :uniq] => [:value, :addr]
    scratch     :all, [:key, :value]
    scratch     :nodecnt, [] => [:cnt]
  end

  bloom do
    # asynchronously invoke the mapfn
    mapfn_in <= input_rows
    map_results <= mapfn_out
    
    # count number of reducers, hash-partition messages across reducers.
    nodecnt <= reducers.group([], count)
    kvs <= map_results do |mo|
      [mo.key, mo.uniq, mo.value, Zlib.crc32(mo.key) % nodecnt.first.cnt]
    end
      
    kvs_addrs <= (kvs * reducers).pairs(:hashed => :lineno) do |k, r|
      [k.key, k.uniq, k.value, r.text]
    end
  end
end

module WordCntMapFn
  state do
    interface input, :in_table, [:lineno] => [:text]
    interface output, :out_table, [:word, :uniq] => [:cnt]
  end
  
  bloom do
    out_table <= in_table.flat_map do |t|
      t.text.split.each_with_index.map{ |w,i| [w, t.lineno.to_s+':'+i.to_s, 1] }
    end
  end
end

class SimpleMapper
  include Bud
  import WordCntMapFn => :wordCntMap
  import MapTask => :do_map
  
  def initialize(file, options)
    @file = file
    super options
  end
  
  state do
    file_reader :nodes, 'mr_reducelist.txt'
    file_reader :lines, @file
    channel     :shuffle, [:@addr, :key, :value]
  end
  
  bloom do
    # seed the list of reducers
    do_map.reducers <= nodes
    
    # Gimme more input data!
    do_map.input_rows <= lines
    
    # asynchronously invoke map/reduce functions.
    wordCntMap.in_table <= do_map.mapfn_in
    do_map.mapfn_out <= wordCntMap.out_table
    
    # shuffle to all reducers
    shuffle <~ do_map.kvs_addrs { |t| [t.addr, t.key, t.uniq] }
  end
end
  

source = ARGV[0].split(':')
ip = source[0]
port = source[1].to_i
file = ARGV[1]
program = SimpleMapper.new(file, :ip => ip, :port => port)
program.run_bg
sleep 40
