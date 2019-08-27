# -*- python -*-

from wavedisp.ast import *


def generator():
    block = Block()

    block.add(Disp('rclk', radix='binary'))
    block.add(Disp('rsrst', radix='binary'))
    block.add(Disp('ren', radix='binary'))
    block.add(Disp('rdata', radix='hexadecimal'))
    block.add(Disp('rlevel', radix='hexadecimal'))
    block.add(Disp('rempty', radix='binary'))
    block.add(Disp('wclk', radix='binary'))
    block.add(Disp('wsrst', radix='binary'))
    block.add(Disp('wen', radix='binary'))
    block.add(Disp('wdata', radix='hexadecimal'))
    block.add(Disp('wlevel', radix='hexadecimal'))
    block.add(Disp('wfull', radix='binary'))

    read_ptr_gray = block.add(Hierarchy('read_ptr_gray')).add(Group('read_ptr_gray'))
    read_ptr_gray.include('../../bin2gray/project/bin2gray.wave.py')

    write_ptr_gray = block.add(Hierarchy('write_ptr_gray')).add(Group('write_ptr_gray'))
    write_ptr_gray.include('../../bin2gray/project/bin2gray.wave.py')

    read_ptr_bin = block.add(Hierarchy('read_ptr_bin')).add(Group('read_ptr_bin'))
    read_ptr_bin.include('../../gray2bin/project/gray2bin.wave.py')

    write_ptr_bin = block.add(Hierarchy('write_ptr_bin')).add(Group('write_ptr_bin'))
    write_ptr_bin.include('../../gray2bin/project/gray2bin.wave.py')

    return block
