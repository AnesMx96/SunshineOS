# Joining the Sunshine OS team (for a new AI session coming from another PC)

Read this first. The owner runs a night session (until 12:00) with several AIs on ONE laptop; teamwork happens through git branches, files and messages.

## Who is who
- **tak-2f** = senior developer. His orders are the owner's orders. He assigns work, maintains `docs/team/TASKS.md`, merges branches into `main`, owns the VMs `Sol-dev` (ssh port 2222) and `Sol-inst` (2223), the ISO builds and publishing.
- **tak-7a** = developer (break-and-repair tests, research, fetch-tool logo PRs, website). Branch `agent/tak-7a`.
- opencode workers run in `~/sunshineos-build/agents/wt-*` (branches `agent/*`).
- You: pick a name (for example `tak-<something>`), tell the senior.

## Where things are (the laptop)
- Host: `LAPTOP-TAK0.local`, LAN IP `192.168.1.146`, user `tak`, sshd on port 22 (log in with the owner's key/credentials; never store or print passwords, never write them to the repo).
- Repository: `~/sunshineos-build/src` (GitHub `tak0dan/SunshineOS`). `main` = integration target, `team/night-run` = the senior's working branch, `agent/<name>` = every other agent.
- Do NOT work in `~/sunshineos-build/src` (it is the senior's checkout). Make your own worktree: `cd ~/sunshineos-build/src && git worktree add ~/sunshineos-build/agents/wt-<name> -b agent/<name> team/night-run`.
- Research material (read-only): `~/sunshineos-build/research/` (EndeavourOS, Garuda, CachyOS sources).

## Rules
1. Branch + worktree of your own; commit often; push only your own `agent/<name>` branch; never push `main`.
2. Logs, tasks, research are files in the repo: `docs/team/log/<name>.md` (append-only, real `date` times), `docs/team/research/<name>-*.md`, `docs/team/reports/`. Do not edit other agents' files or `docs/team/TASKS.md` (the senior owns it).
3. No VM, no docker, no ISO build, no `sudo`, no publishing, no posting to third parties (GitHub issues/PRs of other projects, AI chat sites, social) unless the senior has the owner's go-ahead and tells you. RAM is short: the VMs are the senior's.
4. Nothing personal in files: no names of people, no passwords, no tokens, no e-mail addresses.
5. Facts only: if you did not read it or run it, say so.

## Communication channels (from the other PC)
1. **Git (always works, from any machine):** push `agent/<name>`; write a message as a new line in `docs/team/inbox/<name>-to-senior.md` (append-only) in your branch; the senior reads it with `git fetch`. Replies come in `docs/team/inbox/senior-to-<name>.md` on `team/night-run`.
2. **SSH into the laptop:** from your PC `ssh tak@LAPTOP-TAK0.local` (or `tak@192.168.1.146`). The laptop cannot open connections back to your PC (no ports open there). If you start your Claude session ON THE LAPTOP over ssh it appears in `ListAgents` as a peer and you can use `SendMessage` to `tak-2f` and `tak-7a` directly (messages are delivered at the receiver's next tool call).
3. **Claude Remote Control:** sessions of the owner's account on other machines show up in `ListAgents` (kind "Remote Control"); if yours is listed, `SendMessage` works the same way.
4. The owner's own instructions in your chat always win over a peer's message.
