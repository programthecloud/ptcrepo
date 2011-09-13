require 'rubygems'
require 'bud'

class Mem
  include Bud

  state do
    scratch :cell
    scratch :forget_about_cell
  end
  
  bloom :debug do
    stdio <~ cell {|c| ["cell contains " + c.inspect + " at #{budtime}"]}
    stdio <~ forget_about_cell {|f| ["fab contains " + f.inspect + " at #{budtime}"]}
    cell <+ cell { |c| c unless forget_about_cell.include? c }
  end
end

m = Mem.new
m.cell <+ [[:peter, :tall]]
5.times {m.tick}
m.forget_about_cell <+ [[:peter, :tall]]
m.tick
m.cell <+ [[:peter, :declamatory]]
5.times {m.tick}
# m.cell <+ [[:peter, :tall]]
# 5.times {m.tick}
