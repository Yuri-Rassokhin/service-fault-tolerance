# Service Fault Tolerance

This is an OCI Resource Manager stack that turns your conventional application to a fault tolerant, geographically distributed service in a few clicks.
It deployes OCI Compute Instance with a local storage (XFS or ext4) that is synchronously mirrored to remote clone.
In case of a failure, it switches over to the remote clone instantly.
Therefore, it provides contunuous service with zero data loss and zero data delay.

For a given OCI Compute Shape, use gets fault-tolerant HTTP endpoint (hostname) with fault-tolerant local storage behind it.

As a rule, this solution is a great choice for running stateful, high-performance web application as a continuous, disaster-tolerant HTTP service.

## Architecture

The stack deploys 2 identical OCI Compute instances (clones) with the following configuration, from the bottom up:

* OCI Block Volume, one per clone
* iSCSI
* Linux kernel DRBD (block device synchronously mirrored across the clones)
* Pacemaker & Corosync (switchover watchdog)
* Floating IP aka Service IP (automatically siwtched over the clones)
* DNS record for the Service IP aka Service Hostname (spread across the clones)

Service Hostname always points to available clone, no matter the health of the other clone.
Storage remains availalbe and up-to-date, no matter the health of the other clone.

## What's It For?

The architecture intentionally spins around DRBD which defines its features.

1. Active/Passive HA.
2. Synchronous storage replication, aka mirroring.
3. Remote mirroring across OCI datacenters (aka Availability Domains) is fine - within limits of the speed of light.
4. Genuine POSIX behaviour of a local filesystem (XFS, ext4), including deterministic performance of fsync() and such, as opposed to emulatation provided by shared filesystems.
5. Very low latency and performance overhead.

## What it is NOT?

This isn't a shared filesystem, meaninig only one clone can write to storage.
To the contrary, DRBD-enabled design buys efficiency by getting rid of the burden of distributed semantics a-la shared filesystems.

