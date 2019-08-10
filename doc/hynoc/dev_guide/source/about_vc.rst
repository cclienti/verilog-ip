.. _about_vc:

About Virtual Channels
======================

HyNoC does not implement virtual channels, as proposed by Hermes, for performance reason. Due to multiple clock domains
on each router's port, virtual channels imply to multiply the number of input FIFO buffers. We must keep in mind that
these input FIFO buffers are responsible of almost fifty percents of the total router area, and according to [MEL2005]_,
doubling the number of virtual channels will double router area. Even if there is not multiple clock domains in a
router, the virtual channel scheduling can not be synchronous to the whole network because of routing difficulty and
efficiency. The Scheduling signal must be locally synchronous to one router which imply to use one FIFO buffer per
virtual channel per router's port.

Let's remember the purpose of virtual channels, the main goal is to increase virtual paths into the network and reduce
congestion. This can be also achieved without virtual channels by slightly increasing the number of router and, from the
client point of view, by providing multiple local interfaces connected to multiple router's ports.

In this section, we will discuss about virtual channels efficiency regarding their routing capacities. We will introduce
the counting formula of all shortest paths between two nodes in a NoC with various topology. Then we will compare the
virtual channel solution against the solution with more basic routers for a given ASIC/FPGA area budget.

.. That wihe influence of the topology regarding these paths. The last secondly we will analyze the number of routing
   paths regarding the NoC area.


Counting shortest paths
-----------------------

We want to count the number of minimal paths between two nodes of a NoC. If the two nodes are not located at extremity,
we will consider the *smallest* enclosing these two nodes. The figure :num:`figure-counting-problem` shows a :math:`3
\times 3` network and the six minimum paths between nodes A and B.

.. _figure-counting-problem:
.. figure:: figures/hynoc_counting_problem.*
   :width: 12cm
   :align: center

   The six shortest paths in a :math:`3 \times 3` network.

Counting shortest paths is a problem related to `Catalan Number <http://en.wikipedia.org/wiki/Catalan_number>`_ which
occurs in various counting problems and is equivalent to counting `Dyck words
<http://en.wikipedia.org/wiki/Dyck_word#Applications_in_combinatorics>`_, with *X* corresponds to an horizontal move and
*Y* to a vertical move.

Using Dyck words, all shortest paths of a :math:`3 \times 3` network can be enumerated as follow: XXYY, XYYX, YYXX,
XYXY, YXXY, YXYX.

We can observe that our counting problem can be interpreted by looking for the number of different permutations of *n*
objects, where there are *n*:sub:`1` indistinguishable objects of style 1, *n*:sub:`2` indistinguishable objects of
style 2, ..., and *n*:sub:`K` indistinguishable objects of style K. The equation :eq:`eq-looking-for-permutations` gives
the number *p* of these permutations.

.. math::
   p = {n! \over {\prod\limits^K_{i=1} n_i!}}
   :label: eq-looking-for-permutations

Applying the equation :eq:`eq-looking-for-permutations` to a network with :math:`N \times M` routers, we obtain the
equation :eq:`eq-n-m-permutations`. We can verify analytically with the network :math:`3 \times 3`, proposed in figure
:num:`figure-counting-problem`, that the number of shortest path is *6*.

.. math::
   p = {\left[(N-1) \cdot (M-1)\right]! \over {(N-1)! \cdot (M-1)!}}
   :label: eq-n-m-permutations

We can generalize the equation :eq:`eq-n-m-permutations` to n-dimensional :math:`n_1 \times n_2 \times \cdots \times n_K`
network using the equation :eq:`eq-n-dim-permutations`.

.. math:: p = {\left[\prod\limits^K_{i=1} n_i-1\right]! \over {\prod\limits^K_{i=1} (n_i-1)!}}
   :label: eq-n-dim-permutations


Shortest paths regarding network topology
-----------------------------------------

The following tables gives some figures related to the total number of shortest paths for various NoC topology without
virtual channels.

.. rubric:: 2-dimensional NoC without virtual channels

=================  =================  ===================  ====================
NoC Topology       Number of Routers  Nb shortest paths    Shortest path length
=================  =================  ===================  ====================
 2 × 2               4                        2             2
 4 × 4              16                       20             6
 6 × 6              36                      252            10
 8 × 8              64                     3432            14
10 × 10            100                    48620            18
12 × 12            144                   705432            22
14 × 14            196                 10400600            26
16 × 16            256                155117520            30
=================  =================  ===================  ====================

.. rubric:: 3-dimensional NoC without virtual channels

