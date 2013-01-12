require 'rubygems'
require 'bud'
require 'test/unit'
require 'kvs/rowo'

class TestQuorum < Test::Unit::TestCase
  class ROWOBloom
    include Bud
    include ReadOneWriteOne

    bootstrap do
      add_member <= [
        ['localhost:54321', 1],
        ['localhost:54322', 2],
        ['localhost:54323', 3]
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

    acks = p1.sync_do {p1.kvput <+ [[1, :joe, 1, :hellerstein]]}
    acks = p2.sync_do {p2.kvput <+ [[2, :peter, 2, :alvaro]]}
    acks = p3.sync_do {p3.kvput <+ [[3, :joe, 3, :piscopo]]}
    acks = p3.sync_do {p3.kvput <+ [[3, :peter, 4, :tosh]]}
    resps = p1.sync_callback(p1.kvget.tabname, [[5, :joe]], p1.kvget_response.tabname)
    assert_equal([[5, "joe", "piscopo"]], resps)
    resps = p3.sync_callback(p1.kvget.tabname, [[6, :joe]], p1.kvget_response.tabname)
    assert_equal([[6, "joe", "piscopo"]], resps)
    resps = p1.sync_callback(p1.kvget.tabname, [[7, :peter]], p1.kvget_response.tabname)
    assert_equal([[7, "peter", "tosh"]], resps)
    resps = p3.sync_callback(p3.kvget.tabname, [[8, :peter]], p1.kvget_response.tabname)
    assert_equal([[8, "peter", "tosh"]], resps)
    p1.stop
    p2.stop
    p3.stop(true, true)
  end
end

