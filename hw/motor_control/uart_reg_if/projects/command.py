#!/usr/bin/env python

import argparse
import serial
from serial.tools.list_ports import comports


class UartRegIf():
    """Manage the register interface to read and write register using an
    UART interface.

    """

    PROTO_INDEX = b'S'
    PROTO_READ = b'R'
    PROTO_WRITE = b'W'

    def __init__(self, tty, speed, num_bytes=4, timeout=1):
        self.num_bytes = num_bytes
        self.serial = serial.Serial(tty, speed, timeout=timeout)

    def write(self, index, value):
        """Write value in the register at the specified index."""
        self.serial.write(UartRegIf.PROTO_INDEX)
        self.serial.write(str(index).encode())

        for _ in range(self.num_bytes):
            self.serial.write(str(value & 0xff).encode())
            value >>= 8

    def read(self, index, timeout=1):
        """Read the register value at the specified index."""
        self.serial.write(UartRegIf.PROTO_INDEX)
        self.serial.write(str(index).encode())

        value = 0
        for num in range(self.num_bytes):
            value += ord(self.serial.read(timeout)) << num*8

        return value


def get_uarts():
    """Return available UART interface."""
    for info in comports(False):
        port, _, _ = info
        yield port


def main():
    """Main entry point."""

    uarts = list(get_uarts())
    if not uarts:
        print("no uart available, exiting...")
        exit(1)

    parser = argparse.ArgumentParser(formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument('-s', '--speed', type=int, default=115200,
                        help='Serial speed (in baud)')

    parser.add_argument('-t', '--tty', type=str, default=uarts[0],
                        help='tty to use')

    args = parser.parse_args()

    uart = UartRegIf(args.tty, args.speed)
    uart.write(0, 0x55)
    print(uart.read(0))


if __name__ == '__main__':
    main()
