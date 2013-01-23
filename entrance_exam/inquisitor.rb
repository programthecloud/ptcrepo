require 'rubygems'

if ENV["COVERAGE"]
  require 'simplecov'
  SimpleCov.command_name 'minitest'
  SimpleCov.root '..'
  SimpleCov.start
end

gem 'minitest'
require 'rest-client'
require 'json'

require 'minitest/autorun'


class TestExam1 < MiniTest::Unit::TestCase
  def do_rest(host, resource, verb, params)
    if verb == :get
      RestClient.get("http://#{host}/#{resource}", {:params => params})
    elsif verb == :post
      RestClient.post("http://#{host}/#{resource}", params)
    end
    
  end

  def do_local_rest(resource, verb, param)
    do_rest(ARGV[0], resource, verb, param)
  end

  def setup
    super
    ARGV.each{|to| do_rest(to, :rst, :post, nil)}
  end


  def test_basic
    do_local_rest(:start_auction, :post, {:name => "anchovies", :end_time => Time.now.to_i + 3})
    do_local_rest(:bid, :post, {:name => "anchovies", :client => 1, :bid => 100})
    do_local_rest(:bid, :post, {:name => "anchovies", :client => 2, :bid => 300})
    do_local_rest(:bid, :post, {:name => "anchovies", :client => 1, :bid => 400})
    
    # running winner
    res = do_local_rest(:status, :get, {:name => "anchovies"})
    assert_equal("1", res.strip)

    # no absolute winner
    res = do_local_rest(:winner, :get, {:name => "anchovies"})
    assert_equal("UNKNOWN", res.strip)

    sleep 5

    res = do_local_rest(:winner, :get, {:name => "anchovies"})
    assert_equal("1", res.strip)

  end
end
