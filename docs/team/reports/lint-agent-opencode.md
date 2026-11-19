# Shellcheck cleanup report

## What I did

Ran `shellcheck -S warning` (ShellCheck 0.11.0) on the 12 requested scripts, fixed the
warnings that were real problems or that were intentional code needing an explicit
directive, then re-ran `bash -n` and `shellcheck -S warning` on every file.

Initial warnings found:

- `sunshine-rescue`: SC2034 (unused fallback colour `R`, unused local `kv`), SC1090
  (runtime `source` of a discovered `os-release`).
- `sunshine-kernel`: SC2034 (unused fallback colours `G`, `R`), SC2046 (optional
  `-headers` package in `pacman -Rns`).
- `sunshine-performance`: SC2034 (unused `mem_gb`), SC2046 (optional
  `cachyos-ananicy-rules` package).
- `sunshine-drivers`: SC2034 (unused fallback colour `R`, unused `pre`).
- `sunshine-desktops`: SC2034 (unused fallback colour `R`).
- `sunshine-toolsync`: SC2034 (unused fallback colours `Y`, `G`, `R`, `B`, `N`).
- `sunshine-update-run`: SC2034 (unused fallback colours `G`, `R`).
- `sunshine-gaming`, `sunshine-migrate`, `sunshine-state-hook`, `sunshine-game-run`,
  `sunshine-doctor`: no warnings at `-S warning`.

There were no real unquoted-variable, unset-variable, wrong-test, useless-cat, or
masked-return-value bugs in these files. The remaining unquoted expansions are
deliberate word splitting of package lists or optional package arguments; see the
"Senior decisions" section.

## Files changed

All paths are relative to the worktree root.

### `overlay/system/usr/local/bin/sunshine-rescue`
- Added `# shellcheck disable=SC2034` with a one-line reason above the fallback
  `ui.sh` loading line: the fallback colour names intentionally mirror `ui.sh`.
- Added `# shellcheck disable=SC1090` above the btrfs subvolume `os-release` source:
  the path is discovered at runtime and cannot be checked statically.
- Removed the unused local `kv` (`local k kv base any=0` -> `local k base any=0`).
  It had no side effects and was never read.

### `overlay/system/usr/local/bin/sunshine-kernel`
- Added `# shellcheck disable=SC2034` with a one-line reason above the fallback
  colour definitions.
- Added `# shellcheck disable=SC2046` above `pacman -Rns`: the command substitution
  must expand to zero arguments when the optional `$k-headers` package is not
  installed, so quoting it would pass an empty package name and break the command.

### `overlay/system/usr/local/bin/sunshine-performance`
- Removed the unused `mem_gb` assignment (its `awk` read of `/proc/meminfo` was
  never used anywhere in the script).
- Added `# shellcheck disable=SC2046` above the `ananicy-cpp` install: the
  substitution must expand to zero or one package (`cachyos-ananicy-rules`).

### `overlay/system/usr/local/bin/sunshine-drivers`
- Added `# shellcheck disable=SC2034` with a one-line reason above the fallback
  colour definitions.
- Removed the unused `pre` variable (`pre=0` and both `pre=1` assignments). The
  `dk` flag already controls whether `nvidia-open-dkms` is emitted; behaviour is
  unchanged.

### `overlay/system/usr/local/bin/sunshine-desktops`
- Added `# shellcheck disable=SC2034` with a one-line reason above the fallback
  colour definitions.

### `overlay/system/usr/local/bin/sunshine-toolsync`
- Added `# shellcheck disable=SC2034` with a one-line reason above the fallback
  colour definitions.

### `profile/airootfs/usr/local/bin/sunshine-update-run`
- Added `# shellcheck disable=SC2034` with a one-line reason above the fallback
  colour definitions.
- Added the missing `loc()` and `t()` fallback functions next to the existing
  `say/ok/bad` fallbacks. This was not a ShellCheck warning, but without them the
  script calls undefined commands when `/usr/local/lib/sunshine/ui.sh` is missing
  (lines using `loc` and `t` would print "command not found"). The normal path
  with `ui.sh` present is unchanged.

### Profile copies
- Ran `cp -a overlay/system/. profile/airootfs/` after editing. The ten scripts
  that exist in both trees are byte-identical again.

## Verification

Per-file results after the edits:

```
OK  overlay/system/usr/local/bin/sunshine-rescue
OK  overlay/system/usr/local/bin/sunshine-kernel
OK  overlay/system/usr/local/bin/sunshine-performance
OK  overlay/system/usr/local/bin/sunshine-gaming
OK  overlay/system/usr/local/bin/sunshine-drivers
OK  overlay/system/usr/local/bin/sunshine-desktops
OK  overlay/system/usr/local/bin/sunshine-toolsync
OK  overlay/system/usr/local/bin/sunshine-migrate
OK  overlay/system/usr/local/bin/sunshine-state-hook
OK  overlay/system/usr/local/bin/sunshine-game-run
OK  profile/airootfs/usr/local/bin/sunshine-update-run
OK  profile/airootfs/usr/local/bin/sunshine-doctor
```

`bash -n` passed for all 12 files, and `shellcheck -S warning` produced no output
for all 12 files.

`test/static.sh` ran to completion and ended with:

```
static checks passed
```

This includes the "copies of the same file agree" check. The environment had all
tools the static checks needed (Python 3, PyQt6, Git, ShellCheck); nothing was
skipped for missing tools.

## What I could not do

- I did not execute the scripts' real repair/install/update paths: they require
  root, package-manager/network access, block devices, or an installed target
  system, and the task forbids package/network/system changes. Verification was
  limited to syntax, ShellCheck, source comparison, and the existing static suite.
- I did not run an ISO build or VM test (out of scope and forbidden).

## Senior decisions

1. **Remaining info-level SC2086 warnings were left intentionally.** Running
   plain `shellcheck` (not `-S warning`) still reports SC2086 on:
   `sunshine-kernel` `$hdr`, `sunshine-gaming` `$pk`, `sunshine-desktops`
   `${PKG[$n]}` and the session glob, `sunshine-toolsync` `/$path` in a message,
   `sunshine-update-run` `echo $orph | wc -w`, and `sunshine-doctor`
   `$core_missing`.

   These are package lists or optional arguments whose word splitting is required;
   quoting them would pass one argument containing spaces and break the command.
   I did not add disables because they are info-level only and not real bugs. If
   you want default-severity ShellCheck clean, they should be converted to arrays
   (package list cases) or given reasoned `SC2086` disables. That is a larger
   refactor and I left it for a deliberate decision.

2. **Fallback colour palette (`SC2034`).** I chose disables rather than deleting
   individual unused colour assignments, because the fallback block is a shared
   palette mirroring `ui.sh`. If you prefer no ShellCheck directives at all, the
   unused names could be removed from each fallback instead; that is safe today
   but makes the fallback diverge from the `ui.sh` palette.

3. **`sunshine-update-run` fallback fix.** I added `loc`/`t` to the fallback
   because that path is genuinely broken without `ui.sh`. Please confirm you want
   that hardening; it is the only change not driven by a ShellCheck warning.

4. **`sunshine-state-hook` / `sunshine-doctor` / `sunshine-rescue` use
   `base=$(cat "$kd/pkgbase")`.** ShellCheck does not flag this and it is not a
   behavioural bug, so I left it alone per the "minimal changes" instruction. It
   could be changed to `base=$(<"$kd/pkgbase")` in a separate style cleanup if
   desired.
