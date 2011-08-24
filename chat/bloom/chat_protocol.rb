module ChatProtocol
  state do
    channel :mcast
    channel :connect
    channel :disconnect
  end

  DEFAULT_ADDR = "localhost:12345"
end
