# retro-tools

A small toolkit of Windows batch scripts for managing the piles of files you
collect when building a [RetroPie](https://retropie.org.uk/). It converts disc
images to space-saving `.chd` files, copies them straight to your Pi over the
network, verifies your BIOS files against known-good checksums, and fixes up
PC Engine CD audio tracks.

> **Foreword** — This started as a way to keep my Playstation 1 ROMs straight
> and to check whether my BIOS files were legitimate. It grew from there. It's
> a hobby project and my first real attempt at sharing code, so be kind. Issues
> and PRs are welcome.

---

## What it does

| Script | Purpose |
|--------|---------|
| `bin\RT-Retrieve-Tools.bat` | One-time setup. Downloads the external tools the other scripts need (`chdman`, `ffmpeg`, `7-Zip`, `crc32`, `md5`, `psftp`, `wget`). |
| `RT-BIOS-CHECKER.bat` | Walks your Pi's `bios` share and checks each file's CRC32/MD5 against a built-in table of known-good BIOS hashes. |
| `DC-CUE-or-GDI-to-CHD.bat` | Converts Dreamcast `.cue`/`.gdi` images to `.chd` and copies them to the Pi. |
| `PSX-CUE-to-CHD.bat` | Same, for Playstation 1 `.cue`/`.bin`/`.iso`. |
| `PCECD-CUE-to-CHD.bat` | Same, for PC Engine CD / TurboGrafx-16 CD. |
| `SEGACD-CHD-CONVERTER.bat` | Same, for Sega CD / Mega CD. |
| `PCECD-APE-to-WAV.bat` | Converts `.ape` audio tracks back to `.wav` so PC Engine CD images become playable (and `.chd`-compressible). |

There are also two helper scripts under `Bash/` meant to run **on the Pi
itself**, not on Windows (see [Bash helpers](#bash-helpers)).

---

## Requirements

- **Windows** (uses `cmd` batch + a few bundled `.exe` tools). Tested on Windows 10/11.
- **7-Zip** installed at `C:\Program Files\7-Zip\` (the setup script can install it for you).
- A **RetroPie** on your network with the **Samba/SMB** shares enabled (the
  optional `Samba ROM Service` package in `retropie-setup`), reachable as
  `\\<pi-ip>\roms\...` and `\\<pi-ip>\bios`.
- Network access to the Pi as the `pi` user (default RetroPie SMB setup).

This has only been tested with a Pi exposing its shares over SMB. Other setups
may work but aren't supported.

---

## Setup

### 1. Configure your variables

Open [`conf/config.bat`](conf/config.bat) and set the values for your setup,
then **save**:

```bat
set rpi=R:                          :: drive letter you've mapped the Pi to (optional)
set rpiip=10.0.0.20                 :: your Pi's IP address
set rpibios="\\%rpiip%\bios"        :: BIOS share (used by the BIOS checker)
set rpidc="\\%rpiip%\roms\dreamcast"
set rpipsx="\\%rpiip%\roms\psx"
set rpipce="\\%rpiip%\roms\pcengine"
set rpisegacd="\\%rpiip%\roms\segacd"
```

`rpiip` and the share paths are what actually matter — the converters write
their output to those UNC paths. The `rpiusername` / `rpipassword` entries are
currently **unused** by the scripts (they rely on your existing network
access), so don't put real credentials there.

### 2. Download the tools

From the repo root, run the retriever:

```bat
cd bin
RT-Retrieve-Tools.bat
```

This fetches everything the other scripts depend on and drops the `.exe` tools
into place, plus it creates a `logs\` folder. The downloaded binaries are
git-ignored, so they never get committed.

> **Note:** Download sources go stale over time (a previous host, Zeranoe, shut
> down entirely). If a download fails, check the URLs in
> [`bin/RT-Retrieve-Tools.bat`](bin/RT-Retrieve-Tools.bat). On modern Windows
> you can also use the built-in `curl.exe` and `certutil -hashfile` instead of
> the bundled `wget`/`md5` tools.

---

## Usage

### BIOS checker

```bat
RT-BIOS-CHECKER.bat
```

No arguments. It walks `%rpibios%`, computes the CRC32 and MD5 of every file,
and matches them against the table in
[`conf/bios-checksums.bat`](conf/bios-checksums.bat) (sourced from the official
RetroPie BIOS documentation). Results are printed and written to
`logs/RT-BIOS-CHECKER.bat-*.log`.

- A **CRC32/MD5 match** confirms the file is a known-good BIOS.
- A **filename-only match** (`[WARN]`) means the name is right but the contents
  don't match any known hash — verify that file. If you're confident a file is
  correct, the log tells you how to send the details so the table can be
  improved.

### Disc-image → CHD converters

Each converter takes the folder of ROMs to process as its **first argument**.
Quote the path if it has spaces:

```bat
PSX-CUE-to-CHD.bat "D:\roms\psx"
DC-CUE-or-GDI-to-CHD.bat "D:\roms\dreamcast"
PCECD-CUE-to-CHD.bat "D:\roms\pcengine"
SEGACD-CHD-CONVERTER.bat "D:\roms\segacd"
```

When you run one, it asks `(c)onvert or e(x)it`. On convert, the script will,
for every disc image under the folder (recursively):

1. **Skip** it if a matching `.chd` already exists on the Pi (logged as `[INFO]`).
2. Otherwise **extract** any `.7z`/`.zip`/`.rar` archive first (via 7-Zip).
3. **Compress** the `.cue`/`.gdi`/`.bin`/`.iso` set into a single `.chd` with `chdman`.
4. **Copy** the `.chd` to the matching Pi share and verify it landed
   (`[INFO]` on success, `[ERROR]` on failure).
5. **Only after a verified copy**, delete the now-redundant extracted source
   files. (A failed copy leaves your originals untouched.)

Everything is mirrored to `logs/<script-name>-*.log`.

### PC Engine CD: APE → WAV

Some PC Engine CD / TurboGrafx-16 rips ship with their audio tracks encoded as
`.ape` even though the `.cue` references `.wav`. That makes them unplayable and
un-`chd`-able until fixed:

```bat
PCECD-APE-to-WAV.bat "D:\roms\pcengine"
```

Menu options:

- **(c)onvert** — finds every `.ape` and writes a sibling `.wav` (via `ffmpeg`),
  skipping any that already have one.
- **(d)elete .wavs** — removes the generated `.wav` files (e.g. to redo a batch).
- **(x)it** — quit.

Run **convert** first, then run the matching `*-CUE-to-CHD` converter on the
same folder to produce the final `.chd`.

---

## How it's organized

```
retro-tools/
├─ RT-BIOS-CHECKER.bat        ┐
├─ DC-CUE-or-GDI-to-CHD.bat   │  user-facing scripts (run these)
├─ PSX-CUE-to-CHD.bat         │
├─ PCECD-CUE-to-CHD.bat       │
├─ SEGACD-CHD-CONVERTER.bat   │
├─ PCECD-APE-to-WAV.bat       ┘
├─ bin/
│  ├─ RT-Retrieve-Tools.bat   one-time tool downloader
│  └─ (downloaded .exe tools live here, git-ignored)
├─ conf/
│  ├─ config.bat              your settings (edit this)
│  ├─ bios-checksums.bat      known-good BIOS hash table
│  ├─ header.bat              prints the on-screen banner
│  └─ log.bat                 sets the rotating log filename
├─ Bash/                      helper scripts that run ON the Pi
└─ logs/                      created at setup; per-script run logs
```

Every user-facing script follows the same pattern: it `call`s `conf\config.bat`
for your settings, sets a title/description, then `call`s `conf\log.bat` (which
picks a rotating log file, 0–4) and `conf\header.bat` (the banner). Logs land in
`logs/` and rotate so they don't grow unbounded.

---

## Bash helpers

These live in [`Bash/`](Bash/) and are meant to run **on the RetroPie**, not on
Windows:

- `PCE - APE to WAV.sh` — the Linux equivalent of the APE→WAV converter, using
  `ffmpeg` and `find`.
- `RP - restart-emulationstation-from-ssh.sh` — restarts EmulationStation from
  an SSH session (`export DISPLAY=:0` then relaunch).

---

## Known limitations

- **Filenames containing `!`** are skipped by the batch converters. This is a
  `cmd` delayed-expansion limitation, not easily fixable in batch — rename the
  file to drop the `!` as a workaround. A future PowerShell port would remove
  this class of problem entirely.
- Tool **download URLs go stale** over time; see the note in [Setup](#2-download-the-tools).
- The BIOS hash table is **hand-maintained** and incomplete (many entries have
  no CRC32/MD5 yet). Contributions of verified hashes are welcome.

---

## Roadmap

- A config **wizard** to set everything up interactively.
- A single **menu-driven** entry point instead of one script per system.
- A **PowerShell** rewrite to replace the bundled download tools with built-in
  `curl`/`Get-FileHash`, get real arrays/hashtables for the BIOS table, and add
  proper error handling and `-WhatIf` dry-runs.

---

## License

<!-- PLACEHOLDER(greg): choose license -->

The README has said GPL-3.0, but the repo has no license text yet. See
[`LICENSE`](LICENSE), which is a placeholder until the license is confirmed and
its full text is added.

> If this breaks everything in your house, sets your car on fire, or kicks your
> dog, I am in no way responsible. Use at your own risk.
