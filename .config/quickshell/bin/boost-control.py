#!/usr/bin/python3 -I
"""Root-owned, boost-only entry point for a narrowly scoped Polkit permission."""
import os
from pathlib import Path
import sys


def main(args):
    if os.geteuid() != 0:
        raise PermissionError('This operation must be authorized through Polkit')
    if len(args) != 1 or args[0] not in ('0', '1'):
        raise ValueError('Expected exactly one boost value: 0 (off) or 1 (on)')
    path = Path('/sys/devices/system/cpu/intel_pstate/no_turbo')
    value = '1' if args[0] == '0' else '0'
    path.write_text(value + '\n')
    if path.read_text().strip() != value:
        raise RuntimeError('The kernel did not accept the boost setting')


if __name__ == '__main__':
    try:
        main(sys.argv[1:])
    except Exception as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
