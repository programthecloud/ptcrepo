require 'rubygems'
require 'bud'

module KingProto
  state do
    interface input, :pretender, [:name]
    interface output, :king, [:name]
  end
end 

module KingChooser
  include KingProto
  state do
    table :chamber, [:name] => [:arrival_time]
    scratch :heir, chamber.schema
    scratch :true_heir, heir.schema
  end

  bloom do
    chamber <= pretender{ |p| [p.name, budtime] }
    #heir <= chamber.group([], choose(:name))
    heir <= chamber.argagg(:min, [], :arrival_time)
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
a.pretender <+ [["Chris"]]
a.tick
a.tick

