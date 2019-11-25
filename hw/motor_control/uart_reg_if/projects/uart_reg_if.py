#!/usr/bin/env python

import sys
import argparse
import serial
from serial.tools.list_ports import comports


class UartRegIf():
    """Manage the register interface to read and write register using an
    UART interface.

    :param tty: str, tty interface
    :param speed: int, tty speed value (bauds)
    :param num_bytes: int, number of bytes per register, defaults to 4
    :param timeout: int, serial interface timeout (seconds), defaults to 1
    """

    PROTO_INDEX = b'S'
    PROTO_READ = b'R'
    PROTO_WRITE = b'W'

    def __init__(self, tty, speed, num_bytes=4, timeout=1):
        self.num_bytes = num_bytes
        self.serial = serial.Serial(tty, speed, timeout=timeout)

    def write(self, index, value):
        """Write value in the register at the specified index.

        :param index: int, register index
        :param value: int, register value
        """
        self.serial.write(UartRegIf.PROTO_INDEX)
        self.serial.write(str(index).encode())

        for _ in range(self.num_bytes):
            self.serial.write(str(value & 0xff).encode())
            value >>= 8

    def read(self, index, timeout=1):
        """Read the register value at the specified index.

        :param index: int, register index
        :param timeout: int, read timeout (seconds), defaults to 1
        :return: read value
        :rtype: int
        """
        self.serial.write(UartRegIf.PROTO_INDEX)
        self.serial.write(str(index).encode())

        value = 0
        for num in range(self.num_bytes):
            try:
                value += ord(self.serial.read(timeout)) << num*8
            except TypeError:
                print('read timeout!', file=sys.stderr)
                return None

        return value


def get_uarts():
    """Return available UART interface."""
    for info in comports(False):
        port, _, _ = info
        yield port


def main():
    """Main entry point."""

    try:
        uarts = list(get_uarts())
        default_uart = uarts[0]
    except IndexError:
        default_uart = None

    parser = argparse.ArgumentParser(formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument('-s', '--speed', type=int, default=115200,
                        help='Serial speed (in baud)')

    parser.add_argument('-t', '--tty', type=str, default=default_uart,
                        help='tty to use')

    parser.add_argument('-n', '--bytes', dest='num_bytes', type=int, default=4,
                        help='Number of bytes per registers')

    parser.add_argument('-i', '--index', type=int, required=True,
                        help='Register to select')

    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument('-w', '--write', type=int, help='Value to write')
    action.add_argument('-r', '--read', action='store_true')

    args = parser.parse_args()

    if not uarts:
        print('no uart available, exiting...', file=sys.stderr)
        exit(1)

    uart = UartRegIf(args.tty, args.speed, num_bytes=args.num_bytes)

    if args.write:
        uart.write(args.index, args.write)
    else:
        value = uart.read(args.index)
        if not value:
            exit(1)



if __name__ == '__main__':
    main()
