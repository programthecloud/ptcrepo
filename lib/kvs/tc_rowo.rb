require 'rubygems'
require 'bud'
require 'test/unit'
require 'rowo'

class TestQuorum < Test::Unit::TestCase
  class ROWOBloom
    include Bud
    include ReadOneWriteOne

    bootstrap do
      add_member <= [
        [1, 'localhost:54321'],
        [2, 'localhost:54322'],
        [3, 'localhost:54323']
      ]
    end
  end

  def test_rowo
    p1 = ROWOBloom.new(:port=>54321)
    p1.run_bg
    p2 = ROWOBloom.new(:port=>54322)
    p2.run_bg
    p3 = ROWOBloom.new(:port=>54323)
    p3.run_bg

    acks = p1.sync_callback(:kvput, [[1, :joe, 1, :hellerstein]], :kv_acks)
    assert_equal([[1]], acks)
    acks = p2.sync_callback(:kvput, [[2, :peter, 2, :alvaro]], :kv_acks)
    assert_equal([[2]], acks)
    acks = p3.sync_callback(:kvput, [[3, :joe, 3, :piscopo]], :kv_acks)
    assert_equal([[3]], acks)
    acks = p3.sync_callback(:kvput, [[3, :peter, 4, :tosh]], :kv_acks)
    assert_equal([[4]], acks)
    resps = p1.sync_callback(:kvget, [[5, :joe]], :kvget_response)
    assert_equal([[5, "joe", "piscopo"]], resps)
    resps = p3.sync_callback(:kvget, [[6, :joe]], :kvget_response)
    assert_equal([[6, "joe", "piscopo"]], resps)
    resps = p1.sync_callback(:kvget, [[7, :peter]], :kvget_response)
    assert_equal([[7, "peter", "tosh"]], resps)
    resps = p3.sync_callback(:kvget, [[8, :peter]], :kvget_response)
    assert_equal([[8, "peter", "tosh"]], resps)
    p1.stop
    p2.stop
    p3.stop(true, true)
  end
end

