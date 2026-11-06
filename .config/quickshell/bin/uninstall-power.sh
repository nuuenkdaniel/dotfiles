#!/bin/sh
# Remove only the Battery feature, not the rest of this Quickshell configuration.
set -eu
source_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec python3 "$source_dir/uninstall-power.py" "$@"