=================  =================  ===================  ====================
NoC Topology       Number of Routers  Nb shortest paths    Shortest path length
=================  =================  ===================  ====================
 2 × 2 × 2           8                      6               3
 3 × 3 × 3          27                     90               6
 4 × 4 × 4          64                   1680               9
 5 × 5 × 5         125                  34650              12
 6 × 6 × 6         216                 756756              15
=================  =================  ===================  ====================

.. rubric:: 4-dimensional NoC without virtual channels

=================  =================  ===================  ====================
NoC Topology       Number of Routers  Nb shortest paths    Shortest path length
=================  =================  ===================  ====================
 2 × 2 × 2 × 2      16                    24                4
 3 × 3 × 3 × 3      81                  2520                6
 4 × 4 × 4 × 4     256                369600               12
=================  =================  ===================  ====================

We observe that the network topology has a strong influence regarding routing capacities of a network but also with the
shortest path length. For the same number of routers, when the dimension of interconnection topology increases, the
number of shortest paths and their length will decrease. Reducing the number of shortest paths is a drawback while
reducing their lengths is a benefit because the latency is reduced.


Efficiency of virtual channels
------------------------------

Virtual channels can be viewed as an additional dimension to the network topology. This assumption fits well with the
increase number of shortest path powered by virtual channels without increasing the number of routers.  The following
tables show, for various 2-dimensional networks, the impact of virtual channels in terms of number of shortest paths and
their size.

.. rubric:: 2-dimensional NoC with two virtual channels

=================  =================  ===========  ===================  ====================
NoC Topology       Number of Routers  Area [#f1]_  Nb shortest paths    Shortest path length
=================  =================  ===========  ===================  ====================
 2 ×  2 × 2 VC       4                  8                   6            3
 4 ×  4 × 2 VC      16                 32                 140            7
 6 ×  6 × 2 VC      36                 72                2772           11
 8 ×  8 × 2 VC      64                128               51480           15
10 × 10 × 2 VC     100                200              923780           19
12 × 12 × 2 VC     144                288            16224936           23
14 × 14 × 2 VC     196                392           280816200           27
16 × 16 × 2 VC     256                512          4808643120           31
=================  =================  ===========  ===================  ====================

.. rubric:: 2-dimensional NoC with four virtual channels

=================  =================  ===========  ===================  ====================
NoC Topology       Number of Routers  Area [#f1]_  Nb shortest paths    Shortest path length
=================  =================  ===========  ===================  ====================
 2 ×  2 × 4 VC       4                  16                   20          6
 4 ×  4 × 4 VC      16                  64                 1680          9
 6 ×  6 × 4 VC      36                 144                72072         13
 8 ×  8 × 4 VC      64                 256              2333760         17
10 × 10 × 4 VC     100                 400             64664600         21
12 × 12 × 4 VC     144                 576           1622493600         25
14 × 14 × 4 VC     196                 784          38003792400         29
16 × 16 × 4 VC     256                1024         846321189120         33
=================  =================  ===========  ===================  ====================

.. [#f1] The **Area** unit is expressed as number of router with the same topology without virtual channels. It is based
         on [MEL2005]_ observations that the router area grow almost linearly with number of virtual channels. This unit
         is optimistic because it does not take into account the ASIC/FPGA routing effort.

Virtual channels seems to be a good idea, but we must keep in mind that they are not a **true** dimension because of
time multiplexing. The latency can vary depending on the network workload, moreover multiple FIFO must be added to
memorize each channel in each router's port, this strongly increases the total area of the network.

The figure :num:`figure-counting-router` presents the NoC area versus number of router. This figure must be used in
combination with the figure :num:`figure-counting-path` which presents number of shortest paths over the network
area. For instance, a :math:`8 \times 8` network with 4 virtual channels has the same area than a :math:`16 \times 16`
network without virtual channel, but the later has 66 times more shortest paths between two extreme nodes than the
former.

.. _figure-counting-router:
.. figure:: figures/hynoc_routers_versus_area.*
   :width: 15cm
   :align: center

   Network area over number of routers.

.. _figure-counting-path:
.. figure:: figures/hynoc_path_versus_area.*
   :width: 15cm
   :align: center

   Number of shortest paths over area for a 2-dimensional NoC.

Conclusion
----------

We show in this section that the use of virtual channels as a solution to *virtually* increase routing capacity of a
network is costly. We propose an alternative by keeping router simple, without virtual channels, and by adding more
routers in the network dedicated to packet transfer without local interface to a client. This solution increases
drastically the number of shortest paths in the network and therefore will improve the latency and the reliability by
minimizing congestion issues. If the latency is really a key point, topology with a higher number of dimension must be
considered and some extra routers can be added to boost number of shortest routing paths.
