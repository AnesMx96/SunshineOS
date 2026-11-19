# Team tasks (night run 2026-11-19, until 12:00)

Maintained by the senior developer only. Agents: work in your own git worktree and branch, append to your own `docs/team/log/<agent>.md`
(real `date` timestamps; what you did, what failed, evidence paths), put research in `docs/team/research/<agent>-*.md` and reports in
`docs/team/reports/`. Never edit another agent's files. The senior developer merges branches into `main`.

| id | task | owner | status | branch |
|----|------|-------|--------|--------|
| T1 | Core tools: rescue, kernel, performance, gaming, drivers, desktops, toolsync, migrate, pacnew, reset-plasma | senior | done (testing in VMs next) | team/night-run |
| T2 | sunshine-tools repository + signed sync | senior | done | team/night-run |
| T3 | Fast ISO build, real install test, break-and-repair, performance numbers | senior | building ISO | team/night-run |
| T4 | Shellcheck pass over the new tools | opencode lint | merged | agent/lint |
| T5 | Ukrainian strings for the new tools | opencode translate | merged | agent/translate |
| T6 | docs/TOOLS.md user guide | opencode docs | running | agent/docs |
| T7 | Comparison of EndeavourOS / Garuda / CachyOS tools vs Sunshine OS | opencode compare | running | agent/compare |
| T8 | break-repair harness (test/break-repair.sh, test/break/*.sh) | tak-7a | in progress | agent/tak-7a |
| T9 | Research notes per breakage scenario | tak-7a | in progress | agent/tak-7a |
| T10 | Compare Gemini/Grok/ChatGPT answers to the same design prompt | senior + opencode | done: docs/team/research/ai-comparison.md (Gemini was not logged in) | team/night-run |
| T11 | fastfetch/hyfetch logo PRs | tak-7a | waiting for the stable Sol release | agent/tak-7a |
| T12 | Safety review of the new tools (A), Ukrainian README (B), later final ISO build on the desktop PC (C) | newcomer (name tbd, other PC) | assigned: docs/team/inbox/senior-to-newcomer.md | agent/<name> |
| T13 | Desktops group in the installer catalogue; weekly health scan | senior | done (needs repo rebuild) | team/night-run |
