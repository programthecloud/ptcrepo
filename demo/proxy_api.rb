module ProxyProtocol
  state do
    channel :speakToServer, [:@addr, :key, :val]
    channel :listenToServer, [:@addr, :ident, :key]
    channel :rcvFromServer, [:@hear_id, :key, :val]
  end
end