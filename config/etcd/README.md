# etcd3 Distributed Configuration Store (DCS)

This folder documents the `etcd3` consensus cluster powering the Patroni leader election and distributed configuration store (DCS).

## Architecture

The cluster utilizes a 3-node static etcd configuration:
- **`etcd1`**: `http://etcd1:2379` (Client), `http://etcd1:2380` (Peer)
- **`etcd2`**: `http://etcd2:2379` (Client), `http://etcd2:2380` (Peer)
- **`etcd3`**: `http://etcd3:2379` (Client), `http://etcd3:2380` (Peer)

## Quorum & Fault Tolerance

Raft consensus requires a strict majority of voting members to make decisions:
$$\text{Quorum} = \lfloor N/2 \rfloor + 1$$

For a 3-node cluster:
- **Nodes ($N$)**: 3
- **Quorum Needed**: 2
- **Failure Tolerance**: 1 node failure without loss of availability

## Patroni Leader Lock Mechanics

1. Patroni nodes race to acquire a distributed key lease in etcd: `/service/<CLUSTER_SCOPE>/leader`.
2. The winner holds the lease with a Time-To-Live (`PATRONI_TTL=30s`) and heartbeats every `PATRONI_LOOP_WAIT=10s`.
3. If the leader fails to renew its lease before the TTL expires, etcd deletes the key.
4. Remaining healthy standby nodes detect the missing key and initiate an automatic failover election to promote the replica with the lowest replication lag.
