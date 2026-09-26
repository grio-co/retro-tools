#!/usr/bin/env bash
# config.sh - settings for the Bash converters (the Linux equivalent of
# ../conf/config.bat). Sourced by the per-system *-to-CHD.sh wrappers.
#
# Every value can also be overridden from the environment, e.g.
#   RPI_ROMS=/mnt/retropie/roms ./PSX-CUE-to-CHD.sh ~/roms/psx

# Root of the RetroPie "roms" tree. When these scripts run on the Pi itself the
# default below is right; from another machine point it at wherever you have
# mounted the Pi's roms share (e.g. /mnt/retropie/roms).
RPI_ROMS=${RPI_ROMS:-$HOME/RetroPie/roms}

# Per-system destinations (same layout as conf/config.bat).
RPI_DC=${RPI_DC:-$RPI_ROMS/dreamcast}
RPI_PSX=${RPI_PSX:-$RPI_ROMS/psx}
RPI_PCE=${RPI_PCE:-$RPI_ROMS/pcengine}
RPI_SEGACD=${RPI_SEGACD:-$RPI_ROMS/segacd}

# Tools. Leave empty to search $PATH ("chdman"; "7z", "7za" or "7zr").
CHDMAN=${CHDMAN:-}
SEVENZIP=${SEVENZIP:-}

# Where run logs go (default: the repo's logs/ folder, like the batch scripts).
RT_LOG_DIR=${RT_LOG_DIR:-}

export RPI_ROMS RPI_DC RPI_PSX RPI_PCE RPI_SEGACD CHDMAN SEVENZIP RT_LOG_DIR
