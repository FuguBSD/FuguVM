# 002 — A scriptable status, a bind address, automatic ports, and two guards

## Status

Proposed. Implements: GST-FLEET.

## Purpose

Four changes make a fleet of guests scriptable, parallel and private.

1. `fuguvm status` writes `key: value` lines to standard output. The key set is
   stable, and it gains `accel`, `bind_address` and the resolved host ports.
2. A `bind_address` directive names the host address of every forwarded port.
   The default is `127.0.0.1`.
3. The value `auto` in `ssh_port` and in `console_port` makes the tool take a
   free host port from a fixed range, and record it.
4. Two guards protect a parallel fleet: an optional `qemu_version` gate, and a
   lock around the first population of one image-cache entry.

The four changes serve one goal. A consumer declares several guests in one
`.fuguvmrc`, and starts them at the same time. It reads the real ports of each
guest from standard output. It reaches no guest from an other machine.

## Why FuguVM holds this work

A consumer must never load an `App::FuguVM` module, because a sibling
application is not a library. `fuguvm` is consumable as a tool only: its
subcommands, its output, and its exit codes. All four changes are tool-surface
changes, so FuguVM is the one repository that can hold them.

Fugu holds no part of this work. Three of the four changes are QEMU policy: a
hostfwd address, a serial listener address, and the version of one binary. The
fourth change, the free-port probe, has a Fugu pattern already, and that pattern
is a private method. `Fugu::Proxy::_find_free_port` binds each port of a range.
It returns the first port that nothing holds. A consumer cannot use the pattern
by itself, because a consumer needs the port of a guest, and only the tool knows
that port. The probe therefore stays in FuguVM, beside the QEMU command line.

## Consumers and citations

| Repo       | Unit           | Rules          | Need                                                                                                                                                      |
| ---------- | -------------- | -------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| FuguTTX    | `AGT-RUNTIME`  | AGT-RUNTIME-2  | Each forwarded guest port must bind to the loopback address of the host. A guest holds a generated root password.                                         |
| FuguTTX    | `AGT-RUNTIME`  | AGT-RUNTIME-3  | The `.fuguvmrc` names the exact qemu version of the host. The tool must refuse an other version, with exit code 3, so a `make` target stops.              |
| FuguTTX    | `AGT-FEEDBACK` | AGT-FEEDBACK-2 | Each guest takes its host ports automatically, and `fuguvm status` reports them on standard output. The repository must hold no hand-assigned port.       |
| FuguTTX    | `IAC-DEV`      | IAC-DEV-1      | One `.fuguvmrc` declares one guest for each parallel scenario. Each guest takes its host ports automatically. The guests share one read-only image cache. |
| FuguTTX    | `IAC-DEV`      | IAC-DEV-2      | Each forwarded guest port must bind to `127.0.0.1`. The host holds a public IPv4 address.                                                                 |
| FuguTTX    | `IAC-METAL`    | IAC-METAL-1    | The tool must report the `kvm` accelerator, and the bootstrap runbook records the reported value.                                                         |
| FuguTTX    | `EVL-RUNS`     | EVL-RUNS-2     | Each forwarded guest port must listen on the loopback address of the development host only.                                                               |
| FuguTTX    | `EVL-RUNS`     | EVL-RUNS-3     | The suite operates several named guests at the same time. Each guest takes its host ports automatically, and the guests share one read-only image cache.  |
| FuguOracle | `TEST-INTEROP` | TEST-INTEROP-5 | The harness must read the exit code of each `fuguvm` call.                                                                                                |
| FuguOracle | `TEST-INTEROP` | TEST-INTEROP-6 | The developer must run the harness on a private host, or must bind each forwarded guest port to the loopback address.                                     |

Every unit above exists today, and this plan opened each document and verified
each anchor. FuguOracle `TEST-INTEROP` carries the rules TEST-INTEROP-1 to
TEST-INTEROP-3 today, so TEST-INTEROP-5 and TEST-INTEROP-6 are free numbers.
FuguTTX `AGT-RUNTIME`, `AGT-FEEDBACK`, `IAC-DEV`, `IAC-METAL` and `EVL-RUNS`
carry no rule today, so every FuguTTX number above is free. The specification
edit set of this workflow adds each cited rule.

