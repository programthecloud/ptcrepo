require 'rubygems'
require 'test/unit'
require 'bud'
#require 'peter_fifo'
#require 'FIFODelivery-3.rb'
require 'FIFOdelivery-4.rb'

class FC
  include Bud
  include FIFODelivery

  state do
    table :timestamped, [:client, :time, :ident, :payload]
  end

  bloom do
    timestamped <= pipe_chan {|c| [c.src, budtime, c.ident, c.payload]}
  end
end


class TestFIFO < Test::Unit::TestCase
  def workload(fd)
    fd.sync_do { fd.pipe_in <+ [["localhost:12345", fd.ip_port, 3, "qux"]] }
    fd.sync_do { fd.pipe_in <+ [["localhost:12345", fd.ip_port, 1, "bar"]] }
    fd.sync_do { fd.pipe_in <+ [["localhost:12345", fd.ip_port, 0, "foo"]] }
    fd.sync_do { fd.pipe_in <+ [["localhost:12345", fd.ip_port, 2, "baz"]] }
  end

  def test_fifo
    fs = FC.new(:port => 54321)
    fs2 = FC.new(:port => 54322)
    fr = FC.new(:port => 12345)

    fs.run_bg
    fs2.run_bg
    fr.run_bg

    workload(fs2)
    workload(fs)

    4.times {fr.sync_do}

    fr.sync_do do
      fr.timestamped.each do |t|
        fr.timestamped.each do |t2|
          if t.ident < t2.ident and t.client == t2.client
            assert(t.time < t2.time)
          end
        end
      end
      assert_equal(8, fr.timestamped.length)
    end
  end
end
