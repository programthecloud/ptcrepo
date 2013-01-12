require 'rubygems'
require 'bud'
require 'bud/bust/client/restclient'
require 'json'
require 'ordering/nonce'
require 'test/unit'

EXEC="echo hello world"


class Dispatcher # :nodoc: all
  include Bud
  include RestClient
  include TimestepNonce

  state do
    interface input, :dispatch, [:rtype, :tab, :params]
  end

  bloom do
    rest_req <= (dispatch * nonce).pairs do |d, n|
      [n.ident, d.rtype, nil, "http://localhost:8080/#{d.tab}", d.params]
    end

    stdio <~ rest_response do |r|
      [r.rid, r.resp.inspect, r.exception] unless r.exception
      ["FAIL: #{r.exception}"] if r.exception
    end
  end
end

class DispatchInterface
  def self.sync_dispatch(te, rtype, tab, params)
    res = te.sync_callback(:dispatch, [[rtype, tab, params]], :rest_response)
    puts "RES is #{res.first.inspect}"
    if res.first[2] 
      raise "Failure: #{res.first[2]}"
    else
      # in general we'd expect a REST response body to be a format like
      # JSON or XML.  for this exercise, we'll expect a scalar: the 
      # winner of the vote.
      #return res.first[1] == "" ? nil : JSON.parse(res.first[1].chomp)
      return res.first[1] == "" ? nil : res.first[1].chomp
    end
  end
end

class TestCounter < Test::Unit::TestCase
  
  def tribunal(te)
    # establish a tribunal with 3 voters: {A, B, C}
    DispatchInterface.sync_dispatch(te, :post, :rst, {:vd => "reset"})
    DispatchInterface.sync_dispatch(te, :post, :member, {:agent => 'A'})
    DispatchInterface.sync_dispatch(te, :post, :member, {:agent => 'B'})
    DispatchInterface.sync_dispatch(te, :post, :member, {:agent => 'C'})
  end
  
  def last_presidential(te)
    # A and C vote for obama, B for mccain.
    DispatchInterface.sync_dispatch(te, :post, :vote, {:agent => 'A', :vote => 'obama'})
    DispatchInterface.sync_dispatch(te, :post, :vote, {:agent => 'B', :vote => 'mccain'})
    # a tie.
    resp = DispatchInterface.sync_dispatch(te, :get, :victor, nil)
    assert_equal("UNKNOWN", resp)
    # the tiebreaker
    DispatchInterface.sync_dispatch(te, :post, :vote, {:agent => 'C', :vote => 'obama'})
    resp = DispatchInterface.sync_dispatch(te, :get, :victor, nil)
    assert_equal('obama', resp)
  end
  
  def test_basic_voting
    te = Dispatcher.new
    te.run_bg
    tribunal(te)
    last_presidential(te)
    te.stop_bg
  end

end