No decision blocks a consumer here. `fuguvm` is a development-host tool, like
qemu and the `scw` CLI, and a consumer loads no module from it. FuguTTX D7
therefore permits every row above.

Two facts of the consumer specifications already state the need, and both stand
today. FuguTTX `AGT-RUNTIME` states that the host must pin an exact qemu
version. FuguTTX `IAC-DEV` records one included, static public IPv4 address for
the development host.

## Scope

In scope:

- The `status` report on standard output, with a stable key set.
- One optional key argument to `status`, for one bare value.
- The `accel` key, with the value `kvm`, `hvf` or `tcg`.
- A `bind_address` directive, in a `vm` block or in the enclosing file.
- The default bind address `127.0.0.1`, which is a breaking change.
- The bind address in the hostfwd rule, in the serial listener, and in every
  address that the tool connects to.
- The value `auto` in `ssh_port` and in `console_port`.
- A free-port probe over a fixed range, with a lock and a record.
- An optional `qemu_version` directive, and exit code 3 on a mismatch.
- A lock around the first population of one image-cache entry.
- The same `key: value` contract for `fuguvm disk info`, which shares the
  printer.

Out of scope:

- A JSON form of `status`. No consumer asks for one, and a `key: value` line
  needs no parser in `sh`.
- The `arch` key of `status`. Plan 001 owns the `arch` directive, and it adds
  the key.
- The accelerator rule itself. Plan 001 owns it. This plan reports the choice.
- A port directive for the range bounds. The constants are the one home of the
  range, and no consumer asks for a second range.
- An IPv6 bind address. QEMU needs bracket syntax in a hostfwd rule, and no
  consumer asks for IPv6 today.
- A version gate on `qemu-img` or on `expect`. The directive names the QEMU
  system binary only.
- A lock around the miniroot download. `App::FuguVM::Miniroot` and the proxy
  cache hold that concern, and no consumer reports a collision there.
- A shared proxy for a fleet. Each guest starts its own proxy child today, and
  each child takes its own free port.
- The `console` verb that attaches to the serial console. Plan 003 owns it.

## Constraints that shape the design

- **The tool must not print data through the logger.** `App::FuguVM::CLI.pod`
  already states the contract: "Command data goes to standard output; a
  diagnostic goes to the logger, which writes to standard error." `cmd_status`
  breaks the contract today. `_dump_sorted` logs each line:

  ```perl
  $self->{log}->info("$key: $value");
  ```

  `Fugu::Log` in stderr mode prefixes every line with a timestamp and a level:
  `printf STDERR "[%s] %s: %s\n", $timestamp, $level_str, $message`. A script
  must therefore strip two fields to read one value. `fuguvm --quiet status`
  prints nothing at all, because `MODE_QUIET` drops every message.

- **`fuguvm snapshot list --names` is the pattern.** The method writes bare
  names with `say`. Its comment states the rule: "--names writes bare names to
  stdout, where a shell can read them." The `status` report must follow it.

- **The forwarded ports listen on every host interface today.** The QEMU command
  line carries no address:

  ```perl
  push @cmd, '-netdev', "user,id=net0,hostfwd=tcp::$ssh_port-:22";
  push @cmd, '-serial', "tcp::$console_port,server,telnet,nowait";
  ```

  The manual page states the consequence in `SECURITY CONSIDERATIONS`. The tool
  "gives QEMU the `ssh_port` and `console_port` values with no bind address", so
  both ports "listen on each host interface". The guest "permits password root
  login" with a generated password. The default must change to `127.0.0.1`. This
  is a breaking change for a caller that reaches a guest from an other machine.
  Such a caller must set `bind_address 0.0.0.0`.

- **The tool connects to its own guest.** Six places name an address today.
  `cmd_ssh`, `wait_ssh` and the installer in `up` name `127.0.0.1`. `cmd_expect`
  names `localhost`. `_wait_console_ready` names `127.0.0.1`. `cmd_console`
  prints `localhost` as advice. Each place must use the bind address. A bind
  address of `0.0.0.0` is not a destination, so the connect address is
  `127.0.0.1` in that one case.

