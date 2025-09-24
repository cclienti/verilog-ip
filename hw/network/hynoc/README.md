# HyNoC (High-performance NoC)

**HyNoC** (High-performance NoC) is a Network-On-a-Chip dedicated to
High Performance Computing with static and dynamic routing
capabilities. It can manage any topologies by assembling routers with
a variable number of ports. Each router implements a distributed
arbitration scheme within each port.

---

## Key Features

The HyNoC router is built upon the following characteristics:

* **Wormhole switching**
* **Buffered (FIFO) flow control**
* **Distributed arbitration**
* **Fully parallel round robin** in each distributed arbiter
* **Dedicated clock domain** for each port

A router can be delivered in a fully synchronous way, i.e., the router
and the port use the same clock domain. For more complex designs, the
router can also be delivered with dedicated clock domains for the
router itself (core clock) and for the interfaces (ifce clocks).

A router can also be delivered with 3 to 9 interfaces. Each interface
embeds a synchronous or asynchronous FIFO with a depth configurable
between 2 to 64 elements.

---

## Architecture

A router is made of full-duplex ports which rely on ingress and egress
interfaces and that are respectively plugged to the egress and ingress
of another router's ports. Each router has its own clock domains and
the clock crossing relies on dual-clocked FIFOs at the input of each
ingress interface. A node is attached to a router using a local
interface; this interface instantiates an extra FIFO at the egress
output to support the node's clock domain.

Figure 1 shows both the internal organization of 5-port routers and
how they are connected to their neighbors.

![Router interconnections overview](doc/datasheet/figures/hynoc_noc_overview.png)

The router is a full crossbar, meaning that each port can establish a
communication with all ports except itself. Multiple paths inside the
router can be opened at the same time thanks to the distributed
arbitration scheme. Thus, each egress port embeds an output
multiplexer and an arbiter to route, without starvation, data from the
ingress ports that have requested a transfer.

Figure 2 presents the data paths between ingress and egress. Each
ingress broadcasts its data to all egress ports except to the one
which is grouped in the same router port. Then, the egress will
forward data to the next router depending on the request asserted by
the ingress and also based on the state of the arbiter.

![Internal data path of a 3-port router](doc/datasheet/figures/hynoc_router_data_arch.png)

The control path is shown in Figure 3. Unlike the data path structure,
there is no broadcasting of control signals. Each ingress has
dedicated links with each egress to assert transmit requests and to
receive a grant from an egress. Once the grant is received, the
ingress can push data.

![Internal control path of a 3-port router](doc/datasheet/figures/hynoc_router_control_arch.png)

The egress arbiter uses a parallel Round Robin arbiter that allows all
ingress requests to be scheduled without starvation and with a fixed
latency.

---

## Protocols

### Packet Routing

HyNoC uses source routing techniques to send data through the
routers. Instead of addressing nodes with coordinates, for example
(x,y) for a mesh network topology, we define in the packet header the
path to take through the network. This means the header contains a
list of output ports, called "hops," of routers to cross.

### Packet Structure

A packet consists of multiple flits. A flit is the smallest unit
transmitted over the network and is composed of $K+1$ bits. The most
significant bit is the last bit and it indicates the last flit of a
packet. The table below shows the packet structure. A packet is built
with at least one routing flit followed by at least one payload flit.

| **Last bit** |    **Payload (K bits)**    |
|--------------|----------------------------|
| 0            | 4-bit Proto + Routing flit |
| 0            |            ...             |
| 0            |        Payload flit        |
| 0            |            ...             |
| 1            |     Last payload flit      |

*Packet definition*

### Routing Protocols

Multiple protocols can be supported in a routing flit depending on the
4-bit "Proto" value. The following table shows the supported protocols
and the following subsections describe their operation.

| **Proto value** | **Routing method**               |
|-----------------|----------------------------------|
| 4'b0000         | Unicast Circuit Switch           |
| 4'b0001         | Multicast Circuit Switch         |
| 4'b1000         | XY routing (not yet implemented) |
| 4'b1111         | Forbidden value                  |

