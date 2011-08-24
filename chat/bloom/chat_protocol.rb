module ChatProtocol
  state do
    channel :chatter
    channel :connect
    channel :disconnect
  end

  DEFAULT_ADDR = "localhost:12345"
end
