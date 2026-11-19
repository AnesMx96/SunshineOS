# Ukrainian translations for the sunshine-* tools

## What I did

I found every user-facing English string that the listed scripts look up through
`loc` / `t` (including strings passed to `sec`, `say`, `ok` and `bad`, because those
helpers call `loc "$*"` internally) and that had no line in
`overlay/system/usr/share/sunshine/i18n/uk.tsv`.

I appended **124** new `English<TAB>Ukrainian` lines. No existing line was edited.
Translations are plain, polite Ukrainian for ordinary users; technical names
(pacman, GRUB, initramfs, NVIDIA, sudo, `fstab`, `zsh`, command names, package
names, `%command%`) are kept unchanged. Trailing colons were preserved where the
English has one. The URL/command examples were left verbatim.

Files changed:

- `overlay/system/usr/share/sunshine/i18n/uk.tsv` — 124 lines appended
  (`git diff --numstat`: 124 insertions, 0 deletions).
- `REPORT.md` — this report.

## Scope and method

Scripts inspected:

`overlay/system/usr/local/bin/sunshine-{rescue,kernel,performance,gaming,drivers,desktops,toolsync,migrate,state-hook,game-run,fix-pacman}`
and `profile/airootfs/usr/local/bin/sunshine-update-run`.

Strings were extracted statically (quoted literals passed to `loc`, `t` defaults,
and the `sec`/`say`/`ok`/`bad` wrappers). A second pass with a plain regex over all
`loc "..."` calls was used as a cross-check; after the append it reports
**0 remaining literal lookups without a line**.

Verification run:

- `awk -F'\t' 'NF!=2' overlay/system/usr/share/sunshine/i18n/uk.tsv` prints nothing.
- File has 306 lines; every line has exactly 2 fields; no empty field.
- `git diff` shows only additions at the end of the file (124 insertions, 0 deletions).
- Re-running the literal extraction finds 0 missing keys.

## Strings skipped because they are built with variables

These are passed to `loc` (directly or through `sec`/`ok`/`bad`) but contain a
runtime value, so an exact-match TSV line can never match them. They remain in
English unless the script is changed:

- `sunshine-rescue:166` — `sec "File system check ($fs)"`
- `sunshine-kernel:39` — `sec "Installing $k"`
- `sunshine-kernel:18` — `bad "grub-mkconfig failed: $(tail ...)"` (command output)
- `sunshine-kernel:60` — `bad "mkinitcpio: $(tail ...)"` (command output)
- `sunshine-desktops:41` — `bad "usage: sunshine-desktops install NAME (...)"`
- `sunshine-desktops:48` — `sec "Installing $n"`
- `sunshine-migrate:24` — `ok "$n${out:+: $out}"`
- `sunshine-migrate:25` — `bad "$n failed ($out)"`
- `sunshine-fix-pacman:28` — `ok "removed the obsolete or unstable repository [$r] (...)"`
- `sunshine-fix-pacman:31` — `ok "login lock of $u cleared"`
- `sunshine-fix-pacman:76` — `ok "$h works"`
- `sunshine-fix-pacman:78` — `bad "$h does not start (broken libalpm after an update?): reinstalling"`
- `sunshine-fix-pacman:79` — `ok "$h reinstalled"`
- `sunshine-fix-pacman:87` — `bad "$fails step(s) failed: ..."`
- `sunshine-update-run:50` — `bad "The update has a new $k but not yet a matching $n: ..."`
- `sunshine-update-run:53` — `ok "Login lock of $REAL_USER cleared (too many wrong passwords earlier)"`
- `sunshine-update-run:67` — `ok "${target%%:*} mirrors ranked"`
- `sunshine-update-run:68` — `bad "could not rank the ${target%%:*} mirrors: keeping the current list"`

Generic pass-through helpers are also dynamic by design: `bad "$*"` in
`sunshine-rescue` (lines 24 and 104), `sunshine-toolsync:17` and
`sunshine-fix-pacman:10`.

Note: statements that merely combine an already-translated `loc "..."` with a
value (for example `ok "$k $(loc "removed")"` or
`ok "$(loc "mounted at") $M (...)"`) are not separate lookup keys. Their literal
part is translated through the new lines, so they do not need entries.

## Not translated because those strings never go through loc

Out of scope for this task, listed so nobody mistakes them for translated UI:

- `sunshine-game-run` has no `loc`/`t` calls at all.
- `sunshine-state-hook:14` prints its warning with plain `echo` (English).
- `sunshine-update-run:42` (`$n package update(s) available.`),
  `:104` (kernel-updated notice) and `finish()` use plain `echo`/`printf`/`read`.
  The `Press Enter to close this window.` prompt already has a TSV line but is not
  looked up by `loc`.
- `sunshine-kernel` usage messages (`usage: sunshine-kernel ...`) are plain `echo`.

## What the senior developer must decide

1. **Mirror copy is now out of date.** `profile/airootfs/usr/share/sunshine/i18n/uk.tsv`
   was byte-identical to the overlay file before my change; I changed only
   `overlay/system/...` because the task said not to change anything else. As a
   result `test/static.sh`'s drift check (line 33) will flag this file. Decide
   whether to sync it in this branch (`cp -a overlay/system/. profile/airootfs/`)
   or in a separate sync commit.

2. **`sunshine-fix-pacman:86` bypasses `loc`.** It does
   `printf '%s\n' "$(t repair_done 'Done. Try the update again.')"`. `t` only looks
   up a key named `repair_done` (not the English sentence), so the English default
   is printed verbatim even though `Done. Try the update again.` exists in `uk.tsv`.
   Fixing it needs a script change (use `loc` or an `ok` call); I did not touch the
   script.

3. **Identity entries.** To satisfy "every string has a line", I added
   `fstab → fstab`, `pacman.conf → pacman.conf`, `multilib → multilib` and
   `ananicy-cpp → ananicy-cpp`. They are harmless (the fallback would show the same
   text); remove them if you prefer to keep only real translations.

4. **Pre-existing duplicate key.** `Kernel and initramfs` appears twice in the
   original file (lines 61 and 151, identical values). I left both untouched as
   instructed; it can be de-duplicated in a separate cleanup.

5. **Wildcard key.** `Config updates waiting for review (*.pacnew):` contains `*`.
   `loc` checks exact keys first, so this string works, but the key also joins the
   prefix-matching loop in `ui.sh`. The prefix is specific enough to be safe; only
   relevant if you want to avoid `*` in keys altogether.

6. **Typography.** New lines use the ASCII apostrophe (`'`) already used in several
   existing entries, e.g. `Перевірка здоров'я`; no other style changes were made.