*Supported routing protocols*

### Unicast Circuit Switch Routing

In this routing policy, the routing flit is a list of router egress
IDs to be crossed. The "Hop" field for a router with P ports is
encoded using $W=\lceil \log_2(P-1)\rceil$ bits. The "Index" field
points to the correct hop to be used by the router's ingress port.

The hop is encoded in a relative manner depending on the ingress port ID.

Figure 4 shows the list of hops $0 \rightarrow 2 \rightarrow 0
\rightarrow 1 \rightarrow 2$ to establish a communication channel from
node $(0,0)$ to node $(2,2)$ in a $3 \times 3$ mesh network.

![Unicast Circuit Switch hops encoding](doc/datasheet/figures/hynoc_hops_encoding.png)

### Multicast Circuit Switch Routing

The multicast routing policy allows targeting multiple egress ports at
once from a single ingress port. For a router with P ports, the "Hop"
field width is $W=P-1$ bits. The "Index" field points to the correct
hop to be used by the router's ingress port.

Multiple types of routing flits can be combined at the beginning of a
packet.

---

## Router Example: 32-bit 3-port

The 32-bit 3-port router comes with a testbench that demonstrates its
functionality and behavior. The 32-bit 3-port NoC can hold up to 23
hops for unicast packets and up to 11 hops for multicast packets. The
figures below describe the packet structures for the unicast and
multicast protocols.

![Unicast packet structure for 3-port 32-bit NoC](doc/datasheet/figures/hynoc_unicast_packet_3port_32b.png)

![Multicast packet structure for 3-port 32-bit NoC](doc/datasheet/figures/hynoc_mcast_packet_3port_32b.png)

### Parameters

The module parameters declared in the 3-port router module are presented in the following table.

| Name                 | Default Value     | Description                                                                                                 |
|----------------------|-------------------|------------------------------------------------------------------------------------------------------------ |
| INDEX_WIDTH          | 5                 | Bit width of the index in an address flit                                                                   |
| LOG2_FIFO_DEPTH      | 5                 | Size of the FIFO inserted in each port's ingress, expressed in $log_2$ basis                                |
| PAYLOAD_WIDTH        | 32                | Bit width of the payload                                                                                    |
| FLIT_WIDTH           | PAYLOAD_WIDTH + 1 | Bit width of the flit                                                                                       |
| PRRA_PIPELINE        | 0                 | Response of the parallel Round Robin arbiter over 2 cycles if 0, otherwise 3 cycles                         |
| SINGLE_CLOCK_ROUTER  | 0                 | When the value is 1, each port uses the router's clock instead of its own clock to reduce crossing latency  |
| ENABLE_MCAST_ROUTING | 1                 | When the value is 1, it enables the multicast routing protocol                                              |

*3-port 32-bit router parameters*

---

## Place and Route Results

The following table presents some place and route results. The figures
given here are obtained with Altera tools tuned for maximum
performances in terms of frequency. The router considered uses 32-bit
payload words with 16-element dual-clocked FIFOs for each router
interface. Here, the number of memory bits used is directly
proportional to the size of the 16-element FIFOs used: for a 3-port
32-bit router it represents $3 \times 16 \times 32=1536$ bits.

| Router Type   | LEs  | Mem (bits)  | FFs  | Core $f_{max}$ | Ifce $f_{max}$  |
|---------------|------|-------------|------|----------------|---------------- |
| 32-bit 3-port | 730  | 1600        | 450  | 280            | 315             |
| 32-bit 5-port | 1600 | 2650        | 750  | 245            | 315             |
| 32-bit 7-port | 2860 | 3700        | 1150 | 215            | 315             |
| 32-bit 9-port | 4550 | 4750        | 1600 | 195            | 315             |

*Note: These results are for the Altera Cyclone IV E FPGA family with
a Stream protocol.*

---

## Revisions

| Date       | Version | Modification                        |
|------------|---------|-------------------------------------|
| 2020-03-01 | 1.0.1   | Update routing protocol definitions |
| 2020-02-29 | 1.0.0   | Initial version                     |