- **The image-cache key excludes both ports, so the cache needs no change.**
  `App::FuguVM::DiskCache->key` hashes the version, the architecture, the disk
  size, the installer script and the generation counter. Its comment states the
  result: "Thus memory and port changes keep hitting the same entry."
  `t/fuguvm/diskcache.t` already proves it: "memory and ports do not shape the
  disk, so the key holds". Automatic ports therefore share one cache entry
  across a whole fleet, which is what FuguTTX IAC-DEV-1 and EVL-RUNS-3 need.

- **Two cold `up` runs both install the whole system today.** Each run derives
  the same key, misses the cache, and installs OpenBSD, which costs tens of
  minutes under software emulation. The second run then discards its own
  install. `App::FuguVM::DiskCache->store` refuses the second publication, and
  `Fugu::File->atomic_dir` refuses it again:

  ```perl
  if ( -e $target ) {
  	Fugu::Log->default->warning( 'Already exists: %s', $target );
  	return;
  }
  ```

  The comment of `store` states the rule for both refusals:

  > Entries are write-once: a rename onto a populated directory fails with
  > ENOTEMPTY, and the existing entry wins.

  The cache is therefore correct under a race. Only the wasted install needs a
  fix. A lock must make the second run wait, and then use the published entry.

- **The version gate must be optional.** FuguTTX `IAC-CI` states that a
  GitHub-hosted runner has no KVM. FuguTTX `IAC-IMAGE` builds the guest image
  with `autoinstall(8)` under qemu in CI. That runner carries the qemu version
  of its own image, and not the pinned version of the development host. With no
  directive the tool must check nothing. It must not run the binary.

- **A pinned version that the tool cannot verify must fail closed.** An absent
  binary, or output with no version in it, gives exit code 3.

- **The lock must release when its holder dies.** flock(2) releases every lock
  of a process when the process exits. A stale lock file therefore blocks
  nothing, and the tool needs no lock reaper.

- **Fugu ships no generic lock utility.** `Fugu::Pidfile` locks a file, but its
  `acquire` "fails at once and does not wait", and its file holds a PID. This
  plan therefore writes two small flock(2) callers in FuguVM. `Fcntl` is core
  Perl, so `t/fuguvm/boundary.t` stays green.

- **Validate each input once, at its boundary.** `App::FuguVM::Config` validates
  the bind address, the two port values and the version string. No module
  downstream checks them again.

## The tool surface

### `fuguvm status`

The command writes one `key: value` line for each key to standard output, in
sorted key order. It writes the lines whatever the `--quiet` option says,
because the lines are data. A diagnostic stays on the logger, on standard error.

| Key            | Value                                   |
| -------------- | --------------------------------------- |
| `accel`        | `kvm`, `hvf` or `tcg`                   |
| `bind_address` | The host address of the forwarded ports |
| `console_port` | The resolved console port               |
| `disk_exists`  | `1` or `0`                              |
| `installed`    | `1` or `0`                              |
| `name`         | The guest name                          |
| `pid`          | The QEMU process ID                     |
| `ssh_port`     | The resolved SSH port                   |
| `state`        | `running`, `stopped`, or the QMP status |

The first two rows and the two port values are new. The key set is stable: every
key appears on every run. A value can be empty, and an empty value means "not
now". A line with an empty value ends with the colon and one space, so every
line has one shape. `pid` is empty for a stopped guest today, and this plan
keeps that rule.

`fuguvm status <key>` writes the bare value of one key, with no key name and no
colon. Thus a `make` target reads one port without a text filter. An unknown key
gives exit code 2, and the diagnostic names every valid key.

The report is one hash, so the printer needs no second home. `_dump_sorted`
writes each line with `say`. `fuguvm disk info` shares the printer, so its
report moves to standard output with the same change.

### The `bind_address` directive

```
vm "default" {
	bind_address 127.0.0.1
}
```

