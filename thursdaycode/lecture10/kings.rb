require 'rubygems'
require 'bud'

module KingChooser
  state do
    table :chamber, [:name] => [:arrival_time]
    scratch :heir, chamber.schema
    scratch :true_heir, heir.schema
  end

  bloom do
    chamber <= pretender{ |p| [p.name, budtime] }
    #heir <= chamber.group([], choose(:name))
    heir <= chamber.argagg(:min, [:name], :arrival_time)
    true_heir <= heir.group([], choose(:name))
    king <= true_heir{ |h| [h.name] }
    chamber <- (true_heir*chamber).rights(:name => :name)

    stdio <~ king{|k| ["#{budtime}-#{k}"]}
  end
end

class KC
  include Bud
  include KingChooser
end

a = KC.new(:trace => true, :port => 1234)
a.pretender <+ [["Joe"]]
a.tick
a.pretender <+ [["Peter"],["Josh"]]
a.tick
a.tick

