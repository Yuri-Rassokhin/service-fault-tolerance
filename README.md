# service-fault-tolerance
Turns your conventional application to a fault tolerant service in a few clicks.
- Stateful fault tolerance for application and its storage
- Strict POSIX semantics of the fault tolerant storage
- True fault tolerance with zero data loss and zero data delay
- Automated switchover in seconds with zero service downtime
- Geographically distributed switchover instance
- Fault tolerance service available via HTTP & SSH (web application) and iSCSI & NFS (storage)

# TODO
- Automatically open VCN Security List ports for the services involved
- Deal with Deprecation Warning: configuring meta attributes without specifying the 'meta' keyword is deprecated and will be removed in a future release
- Add STONITH using OCI API
- Tune corosync.conf according to best-practice for OCI network (mtu, ring0 addr)
- Conduct full check of the resources (pcs status --full)