| Rule             | Contract                                                                                                               |
| ---------------- | ---------------------------------------------------------------------------------------------------------------------- |
| Grammar          | One `key value` line. The value is one IPv4 address in dotted-decimal form.                                            |
| Place            | A `vm` block, else the project `.fuguvmrc`, else the global `~/.fuguvmrc`. The project file wins over the global file. |
| Default          | `127.0.0.1`.                                                                                                           |
| An invalid value | Exit code 3, with a message that names the invalid value.                                                              |
| A host name      | Invalid. A name resolves once for QEMU and once for the tool, and the two answers can differ.                          |

The fallback chain follows `image_cache`, `ssh_pubkey` and `cache_dir`, which
`load_vm` already merges from the enclosing file.

### Automatic host ports

```
vm "scenario-1" {
	ssh_port     auto
	console_port auto
}
```

| Rule               | Contract                                                                                                           |
| ------------------ | ------------------------------------------------------------------------------------------------------------------ |
| Grammar            | The word `auto`, or a decimal number from 1 to 65535.                                                              |
| An other value     | Exit code 3, with a message that names the directive.                                                              |
| The SSH range      | 100 ports from `DEFAULT_SSH_PORT`.                                                                                 |
| The console range  | 100 ports from `DEFAULT_CONSOLE_PORT`.                                                                             |
| The probe          | Bind a listening socket on the bind address and the candidate port, then close it. Take the first port that binds. |
| Exclusion          | Skip every port that the state file of a sibling guest of the project records.                                     |
| The record         | Write both resolved ports to the state of the guest, before the tool spawns QEMU.                                  |
| An exhausted range | Exit code 1, with a message that names the range.                                                                  |

The tool resolves both ports one time for each run of `up` and of `start`,
before the first spawn. A number in the directive resolves to itself. Thus one
read path serves `status`, `ssh`, `wait`, `expect` and `console`.

`stop` clears the record with the process ID. A later `start` therefore resolves
again, and a stopped guest reports an empty port for a directive of `auto`.

### The `qemu_version` directive

```
qemu_version 9.0
```

| Rule                     | Contract                                                                                                                                       |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| Place                    | The project `.fuguvmrc`, else the global `~/.fuguvmrc`.                                                                                        |
| No directive             | The tool checks nothing, and it does not run the binary.                                                                                       |
| The read                 | `Fugu::Process->run` with the argument `--version` and a timeout of 10 seconds.                                                                |
| The parse                | The first dotted-decimal token of the first output line.                                                                                       |
| The match                | Component by component, over the components that the directive names. `9.0` accepts `9.0.4` and refuses `9.1.0`. `9.0.4` accepts `9.0.4` only. |
| A mismatch               | Exit code 3, with a message that names both versions.                                                                                          |
| No version in the output | Exit code 3.                                                                                                                                   |
| An absent binary         | Exit code 3.                                                                                                                                   |
| The commands             | `up` and `start`, one time for each invocation, before the first spawn.                                                                        |

Exit code 3 is `Fugu::CLI::EXIT_CONFIG_ERROR`, which `App::FuguVM::CLI` already
imports as `EXIT_CONFIG_ERROR`.

### The image-cache lock

| Rule                       | Contract                                                                        |
| -------------------------- | ------------------------------------------------------------------------------- |
| The file                   | `.lock.<key>` in the `installed` directory of the cache.                        |
| The lock                   | An exclusive flock(2) on that file.                                             |
| The wait                   | Blocking, under `Fugu::Timeout::bounded`. The default deadline is 3600 seconds. |
| The order                  | Take the lock, look the key up a second time, then install.                     |
| A hit on the second lookup | Restore from the entry, and install nothing.                                    |
| The release                | The handle closes, or the process exits.                                        |
| `--no-cache`               | Take no lock. Such a run publishes nothing, so it cannot collide.               |
| A deadline that elapses    | Log a warning and install without the lock. A slow install must not fail a run. |

The lock file lives in the cache directory, and every project that shares that
directory shares the lock. Two projects on one host therefore serialize one
installation, which is what a shared read-only cache needs.

