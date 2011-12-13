require 'rubygems'
require 'bud'

module Colour
  state do
    interface input, :red, [:payload]
    interface input, :green, [:payload]
    interface input, :yellow, [:payload]
    interface input, :blue, [:payload]
    interface input, :magenta, [:payload]
    interface input, :cyan, [:payload]
    interface input, :white, [:payload]
  end

  bloom do
    stdio <~ red { |p| ["\e[0;31m#{p.payload} at timestep #{budtime} on #{ip_port}\e[0m"] }
    stdio <~ green { |p| ["\e[0;32m#{p.payload} at timestep #{budtime} on #{ip_port}\e[0m"] }
    stdio <~ yellow { |p| ["\e[0;33m#{p.payload} at timestep #{budtime} on #{ip_port}\e[0m"] }
    stdio <~ blue { |p| ["\e[0;34m#{p.payload} at timestep #{budtime} on #{ip_port}\e[0m"] }
    stdio <~ magenta { |p| ["\e[0;35m#{p.payload} at timestep #{budtime} on #{ip_port}\e[0m"] }
    stdio <~ cyan { |p| ["\e[0;36m#{p.payload} at timestep #{budtime} on #{ip_port}\e[0m"] }
    stdio <~ white { |p| ["\e[0;37m#{p.payload} at timestep #{budtime} on #{ip_port}\e[0m"] }
  end
end
