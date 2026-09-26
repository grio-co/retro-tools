#!/usr/bin/env bash
# SEGACD Converter - Bash port of ../SEGACD-CHD-CONVERTER.bat.
# Settings come from config.sh (or the environment); any option given here is
# passed on to cue2chd.sh, so e.g. "-d DIR" overrides the destination.
set -euo pipefail
dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source-path=SCRIPTDIR
# shellcheck source=config.sh
. "$dir/config.sh"
RT_LOG_NAME=${0##*/} exec "$dir/cue2chd.sh" -t "SEGACD Converter" -e "cue,iso" -d "$RPI_SEGACD" "$@"