A dot file cannot collide with an entry. `list` reads only a directory whose
name has no leading dot. `sweep_temp` removes only a directory whose name starts
with `.tmp.`.

### The port lock

| Rule                    | Contract                                                                   |
| ----------------------- | -------------------------------------------------------------------------- |
| The file                | `ports.lock` in the cache directory.                                       |
| The lock                | An exclusive flock(2), held across the probe and the record of both ports. |
| The wait                | Blocking, under `Fugu::Timeout::bounded`, with a deadline of 30 seconds.   |
| A deadline that elapses | Log a warning and probe without the lock.                                  |

The lock closes the window between the probe and the record. One window stays
open: a foreign process can take a probed port before QEMU binds it. The tool
reports that case as a QEMU startup failure, and `_dump_qemu_log` already prints
the QEMU log. The tool must not hang and must not retry silently.

### App::FuguVM::Config

| Method                 | Change                                                                                                                                                    |
| ---------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `DEFAULT_BIND_ADDRESS` | A new constant, `127.0.0.1`, beside `DEFAULT_SSH_PORT`.                                                                                                   |
| `AUTO_PORT`            | A new constant, `auto`. This is the one home of the word.                                                                                                 |
| `AUTO_PORT_COUNT`      | A new constant, 100. Each range starts at its default port, so the two range bounds need no constant of their own.                                        |
| `load_vm($name)`       | Apply `$vm->{bind_address} //= $self->bind_address`. Validate the address and both port values. Return `undef` and record the reason on an invalid value. |
| `bind_address`         | A new method. Return the setting of the enclosing files, or `DEFAULT_BIND_ADDRESS`.                                                                       |
| `qemu_version`         | A new method. Return the setting of the enclosing files, or `undef`.                                                                                      |

`load_vm` reports an invalid value through the `error` accessor that plan 001
adds. `App::FuguVM::CLI` reads it through the `load_exit` field of plan 001, so
a bad value gives 3 and an undeclared guest still gives 4. This plan adds both
if it merges first.

### App::FuguVM::Guest

| Method                              | Change                                                                                                                                                       |
| ----------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `accel`                             | A new method. Return the recorded accelerator while the guest runs. Return the accelerator that the tool selects now in every other case.                    |
| `bind_address`                      | A new method. Return the configured address.                                                                                                                 |
| `connect_address`                   | A new method. Return the address that the tool connects to: the bind address, or `127.0.0.1` when the bind address is `0.0.0.0`.                             |
| `ssh_port`, `console_port`          | Return the recorded port. Fall back to the configured number. Return `undef` for `auto` with no record.                                                      |
| `status`                            | Report `accel` and `bind_address`, and the resolved ports.                                                                                                   |
| `up`, `start`                       | Call `_check_qemu_version`, then `_resolve_ports`, before the first spawn. Return the code that the check gives.                                             |
| `_resolve_ports`                    | A new method. Resolve both ports under the port lock, and record them with the accelerator.                                                                  |
| `_free_port($first, $last, $taken)` | A new method. Return the first port of the range that binds on the bind address and that `$taken` does not hold.                                             |
| `_taken_ports`                      | A new method. Return the recorded ports of every guest of the project. The method enumerates the state directory, like `App::FuguVM::CLI::_disks_backed_by`. |
| `_lock_ports`                       | A new method. Return the locked handle of `ports.lock`, or `undef` on the deadline.                                                                          |
| `_check_qemu_version`               | A new method. Return `undef` when the check passes, and when no directive exists. Return `EXIT_CONFIG_ERROR` otherwise.                                      |
| `_qemu_version`                     | A new method. Return the version that the binary reports, or `undef`.                                                                                        |
| `_accel_args`                       | Take the name from `accel`. The method keeps the pairing of the CPU model.                                                                                   |
| `_start_qemu`                       | Put the bind address in the hostfwd rule and in the serial listener. Take both ports from the resolved values.                                               |
| `_wait_console_ready`               | Connect to `connect_address`.                                                                                                                                |
| `wait_ssh`                          | Connect to `connect_address`.                                                                                                                                |

