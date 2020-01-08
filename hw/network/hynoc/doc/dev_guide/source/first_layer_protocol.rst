.. _first_layer_protocol:

First Layer Protocol
====================

Packet routing
--------------

HyNoC uses source routing techniques to send data through routers. Instead of addressing node with coordinates, for
instance (x,y) for a network with a mesh topology, we define in the packet's header the route to take through the
network. This means that the header contains a list of output ports, called *hops*, of routers to cross. This technique
is used by [LIW2007]_ and [MUB2010]_ to avoid congestion with a low packet header overhead using a simple encoding hop
scheme.

A routing algorithm can be defined upon Source Routing network depending on topology. [MUB2010]_ survey presents such a
technique. The routing algorithm generates for each communication the list of hops either dynamically (in hardware in
the local interface or in software using the node's processor) or statically at compilation time.

Routes are established in a distributed way in each router, this technique is presented by [PON2010]_. Each egress
interface manage itself and it is in charge of selecting the right ingress interface using a simple request/acknowledge
protocol. Moreover, the egress interface embeds a LUT-based parallel round robin arbiter to respond in fix amount of
time without creating any starvation.


Packet structure
----------------

A packet is composed of multiple flits, a flit is the smallest unit transmitted over the network and it is composed of
:math:`k+1` bits. The most significant bit is a stop bit and it indicates the last flit of a packet.

The figure :num:`packet-def-1` shows the packet structure. A packet is built with at least one Network Hops flit
followed by at least one Payload flit. If multiple header flits are used to encode the path through the network, the
router will consider only the first flit as a header and the remaining flits as payload. When all hops of the header are
marked used, this header flit will not be forwarded to the next router. Thus, the next router will use the next flit as
a header flit and so on.

.. _packet-def-1:
.. figure:: figures/hynoc_packet_definition_payload.*
   :width: 8cm
   :align: center

   Packet definition using the last payload to close the channel

The figure :num:`packet-def-min-example` presents the smallest packet that can be sent over the network. The number of
router that it can pass through depends on the width of the flit and the number of ports within a router.

.. _packet-def-min-example:
.. figure:: figures/hynoc_packet_definition_min_example.*
   :width: 8cm
   :align: center

   Example of a minimal HyNoC Packet

The Network Hops flit, presented in figure :num:`packet-def-net-hops`, is a list of router egress id to cross. These ids
are encoded as described in the next subsection (see figure :num:`counting-problem`). An index field is included to
point the correct hop to be used by the router's ingress port.

.. _packet-def-net-hops:
.. figure:: figures/hynoc_packet_definition_net_hops.*
   :width: 7cm
   :align: center

   Network Hops flit structure

The index is numbered between :math:`[0, H[` for a flit with :math:`H` hops and it is initialized to :math:`H-1`. This
allows to feed directly the multiplexer command of the ingress port in charge of selecting the right hop in the first
flit of an incoming packet.

The index is decremented once the pointed hop is used to open the path inside the router. If the index is null before
path opening, the related Network Hops flit will not be transmitted to the router's egress port, else the index is
decremented and the Network Hops flit is transmitted.

The MSB bit of the routing flit is set to zero, this will allow in the future to add sub-types to header flit category.


Hops encoding
-------------

The hop encoding is based upon the fact that a same packet can not use the same port for incoming and outgoing. The
number of accessible egress port are :math:`P-1` for a router with :math:`P` ports. This technique also reduces the
internal router's crossbar, or it gives an additional crossbar *free* port that can be used for the local interface with
a network node such as a processor, an accelerator, a memory, ...

The figure :num:`counting-problem` shows the hops list :math:`[0 \rightarrow 2 \rightarrow 0 \rightarrow 1 \rightarrow
2]` to establish a communication channel from node :math:`(0,0)` to node :math:`(2,2)` in a :math:`3 \times 3` mesh
network. This NoC is built upon 5-port routers and only two bits are needed to encode each hop.

.. _counting-problem:
.. figure:: figures/hynoc_hops_encoding.*
   :width: 10cm
   :align: center

   Hops values to communicate between nodes :math:`(0,0)` and :math:`(2,2)` in a :math:`3 \times 3` mesh network.

The drawback of this encoding is that each ports encodes the next counterclockwise egress with the zero id. In other
words, the selected egress id must be calculated by taking into account the ingress id, this is relative egress
addressing.
