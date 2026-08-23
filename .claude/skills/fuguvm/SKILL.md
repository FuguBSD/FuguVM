---
name: fuguvm
description:
  Drive fuguvm, the utility that installs and manages OpenBSD VMs under QEMU:
  bring a VM up or down, run commands over SSH, watch logs, and troubleshoot.
  Use when starting, debugging, or scripting an OpenBSD VM, or when a fuguvm
  command fails.
---

# Operate an OpenBSD VM

## Objective

Drive an OpenBSD VM with `bin/fuguvm`: lifecycle, ad-hoc commands, and
troubleshooting. A project defines its VMs in a `.fuguvmrc` at its root.

## Workflow

1. Bring the VM up and wait until it accepts SSH:

   ```sh
   bin/fuguvm up && bin/fuguvm wait --timeout=300
   ```

   The first `up` installs the guest without interaction and caches the
   installed disk; later runs reuse the cache.

2. Run ad-hoc commands in the VM:

   ```sh
   bin/fuguvm ssh -- uname -a
   bin/fuguvm ssh -- sh -c 'dmesg | tail -20'
   ```

3. For scripted console interaction (no SSH yet), run an expect script:

   ```sh
   bin/fuguvm expect share/fuguvm/expect/command.exp
   ```

4. Save and restore the guest state with snapshots:

   ```sh
   bin/fuguvm snapshot save <name>
   bin/fuguvm snapshot restore <name>
   ```

## Troubleshooting

- `fuguvm status` prints the VM state, `ssh_port`, and `console_port`.
- "Not in a FuguVM project" — run from the project root (the project is
  auto-discovered via `.fuguvmrc`) or pass `--project`.
- SSH failures after an unclean shutdown — `bin/fuguvm disk check`, then
  `bin/fuguvm disk repair` with the VM stopped.
- Start over from a clean slate: `bin/fuguvm destroy && bin/fuguvm up`.
  `destroy` deletes the working disk only; the next `up` rebuilds it from the
  cached installed image, so this is a cheap factory reset rather than a
  reinstall.
- To force a real reinstall — when debugging the installer itself, or when a
  cached base is suspect — use `bin/fuguvm up --no-cache`, or drop the cached
  bases with `bin/fuguvm cache clear`. `bin/fuguvm cache list` shows what is
  cached and which entry the current configuration uses.
- On aarch64 hosts without hardware acceleration, pass `--emulate`.

## References

- `fuguvm(1)` — full command, option, and exit-code reference:
  `mandoc man/fuguvm/fuguvm.1 | less`
- `bin/fuguvm help` — quick usage
