module LockMgrProtocol
  state do
    interface input, :request_lock, [:xid, :resource] => [:mode]
    interface input, :end_xact, [:xid]
    interface output, :lock_status, [:xid, :resource] => [:status]
  end
end
