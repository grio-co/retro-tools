#!/usr/bin/env bash
# cue2chd.sh - convert disc images to .chd with "chdman createcd".
#
# Bash port of the Windows *-to-CHD.bat converters in the repo root. The
# per-system wrappers next to this file (DC-CUE-or-GDI-to-CHD.sh,
# PSX-CUE-to-CHD.sh, PCECD-CUE-to-CHD.sh, SEGACD-CHD-CONVERTER.sh) call it
# with the right input extensions and destination; it can also be run directly.
#
# For every matching image under ROMDIR (recursively) it will:
#   1. skip the image if <dest>/<name>.chd already exists,
#   2. otherwise run  chdman createcd -i <image> -o <image dir>/<name>.chd --force
#   3. move the .chd to the destination folder (when one is given).
# Archives (.7z/.zip/.rar) are extracted next to themselves first (with 7z);
# the extracted files are deleted once every image inside the archive has been
# converted and copied successfully (pass -k to keep them).
#
# Requires bash 4.4+, chdman (from MAME) and, for archives, 7z/7za/7zr.
set -euo pipefail

VERSION=0.1.0
SCRIPT_NAME=${0##*/}
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DEFAULT_EXTS=cue,gdi,iso

DEST=
EXTS=$DEFAULT_EXTS
TITLE="Disc image to .chd"
ASSUME_YES=0
KEEP_EXTRACTED=0
DRY_RUN=0
LOG_DIR=${RT_LOG_DIR:-$SCRIPT_DIR/../logs}
LOG_NAME=${RT_LOG_NAME:-$SCRIPT_NAME}
LOG=
CHDMAN=${CHDMAN:-}
SEVENZIP=${SEVENZIP:-}

usage() {
	cat <<USAGE
Usage: $SCRIPT_NAME [options] ROMDIR

Convert every disc image under ROMDIR (recursively) to a .chd with
"chdman createcd". Archives (.7z/.zip/.rar) are extracted first with 7z.

Options:
  -d DEST    folder to move finished .chd files to (e.g. a mounted RetroPie
             roms share). Without it the .chd stays next to its source image.
  -e EXTS    comma-separated input extensions (default: $DEFAULT_EXTS)
  -t TITLE   title shown in the banner and at the top of the log
  -y         don't ask "(c)onvert or e(x)it" before starting
  -k         keep files extracted from archives after a successful conversion
  -n         dry run: print the chdman/7z/mv commands instead of running them
  -h         show this help

Environment:
  CHDMAN      chdman binary (default: the first "chdman" on \$PATH)
  SEVENZIP    7z binary (default: 7z, 7za or 7zr on \$PATH)
  RT_LOG_DIR  folder for run logs (default: $SCRIPT_DIR/../logs)
  RT_LOG_NAME base name of the log file (default: $SCRIPT_NAME)

Example:
  $SCRIPT_NAME -e cue,gdi -d /mnt/retropie/roms/dreamcast ~/roms/dreamcast
USAGE
}

die() {
	printf '%s: %s\n' "$SCRIPT_NAME" "$*" >&2
	exit 1
}

# log LEVEL MESSAGE - append to the run log (same line format as the batch
# scripts) and echo to the screen.
log() {
	local level=$1
	shift
	printf '%s - [%s] - %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$*" >>"$LOG"
	if [[ $level == ERROR ]]; then
		printf '[%s] %s\n' "$level" "$*" >&2
	else
		printf '%s\n' "$*"
	fi
}

# run CMD ARGS... - run a command, or only print it with -n.
run() {
	if ((DRY_RUN)); then
		{
			printf '+'
			printf ' %q' "$@"
			printf '\n'
		} >&2
		return 0
	fi
	"$@"
}

# find_tool VAR NAME... - print the tool to use: $VAR if set (must be
# executable), else the first NAME found on $PATH.
find_tool() {
	local var=$1 name
	shift
	if [[ -n ${!var:-} ]]; then
		command -v "${!var}" >/dev/null 2>&1 || die "$var=${!var} is not an executable"
		printf '%s\n' "${!var}"
		return 0
	fi
	for name in "$@"; do
		if command -v "$name" >/dev/null 2>&1; then
			printf '%s\n' "$name"
			return 0
		fi
	done
	return 1
}

# matches_ext PATH - true if PATH ends in one of the -e extensions.
matches_ext() {
	local ext=${1##*.} e
	[[ $ext != "$1" ]] || return 1
	for e in "${EXT_LIST[@]}"; do
		[[ ${ext,,} == "${e,,}" ]] && return 0
	done
	return 1
}

banner() {
	local rule
	rule=$(printf '%103s' '' | tr ' ' '-')
	printf '%s\n%s\n' "$rule" "$rule"
	printf -- '-- retro-tools v.%s\n-- %s\n-- http://grio.net\n-- Logs: %s\n' "$VERSION" "$TITLE" "$LOG"
	printf '%s\n%s\n' "$rule" "$rule"
}

# convert_image IMAGE - createcd IMAGE into <dir>/<name>.chd, then move it to
# DEST. Returns non-zero on any failure (the run carries on with the next file).
convert_image() {
	local src=$1 name dir out final
	name=${src##*/}
	name=${name%.*}
	dir=${src%/*}
	out=$dir/$name.chd
	final=${DEST:-$dir}/$name.chd

	if [[ -e $final ]]; then
		log INFO "$name.chd available in ${DEST:-$dir} - skipping $src"
		SKIPPED=$((SKIPPED + 1))
		return 0
	fi

	log INFO "Converting $src"
	if ! run "$CHDMAN" createcd -i "$src" -o "$out" --force; then
		log ERROR "chdman createcd failed: $src"
		return 1
	fi

	if [[ -n $DEST ]]; then
		printf 'Copying %s.chd to %s\n' "$name" "$DEST"
		run mv -f -- "$out" "$DEST/" || true
		if ((DRY_RUN)) || [[ -e $final ]]; then
			log INFO "Copied $name.chd to $DEST"
		else
			log ERROR "Copy failed: $name.chd to $DEST"
			return 1
		fi
	fi
	CONVERTED=$((CONVERTED + 1))
}

# process_archive ARCHIVE - extract ARCHIVE next to itself, convert the images
# it contained, and delete the extracted files once all of them succeeded.
process_archive() {
	local archive=$1 name dir entry
	local -a entries=() extracted=() images=()
	name=${archive##*/}
	name=${name%.*}
	dir=${archive%/*}

	if [[ -e ${DEST:-$dir}/$name.chd ]]; then
		log INFO "$name.chd available in ${DEST:-$dir} - skipping $archive"
		SKIPPED=$((SKIPPED + 1))
		return 0
	fi
	if [[ -z $SEVENZIP ]]; then
		log ERROR "7z not found on \$PATH - cannot extract $archive (set SEVENZIP=/path/to/7z)"
		return 1
	fi

	# List the contents first so only what came out of the archive is deleted
	# afterwards. -slt prints "Path = ..." for the archive itself before the
	# "----------" separator and for each entry after it.
	mapfile -t entries < <("$SEVENZIP" l -slt -- "$archive" | awk '/^----------$/ { body = 1; next } body && /^Path = / { print substr($0, 8) }')

	log INFO "Extracting $archive"
	if ! run "$SEVENZIP" x -y -o"$dir" -- "$archive" >/dev/null; then
		log ERROR "Extraction failed: $archive"
		return 1
	fi
	for entry in "${entries[@]}"; do
		((DRY_RUN)) || [[ -f $dir/$entry ]] || continue
		extracted+=("$dir/$entry")
		matches_ext "$entry" && images+=("$dir/$entry")
	done
	if ((${#images[@]} == 0)); then
		log ERROR "No .$EXTS image found inside $archive"
		return 1
	fi

	local ok=1 img f
	for img in "${images[@]}"; do
		convert_image "$img" || ok=0
	done
	if ((ok && !KEEP_EXTRACTED && !DRY_RUN)); then
		for f in "${extracted[@]}"; do
			rm -f -- "$f"
			log INFO "Deleted $f"
		done
	fi
	((ok))
}

main() {
	local opt answer count find_args=() ext
	((BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 4))) || die "bash 4.4 or newer is required"

	while getopts ':d:e:t:yknh' opt; do
		case $opt in
			d) DEST=$OPTARG ;;
			e) EXTS=$OPTARG ;;
			t) TITLE=$OPTARG ;;
			y) ASSUME_YES=1 ;;
			k) KEEP_EXTRACTED=1 ;;
			n) DRY_RUN=1 ;;
			h) usage; exit 0 ;;
			:) die "option -$OPTARG needs an argument (see -h)" ;;
			*) die "unknown option -$OPTARG (see -h)" ;;
		esac
	done
	shift $((OPTIND - 1))
	if (($# != 1)); then
		printf -- '-- Missing folder for conversion. Exiting...\n\n' >&2
		usage >&2
		exit 2
	fi
	ROMDIR=$1
	[[ -d $ROMDIR ]] || die "ROM folder not found: $ROMDIR"
	[[ $ROMDIR == / ]] || ROMDIR=${ROMDIR%/}
	if [[ -n $DEST ]]; then
		[[ -d $DEST ]] || die "destination folder not found: $DEST"
		[[ $DEST == / ]] || DEST=${DEST%/}
	fi

	IFS=, read -r -a EXT_LIST <<<"$EXTS"
	((${#EXT_LIST[@]} > 0)) || die "-e needs at least one extension"
	for ext in "${EXT_LIST[@]}"; do
		ext=${ext#.}
		[[ -n $ext ]] || die "empty extension in -e $EXTS"
		((${#find_args[@]} == 0)) || find_args+=(-o)
		find_args+=(-iname "*.$ext")
	done

	CHDMAN=$(find_tool CHDMAN chdman) || die "chdman not found on \$PATH - install it (it ships with MAME) or set CHDMAN=/path/to/chdman"
	SEVENZIP=$(find_tool SEVENZIP 7z 7za 7zr) || SEVENZIP=

	mkdir -p "$LOG_DIR"
	count=$(find "$LOG_DIR" -maxdepth 1 -name "$LOG_NAME-*.log" | wc -l)
	LOG=$LOG_DIR/$LOG_NAME-$((count % 5)).log
	printf 'retro-tools v.%s %s - %s:\n' "$VERSION" "$TITLE" "$(date)" >"$LOG"

	banner
	printf -- '-- ROMs location - [%s]\n' "$ROMDIR"
	[[ -n $DEST ]] && printf -- '-- Destination   - [%s]\n' "$DEST"
	printf -- '-- chdman        - [%s]\n' "$CHDMAN"
	if ((!ASSUME_YES)); then
		read -r -p '-- (c)onvert or e(x)it: ' answer
		[[ $answer == c ]] || exit 0
	fi

	CONVERTED=0
	SKIPPED=0
	FAILED=0
	local path

	# Compressed files first (like the batch scripts), then plain images.
	while IFS= read -r -d '' path; do
		process_archive "$path" || FAILED=$((FAILED + 1))
	done < <(find "$ROMDIR" -type f \( -iname '*.7z' -o -iname '*.zip' -o -iname '*.rar' \) -print0 | sort -z)

	while IFS= read -r -d '' path; do
		convert_image "$path" || FAILED=$((FAILED + 1))
	done < <(find "$ROMDIR" -type f \( "${find_args[@]}" \) -print0 | sort -z)

	log INFO "Done: $CONVERTED converted, $SKIPPED already present, $FAILED failed"
	((FAILED == 0))
}

main "$@"
