.. _router_arch:

Architecture of the router
==========================


General overview
----------------

A router is made of full-duplex ports which rely on ingress and egress interfaces and that are respectively plugged to
egress and ingress of another router's port. Each router has its own clock domains and the crossing rely on dual-clocked
FIFO at the input of each ingress interface. A node is attached to a router using a local interface, this interface
instantiate an extra FIFO a the egress output to support the node's clock domain.

Figure :num:`figure-noc-overview` shows both internal organization of 5-port routers and how they are connected to their
neighbors.

.. _figure-noc-overview:
.. figure:: figures/hynoc_noc_overview.*
   :width: 12cm
   :align: center

   Router interconnections overview

The router is a full crossbar, meaning that each ports can establish a communication to all ports except with
itself. Multiple paths inside the router can be opened at the same time thanks to the distributed arbitration
scheme. Thus, each egress port embeds an output multiplexer and an arbiter to route, without starvation, data from the
ingress ports that has requested a transfer.

Figure :num:`figure-router-data-arch` presents the data paths between ingress and egress. Each ingress broadcasts its
data to all egress ports except to the one which is grouped in the same router port. Then, the egress will forward data
to the next router depending on the request asserted by the ingress ports and also depending on the state of the
arbiter.

.. _figure-router-data-arch:
.. figure:: figures/hynoc_router_data_arch.*
   :width: 13cm
   :align: center

   Internal data path of a 3-port router

The control path is shown in the figures :num:`figure-router-control-arch`. Contrary to the data path structure, there
is no broadcast of control signals. Each ingress has dedicated links with each egress to assert transmit requests and to
receive the grant from an egress. Once the grand is received, the ingress can push data.

.. _figure-router-control-arch:
.. figure:: figures/hynoc_router_control_arch.*
   :width: 13cm
   :align: center

   Internal control path of a 3-port router

The following subsections is a comprehensive description of ingress and egress interface. The egress arbiter is also
described because it use a parallel round-robin arbiter which allows to schedule all ingress requests without starvation
in a fix latency.


Ingress port
------------

The ingress port must manage incoming packets from egress port of another router. It decodes the protocol presented in
section :ref:`first_layer_protocol` to route the flit stream to the right internal router egress port.

The architecture is shown in figure :num:`figure-egress-arch`. The starting point of incoming flit is a :math:`2^D`
depth and :math:`(K+1)`-bit width FIFO instantiated within the ingress port. The incoming data to this FIFO come from
another router's egress port. The clock domain crossing is made using this FIFO, the write port is connected to the
clock domain of the upstream router while the read port uses the clock of the ingress port.

.. _figure-ingress-arch:
.. figure:: figures/hynoc_ingress_arch.*
   :width: 16cm
   :align: center

   Ingress port architecture

Once some flits are buffered in the FIFO, the port extracts the first flit to find the right request bit among the
:math:`N-1` bits (that corresponds to accessible egress ports), waits for a rising edge of the matching grant bit, then
read data from the incoming FIFO and forwards flits to the egress port by managing the flow control. The first flit that
must be forwarded is the routing flit updated to the next hop. When the index of this routing flit is null, this flit is
discarded.

The controller rely on a FSM that reads the two most significant bits of the *fifo_rdata* which indicates the flit
type. Once the flit type is known, the FSM can easily looks for the request bit to assert and opens the transmission
channel with the right egress port. The FSM is also in charge of managing the flow control by both scanning levels of
downstream router FIFO and internal ingress FIFO.



Egress port
-----------

The egress port is connected to :math:`N-1` ingress ports with a data path width :math:`K+1` (including the last flit
bit). It is in charge of scheduling all ingress write requests that have to access to the FIFO of the next router
ingress input. As a reminder, the FIFO depth is :math:`2^D`.

The figure :num:`figure-egress-arch` presents the output port architecture. The arbiter used to prevent starvation is a
parallel round-robin arbiter (PRRA) which responds to any requests in one cycle if the output port is not currently in
use. This arbiter is described in the next section.

.. _figure-egress-arch:
.. figure:: figures/hynoc_egress_arch.*
   :width: 17cm
   :align: center

   Egress port architecture

Once the grant signal is sent to the right ingress port, the data and write enable signal are routed from the ingress to
the next router ingress fifo. The next router ingress fifo level is forwarded to the granted ingress to be able to
manage correctly the flow control.



Arbitration
-----------

The arbitration used in an egress port is based on a round-robin which gives a starvation-free scheduling. The basic
algorithm presented in figure :num:`figure-sequential-round-robin-fsm` relies on a Finite State Machine (FSM) which
scans a specific request at each clock cycle, every time in the same order. When a request is asserted by an ingress
port, and if the round-robin is in the state dedicated to this port, the request will be granted. Once the ingress port
clears its request, the round-robin go to the next state and so on.

.. _figure-sequential-round-robin-fsm:
.. figure:: figures/hynoc_sequential_round_robin_fsm.*
   :width: 7cm
   :align: center

   Sequential implementation of the round-robin


The major drawback of the sequential round-robin implementation is the latency introduced to scan every input even if no
requests are asserted. The opening path latency between two nodes across a large network can be high because of the
delays to grant a request due to the sequential round-robin, so it significantly penalizes small data transfers.

An optimization to reduce drastically the latency is to allow the arbiter to jump directly to the state corresponding to
the request raised. To prevent starvation, priority must be introduced to grant requests in a fair way. Moreover, while
a request is served or if no requests are asserted, the arbiter must not change its state.

Figure :num:`figure-parrallel-round-robin-fsm` shows a parallel implementation of the round robin. The state transition
:math:`P_k` corresponds to the relation given at :eq:`eq-parallel-round-robin-transition`, :math:`P_0` is evaluated with
the highest priority and :math:`P_3` with the lowest priority.

.. math::
   P_k \leftarrow \text{request}[k]==1
   :label: eq-parallel-round-robin-transition

An extra highest priority transition, which is not mentioned on the figure :num:`figure-parrallel-round-robin-fsm`, must
be added to all states to keep the current state until the granted request ends. This end condition is detected when a
lowering edge of the request :math:`k` occurs when the arbiter is in state :math:`k`.

.. _figure-parrallel-round-robin-fsm:
.. figure:: figures/hynoc_parallel_round_robin_fsm.*
   :width: 13cm
   :align: center

   Parallel implementation of the round-robin

Architecture diagram of the parallel round-robin is presented in figure :num:`figure-prra-arch`. The FSM transition's
equations of each states are splitted into LUT. The right LUT is selected using a multiplexer depending on the state
register. This type of implementation allows to provide a simple way to describe, using HDL languages, a generic
parallel priority round-robin arbiter in terms of number of input requests. Moreover, the critical path can be reduced
using optional pipeline registers just after the LUT outputs. Depending on these registers, the arbiter will respond
with one ore two cycles latency.

.. _figure-prra-arch:
.. figure:: figures/hynoc_prra_arch.*
   :width: 14cm
   :align: center

   Parallel round-robin arbiter


Local interface
---------------

Any port of a router can be connected to a node instead of connecting it to another router's port. To ensure a proper
flow control operation, the egress port must be plugged to a FIFO as it was connected to an ingress router's port. This
also ease the clock domain crossing between the node and the network. It adds a buffer to smooth the flow and reduces
the bottlenecks in the network if the node does not consume data quickly enough.