`_check_qemu_version` reads the binary that `_qemu_path` of plan 001 resolves.
With no plan 001 in the tree it reads `QEMU_BINARY`.

`accel` and `_accel_args` have one home for the choice. Plan 001 moves that
choice into `App::FuguVM::Arch->accelerator`, and `accel` calls it. The recorded
value wins for a running guest, because a guest that started under `--emulate`
runs TCG whatever the host can do now. `_resolve_ports` records the selected
value before the spawn, so the record and the running guest always agree.

FuguTTX EVL-RUNS-1 grades a scenario on that answer, and FuguTTX IAC-METAL-1
records it. The answer must therefore be the truth about the running guest. Plan
001 makes the choice correct, and this plan reports it.

### App::FuguVM::State

| Method                | Contract                                                                                                                                     |
| --------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| `set_runtime(%facts)` | Record `accel`, `ssh_port` and `console_port`. The method saves the store.                                                                   |
| `get_runtime`         | Return the three facts as a hash reference. Return an empty hash reference when the guest never ran.                                         |
| `clear_runtime`       | Delete the record, and save the store. Every caller of `clear_vm_pid` calls it. `destroy` needs no call, because it empties the whole store. |

The three facts describe one run of one guest, so one record holds them. The
store is the JSON file that `Fugu::StateFile` already writes at mode 0600.

### App::FuguVM::DiskCache

| Method                       | Contract                                                                                                                                     |
| ---------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| `lock_entry($key, $timeout)` | Return an open, exclusively locked handle on the lock file of `$key`. Return `undef` on the deadline, and `undef` when the file cannot open. |

The module keeps the write-once rule of `store`. The lock removes the wasted
install, and it does not replace the rule. A lock that a deadline released must
never publish a second entry.

### App::FuguVM::CLI

| Method                            | Change                                                                                                                                     |
| --------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| `_dump_sorted`                    | Write each line to standard output with `say`.                                                                                             |
| `cmd_status`                      | Accept one optional key argument. Write the bare value for a key, and every line otherwise. Return `EXIT_INVALID_ARGS` for an unknown key. |
| `cmd_console`                     | Name `connect_address` in the connection advice, and report it as the `host` value.                                                        |
| `cmd_ssh`                         | Connect to `connect_address`.                                                                                                              |
| `cmd_expect`                      | Give `connect_address` to `App::FuguVM::Console`.                                                                                          |
| The `status` entry of `%COMMANDS` | A `usage` value of `[key]`.                                                                                                                |

`App::FuguVM::Console` needs no change: `new` already takes a `host` argument,
and its default is `localhost`.

## Load contract

The change adds no CPAN module, and it needs no `cpanfile` line and no `deps/`
line. `Fcntl` and `IO::Socket::INET` are core Perl. `App::FuguVM::Guest` and
`App::FuguVM::DiskCache` each gain an `Fcntl` line, for the `:flock` names.
`_free_port` reaches `IO::Socket::INET` through the lazy `require` that
`_wait_console_ready` already holds.

`Fugu::Process` and `Fugu::Timeout` come from the installed Fugu library, and
`App::FuguVM::Guest` loads both today. `App::FuguVM::DiskCache` gains a
`Fugu::Timeout` line.

The change adds no external program. It runs the QEMU system binary with
`--version`, and that binary is a runtime dependency today.

## Files

