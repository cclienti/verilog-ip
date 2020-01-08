#!/usr/bin/env python3

import matplotlib.pyplot as pyplot
from pylab import array
from math import factorial


def hynoc_nb_path(dim_list, nb_vc=1):
    """Return the number of path between NoC extremities
    dim_list is [3,3] for a 2D 3x3 NoC
    nb_vc is the number of virtual channel
    """

    n_list = array(dim_list)-1
    n_vc = nb_vc-1;
    n = sum(n_list) + n_vc;

    denom = factorial(n_vc)
    for n_i in n_list:
        denom = denom * factorial(n_i)

    return factorial(n)/denom

###############
### Build stats
###############

dim1 = range(2, 18)

# get nb path for NoC 3x3 to 16x16 with one VC
nb_routers_one_vc = array([ i**2 for i in dim1])
area_one_vc = nb_routers_one_vc
nb_path_versus_area_one_vc = [ hynoc_nb_path([i, i], 1) for i in  dim1]


# get nb path for NoC 3x3 to 16x16 with two VC
nb_routers_two_vc = nb_routers_one_vc
area_two_vc = nb_routers_two_vc * 2
nb_path_versus_area_two_vc = [ hynoc_nb_path([i, i], 2) for i in dim1 ]


# get nb path for NoC 3x3 to 16x16 with four VC
nb_routers_four_vc = nb_routers_one_vc
area_four_vc = nb_routers_four_vc * 4
nb_path_versus_area_four_vc = [ hynoc_nb_path([i, i], 4) for i in dim1 ]

################
### Plot results
################

# plot nb path versus area
pyplot.clf()
pyplot.subplot(1, 1, 1)

pyplot.grid(b=True, which='major', color='0.3', linestyle='-')
pyplot.grid(b=True, which='minor', color='0.8', linestyle='-')
pyplot.yscale('log')

p1, = pyplot.plot(area_one_vc, nb_path_versus_area_one_vc, color='blue', lw=2)
p2, = pyplot.plot(area_two_vc[:12], nb_path_versus_area_two_vc[:12], color='red', lw=2)
p3, = pyplot.plot(area_four_vc[:8], nb_path_versus_area_four_vc[:8], color='gray', lw=2)

pyplot.plot(area_one_vc[14], nb_path_versus_area_one_vc[14], 'rD')
pyplot.plot(area_four_vc[6], nb_path_versus_area_four_vc[6], 'rD')
pyplot.axvline(x=area_one_vc[14],color='k',ls='dashed')
pyplot.axhline(y=nb_path_versus_area_one_vc[14],color='k',ls='dashed')
pyplot.axhline(y=nb_path_versus_area_four_vc[6],color='k',ls='dashed')

pyplot.legend([p1, p2, p3], ['No VC', '2 VC', '4 VC'])
pyplot.savefig('hynoc_path_versus_area.eps')
pyplot.savefig('hynoc_path_versus_area.png')

# plot area versus number of routers
pyplot.clf()

pyplot.grid(b=True, which='major', color='0.3', linestyle='-')

p1, = pyplot.plot(nb_routers_one_vc, area_one_vc, color='blue', lw=2)
p2, = pyplot.plot(nb_routers_two_vc, area_two_vc, color='red', lw=2)
p3, = pyplot.plot(nb_routers_four_vc, area_four_vc, color='gray', lw=2)

pyplot.plot(nb_routers_one_vc[14], area_one_vc[14], 'rD')
pyplot.plot(nb_routers_four_vc[6], area_four_vc[6], 'rD')
pyplot.axhline(y=area_one_vc[14],color='k',ls='dashed')
pyplot.axvline(x=nb_routers_one_vc[14],color='k',ls='dashed')
pyplot.axvline(x=nb_routers_one_vc[6],color='k',ls='dashed')

pyplot.legend([p1, p2, p3], ['No VC', '2 VC', '4 VC'])
pyplot.savefig('hynoc_routers_versus_area.eps')
pyplot.savefig('hynoc_routers_versus_area.png')

################
### Print tables
################

# 2D stats
print('2D')
print('=================  =================  ========  ===================')
print('NoC Topology       Number of Routers  NoC Area  Nb shortest paths  ')
print('=================  =================  ========  ===================')
for i in range(2,17):
    print('%2d x %2d            %3d                %4d      %9d' % (i, i, i**2, i**2, hynoc_nb_path([i, i], 1)))
print('=================  =================  ========  ===================\n')

# 2D stats + 2VC
print('2D + 2VC')
print('=================  =================  ========  ===================')
print('NoC Topology       Number of Routers  NoC Area  Nb shortest paths  ')
print('=================  =================  ========  ===================')
for i in range(2,17):
    print('%2d x %2d x %2d       %3d               %4d      %11d' % (i, i, 2, i**2, i**2*2, hynoc_nb_path([i, i], 2)))
print('=================  =================  ========  ===================\n')


# 2D stats + 4VC
print('2D + 4VC')
print('=================  =================  ========  ===================')
print('NoC Topology       Number of Routers  NoC Area  Nb shortest paths  ')
print('=================  =================  ========  ===================')
for i in range(2,17):
    print('%2d x %2d x %2d       %3d                %4d     %13d' % (i, i, 4, i**2, i**2*4, hynoc_nb_path([i, i], 4)))
print('=================  =================  ========  ===================\n')


# 3D stats
print('3D')
print('=================  =================  ========  ===================')
print('NoC Topology       Number of Routers  NoC Area  Nb shortest paths  ')
print('=================  =================  ========  ===================')
for i in range(2,8):
    print('%2d x %2d x %2d       %3d               %4d      %9d' % (i, i, i, i**3, i**3, hynoc_nb_path([i, i, i], 1)))
print('=================  =================  ========  ===================\n')


# 4D stats
print('4D')
print('=================  =================  ========  ===================')
print('NoC Topology       Number of Routers  NoC Area  Nb shortest paths  ')
print('=================  =================  ========  ===================')
for i in range(2,5):
    print('%2d x %2d x %2d x %2d  %3d               %4d    %9d' % (i, i, i, i, i**4, i**4, hynoc_nb_path([i, i, i, i], 1)))
print('=================  =================  ========  ===================\n')