| File                                   | Content                                                                                                                                       |
| -------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| `lib/App/FuguVM/CLI.pm`                | `_dump_sorted` on standard output, the key argument of `cmd_status`, the connect address in three commands, and the `usage` value             |
| `lib/App/FuguVM/CLI.pod`               | The `status` output contract, the key argument, and exit code 2 for an unknown key                                                            |
| `lib/App/FuguVM/Config.pm`             | The three constants, the two accessors, and the validation in `load_vm`                                                                       |
| `lib/App/FuguVM/Config.pod`            | The `bind_address`, `ssh_port`, `console_port` and `qemu_version` directives, with the defaults                                               |
| `lib/App/FuguVM/Guest.pm`              | The three new public methods, the six new private methods, the port record, the bind address in the QEMU command line, and the resolved ports |
| `lib/App/FuguVM/Guest.pod`             | One section on the addresses and the ports, and one on the version gate                                                                       |
| `lib/App/FuguVM/State.pm`              | `set_runtime`, `get_runtime` and `clear_runtime`                                                                                              |
| `lib/App/FuguVM/State.pod`             | The runtime record, and what clears it                                                                                                        |
| `lib/App/FuguVM/DiskCache.pm`          | `lock_entry`, and the `Fugu::Timeout` line                                                                                                    |
| `lib/App/FuguVM/DiskCache.pod`         | `lock_entry`, the lock file, and the double lookup                                                                                            |
| `share/fuguvm/fuguvm.conf.sample`      | The `qemu_version` line, and `bind_address` in the sample `vm` block                                                                          |
| `share/fuguvm/vms/default.conf.sample` | The `bind_address` line                                                                                                                       |
| `share/fuguvm/vms/minimal.conf.sample` | `ssh_port auto` and `console_port auto`, in place of the two hand-assigned ports                                                              |
| `man/fuguvm/fuguvm.1`                  | Six edits, listed below                                                                                                                       |
| `t/fuguvm/cli.t`                       | The `status` output tests                                                                                                                     |
| `t/fuguvm/config.t`                    | The directive tests                                                                                                                           |
| `t/fuguvm/guest.t`                     | The address, port, accelerator and version tests                                                                                              |
| `t/fuguvm/state.t`                     | The runtime record tests                                                                                                                      |
| `t/fuguvm/diskcache.t`                 | The lock tests                                                                                                                                |

`README.md` names no port and no address, so it needs no edit. `CLAUDE.md` names
no directive, so it needs no edit. `lib/App/FuguVM.pod` gains no entry, because
this plan adds no module. `share/fuguvm/cache-generation` does not change,
because the cache key does not change. `cpanfile` and the three `deps/` files do
not change.

The six edits of `man/fuguvm/fuguvm.1`:

1. `DESCRIPTION`, the `status` item: state the standard-output contract, list
   every key, and name the optional key argument.
2. `DESCRIPTION`, the `console` item: name the bind address in the advice.
3. `FILES`: add `bind_address` to the per-VM key list. Add `qemu_version` to the
   project key list. State the `auto` value of the two port directives.
4. `EXIT STATUS`: extend item 3 with the version mismatch and the invalid
   directive value. Extend item 2 with the unknown `status` key.
5. `SECURITY CONSIDERATIONS`: replace the paragraph that states that both ports
   listen on each host interface. State the `127.0.0.1` default, and state that
   `bind_address 0.0.0.0` restores the old reach.
6. `EXAMPLES`: add a fleet example. Two `vm` blocks with `auto` ports, one
   `fuguvm --vm scenario-1 up`, and one
   `fuguvm --vm scenario-1 status ssh_port`.

## Tests

Every test uses `Test::More` with `done_testing()`, and each one mirrors a test
of `t/fuguvm/`. A test that needs `qemu-img` skips without it, like the second
half of `t/fuguvm/diskcache.t`.

`t/fuguvm/config.t` proves:

- `bind_address` in a `vm` block reaches the merged configuration.
- `bind_address` in the project file serves a `vm` block that omits it.
- The project file wins over the global file.
- The default is `127.0.0.1`.
- An address with a component above 255 fails, and `error` names the value.
- A host name as an address fails.
- `ssh_port auto` and `console_port auto` survive the merge as the word `auto`.
- A port of 0, a port of 65536 and the value `yes` each fail.
- `qemu_version` returns the project value, then the global value, then `undef`.

`t/fuguvm/guest.t` proves:

- `bind_address` returns the configured address.
- `connect_address` returns the bind address, and `127.0.0.1` for `0.0.0.0`.
- `_free_port` returns a port of the range that binds, and it skips a port that
  the caller names as taken.
- `_free_port` returns `undef` for a range that a listening socket fills. The
  test opens the sockets itself, so it needs no guest.
- `_resolve_ports` records a configured number as itself.
- `_resolve_ports` records a port of the range for `auto`.
- `ssh_port` returns the recorded port, and the configured number with no
  record, and `undef` for `auto` with no record.
- `accel` returns the recorded value for a running guest.
- `accel` returns a known name for a stopped guest.
- `_check_qemu_version` returns `undef` with no directive, and it runs no
  command. The test counts the runs with a stub binary.
- `_check_qemu_version` accepts `9.0` against a reported `9.0.4`.
- `_check_qemu_version` refuses `9.1` against a reported `9.0.4`, with
  `EXIT_CONFIG_ERROR`.
- `_check_qemu_version` refuses output with no version in it.
- `_check_qemu_version` refuses an absent binary.
- `status` holds every key of the table, for a stopped guest and for a guest
  with a record.

`t/fuguvm/state.t` proves:

- `set_runtime` and `get_runtime` round-trip the three facts.
- `get_runtime` returns an empty hash reference for a fresh state.
- `clear_runtime` empties the record, and the store survives a reload.

`t/fuguvm/diskcache.t` proves:

- `lock_entry` returns a handle, and a second `lock_entry` from a child process
  waits for it.
- `lock_entry` returns `undef` when the deadline elapses, and it does not hang.
- The lock releases when the holder exits.
- The lock file does not appear in `list`.
- `sweep_temp` leaves the lock file alone.
- `key` ignores `bind_address`. The existing assertion covers the two ports, and
  the new assertion adds the address.

`t/fuguvm/cli.t` proves:

- `fuguvm status` writes every line to standard output, and writes nothing to
  standard error, for a healthy project.
- `fuguvm --quiet status` writes the same lines.
- Each line matches `^\w+: `.
- `fuguvm status ssh_port` writes one bare value and no key name.
- `fuguvm status nonsense` returns 2, and names the valid keys on standard
  error.
- `fuguvm disk info` writes to standard output.

## Acceptance

- `make check` passes: `make lint`, `make test` and `make tidy`.
- `t/fuguvm/boundary.t` passes: `Fcntl` and `IO::Socket::INET` are core Perl,
  and no new import names a CPAN module.
- `t/scripts/symbols.t` passes: every new sub has a caller in `lib/`, `bin/` or
  a test, and every module keeps its `.pod` sidecar.
- `make man` builds `man/fuguvm/fuguvm.1` with no mandoc warning.
- One manual run proves the fleet on a Linux host. The project declares two `vm`
  blocks with `auto` ports. Two `fuguvm up` runs start at the same time, from
  one cold cache. One run installs, and the other run waits. Both guests then
  answer `fuguvm ssh true`.
- One manual run proves the bind address. After `fuguvm up`, `ss -tlnp` names
  `127.0.0.1` for both ports, and it does not name `0.0.0.0`.

## Open questions

1. **The word "exact" in AGT-RUNTIME-3.** The rule says that the `.fuguvmrc`
   names the exact qemu version. This plan matches component by component over
   the components that the directive names, so `9.0` accepts every `9.0.x`. A
   consumer that needs the full triple writes the full triple. If FuguTTX needs
   the strict form for every directive, the rule must say so, and the match
   becomes a full string comparison.
2. **The shape of the two locks.** Both locks are one exclusive flock(2) on a
   named file, with a bounded wait, released at process exit. Fugu holds no such
   utility today, and `Fugu::Pidfile` cannot serve, because its `acquire` never
   waits. A later `Fugu::Lock` could hold the shape for both callers, and for
   the sibling repositories. This plan keeps both callers in FuguVM, and it
   proposes no Fugu module.
3. **The range size.** Each range holds 100 ports, which bounds one host to 100
   guests per cache directory. FuguTTX `IAC-DEV` fixes four parallel scenarios
   today, so the bound is far away. A directive for the bounds needs a consumer
   first.
4. **A stopped guest with `auto`.** The report gives an empty port for such a
   guest, because the record dies with the run. A caller that wants a stable
   port for the life of a project must write a number. No cited rule asks for a
   stable automatic port.
