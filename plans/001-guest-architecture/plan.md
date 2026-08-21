# 001 — A guest architecture directive for amd64 and arm64

## Status

Proposed.

## Purpose

A `vm` block accepts `arch amd64` or `arch arm64`. The value selects these
items:

- the QEMU binary
- the machine type
- the firmware
- the TCG CPU model
- the mirror path of the miniroot
- the installer answers
- the image-cache key

The default stays `arm64`.

The accelerator rule changes with it. The tool must select KVM or HVF only when
the host machine runs the instruction set of the guest. It must select TCG in
every other case.

## Why FuguVM holds this work

`fuguvm` is the one tool that installs and operates an OpenBSD guest for the
FuguBSD projects. A consumer uses it as a command only: `App::FuguVM` is an
application, and a sibling application is not a library. No consumer can hold
this work, and no consumer can carry a QEMU command line of its own.

The architecture is a property of one machine. It therefore belongs in the `vm`
block, beside `version`, `memory` and `disk_size`. It flows from there to every
module that shapes the machine.

Three consumer repositories need an amd64 guest with hardware acceleration. One
consumer needs an arm64 guest, which the tool installs today. One consumer needs
both architectures for the same port.

## Consumers and citations

| Repo       | Unit           | Rules             | Need                                                                                                                                                          |
| ---------- | -------------- | ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| FuguTTX    | `AGT-RUNTIME`  | AGT-RUNTIME-1     | Each guest of the agentic suite is amd64, and the tool must select KVM on the x86_64 host. A guest that falls back to software emulation fails the target.    |
| FuguTTX    | `IAC-DEV`      | IAC-DEV-3         | The guest architecture of the suite is amd64, and the tool must select KVM on this host.                                                                      |
| FuguTTX    | `IAC-METAL`    | IAC-METAL-1       | `fuguvm ssh "uname -m"` must print `amd64`, and the tool must report the `kvm` accelerator.                                                                   |
| FuguTTX    | `EVL-RUNS`     | EVL-RUNS-1        | The suite must prove hardware acceleration before it grades a scenario. The amd64 guests use KVM.                                                             |
| FuguTTX    | `INF-ARM64`    | prose of the unit | An arm64 OpenBSD guest for the arm64 ports build. The tool serves this need today, and this plan must keep it.                                                |
| FuguOracle | `PKG-ORACLE`   | PKG-ORACLE-7      | The developer must verify both ports on OpenBSD/amd64 and on OpenBSD/arm64.                                                                                   |
| FuguPass   | `QA-HARNESS`   | QA-HARNESS-7      | Every leg of the suite runs in an OpenBSD guest on a host that is not OpenBSD. A developer host is commonly x86_64, so the default arm64 guest would emulate. |
| FuguPass   | `QA-CALIBRATE` | QA-CALIBRATE-4    | The scaling check can run in a guest. An emulated guest gives a false round count, so the guest must match the host.                                          |

Every unit above exists today. This plan opened each document and verified each
anchor. Each rule ID is the first free number of its unit, and the specification
edit set of this workflow adds it. No decision blocks a consumer here. `fuguvm`
is a development-host tool, like qemu and the `scw` CLI, and a consumer loads no
module from it.

`fuguvm ssh uname -m` exits 2 today, because the option parser of `Fugu::CLI`
reads `-m` as an option. The quoted form `fuguvm ssh "uname -m"` works, so this
plan uses it. FuguVM plan 003 adds the argument-vector form
`fuguvm ssh -- uname -m` as the alternative, and FuguTTX `IAC-METAL-1` must use
a working form.

Two facts in the consumer specifications already state the need, and they stand
today. FuguTTX `IAC-DEV` names the development host: one Elastic Metal server
with an AMD EPYC 4545P processor and Linux with KVM. FuguTTX `EVL-RUNS` states
that the suite runs OpenBSD/amd64 guests, because no Scaleway offer gives a
native arm64 OpenBSD host.

## Scope

In scope:

- One `arch` directive in a `vm` block, with the values `amd64` and `arm64`.
- The default value `arm64`.
- One architecture table: the QEMU binary, the machine type, the TCG CPU model,
  the host machine names, and the firmware paths.
- An accelerator rule that compares the host machine with the guest.
- The mirror path of the miniroot.
- The installer answers that differ between the two architectures.
- The image-cache key, which already carries the architecture.
- The architecture in the `status` report.
- Exit code 3 for an unknown value, and for an absent QEMU binary.
- A guard that stops a guest whose disk holds an other architecture.

Out of scope:

- An `--arch` command-line option. The value shapes the installed disk, so two
  invocations must not disagree about one disk.
- A third architecture. Neither `i386` nor `riscv64` has a consumer today.
- A cross-architecture snapshot or a cross-architecture disk import. A disk
  belongs to one architecture for its whole life.
- The `accel` field of a scriptable `status`. Plan 002 owns the machine-readable
  `status` output, and `IAC-METAL-1` needs it. This plan makes the accelerator
  correct, and plan 002 reports it.
- An `autoinstall(8)` install mode and an image export. Plan 004 owns both, and
  plan 004 depends on this plan.
- A qemu version gate. Plan 002 owns it.

## Constraints that shape the design

- **The value names the OpenBSD architecture, not the QEMU machine.** The
  accepted strings are `amd64` and `arm64`, because the guest is OpenBSD. The
  mirror path and the cache key already use that spelling.
  `App::FuguVM::Miniroot::url` builds
  `"/pub/OpenBSD/$version/" . ARCH . "/$filename"`.
  `App::FuguVM::DiskCache::key` returns
  `"$version-$arch-" . substr( $hash, 0, KEY_HASH_LENGTH )`. The QEMU spellings
  `aarch64` and `x86_64` stay inside the architecture table.

- **The image cache needs no new key shape.** `App::FuguVM::DiskCache::key`
  holds the architecture in the hashed record, as `"arch=$arch"`, and in the key
  string, as `"$version-$arch-"`. An entry lives in `installed/<key>`, and
  `store` is write-once. It returns early when `base.qcow2` exists. It publishes
  each entry with one rename of a sibling directory. Two architectures therefore
  give two key strings, two entry directories, and two immutable base images.
  The only change is the source of the value. `key` must read the architecture
  from the VM configuration, and not from the constant
  `App::FuguVM::Miniroot::ARCH`.

- **Do not increase the generation counter.** The key hashes the contents of
  `install.exp`, so the change to the installer script rotates the arm64 key by
  itself. `share/fuguvm/cache-generation` covers a change outside that file.

- **The accelerator must match the host machine.** QEMU cannot accelerate a
  guest whose instruction set is not the host's. The rule today names one host:

  ```perl
  elsif ( $^O eq 'linux' && -w '/dev/kvm' && _host_arch() eq 'aarch64' ) {
  ```

  An amd64 guest on an x86_64 Linux host would therefore emulate, and FuguTTX
  `AGT-RUNTIME-1` fails a target that emulates. The Darwin branch tests no
  architecture at all, so it would ask for HVF for an arm64 guest on an Intel
  Mac. Both branches must compare the host machine with the guest.

- **A host machine has more than one name.** `_host_arch()` returns
  `POSIX::uname()` field 4. Linux reports `aarch64` and `x86_64`. Darwin reports
  `arm64` and `x86_64`. OpenBSD reports `arm64` and `amd64`. Each architecture
  therefore carries a list of host machine names, and not one name.

- **An OpenBSD host always emulates.** The rule selects KVM on Linux and HVF on
  Darwin, so an OpenBSD host falls through to TCG. This is correct: QEMU has no
  accelerator on OpenBSD, and FuguTTX `IAC-DEV` states the same fact.

- **`-cpu host` is valid only with hardware acceleration.** The code pairs the
  two today:

  ```perl
  return ( '-accel', $accel, '-cpu', $accel eq 'tcg' ? TCG_CPU : 'host' );
  ```

  Each architecture therefore needs its own TCG model. `cortex-a57` serves
  arm64, and `qemu64` serves amd64.

- **The firmware differs, and the console follows the firmware.** The arm64
  machine is `virt,highmem=off`, it has no display adapter, and edk2 uses the
  serial port as the EFI console. The amd64 machine is `q35`, it has a display
  adapter, and it needs an x86 EFI firmware file. Both architectures boot the
  removable-media path of the install media, so neither needs a writable
  variable store. `-bios` with a code-only file is enough, exactly as the arm64
  path works today.

- **The amd64 boot loader writes to the display, not to the serial port.** The
  installer answers arrive over one serial console, through
  `-serial "tcp::$console_port,server,telnet,nowait"`. The amd64 boot loader
  must therefore move the console to `com0` before it boots the kernel.

- **A disk belongs to one architecture.** `up` consults the image cache only
  when the disk is absent. Therefore a changed directive must not start the
  wrong QEMU on an existing disk. The state must record the architecture of the
  installed disk, and `up` must stop when the two disagree.

- **One invalid value must stop the run early.** `Fugu::Config` reads a value as
  a string, so the configuration loader is the boundary of the directive. The
  loader validates the value one time, and no module downstream repeats the
  check.

## The tool surface

### The directive

```
vm "openbsd-amd64" {
	arch         amd64
	version      7.8
	memory       2048
	disk_size    8G
	ssh_port     2222
	console_port 4444
}
```

`arch = amd64` is the same directive: both spellings come from `Fugu::Config`.
The accepted values are the exact strings `amd64` and `arm64`. The comparison is
case sensitive, so `AMD64` is an unknown value. An absent directive means
`arm64`.

### The architecture table

| Property           | `arm64`                         | `amd64`                         |
| ------------------ | ------------------------------- | ------------------------------- |
| QEMU binary        | `qemu-system-aarch64`           | `qemu-system-x86_64`            |
| Machine type       | `virt,highmem=off`              | `q35`                           |
| TCG CPU model      | `cortex-a57`                    | `qemu64`                        |
| Host machine names | `aarch64`, `arm64`              | `x86_64`, `amd64`               |
| Mirror path        | `/pub/OpenBSD/<version>/arm64/` | `/pub/OpenBSD/<version>/amd64/` |
| Cache key          | `<version>-arm64-<hash8>`       | `<version>-amd64-<hash8>`       |

The firmware search list of `arm64` keeps the five paths and the Homebrew glob
that the tool uses today. The list of `amd64` holds the x86 equivalents, in this
order:

```
/opt/homebrew/share/qemu/edk2-x86_64-code.fd
/usr/local/share/qemu/edk2-x86_64-code.fd
/usr/share/qemu/edk2-x86_64-code.fd
/usr/share/OVMF/OVMF_CODE_4M.fd
/usr/share/OVMF/OVMF_CODE.fd
/usr/share/edk2/ovmf/OVMF_CODE.fd
```

The glob `/opt/homebrew/Cellar/qemu/*/share/qemu/edk2-x86_64-code.fd` follows
the list, as it does for arm64.

### The accelerator rule

| Condition                                                   | Accelerator | `-cpu`                            |
| ----------------------------------------------------------- | ----------- | --------------------------------- |
| `--emulate`                                                 | `tcg`       | the TCG model of the architecture |
| Linux, `/dev/kvm` is writable, and the host machine matches | `kvm`       | `host`                            |
| Darwin, and the host machine matches                        | `hvf`       | `host`                            |
| Every other case                                            | `tcg`       | the TCG model of the architecture |

### Exit codes

| Code | Cause                                                                                              |
| ---- | -------------------------------------------------------------------------------------------------- |
| 3    | The `arch` value is neither `amd64` nor `arm64`.                                                   |
| 3    | The QEMU binary of the architecture is not on `PATH`.                                              |
| 1    | The state records an other architecture for the existing disk. The message names `fuguvm destroy`. |

Code 3 is `Fugu::CLI::EXIT_CONFIG_ERROR`, which `App::FuguVM::CLI` already
imports as `EXIT_CONFIG_ERROR`.

### `fuguvm status`

The report gains one line, `arch`, beside `ssh_port` and `console_port`.

### App::FuguVM::Arch, a new module

The module holds the architecture table and nothing else. It uses core Perl
only, and it loads no other module of the distribution.

| Method                                         | Contract                                                                                                           |
| ---------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| `App::FuguVM::Arch->new($name)`                | Return the architecture object for `amd64` or `arm64`. Return `undef` for every other name.                        |
| `App::FuguVM::Arch->names`                     | Return the supported names, sorted. A diagnostic names them, so the message and the table cannot disagree.         |
| `$arch->name`                                  | The OpenBSD name of the architecture.                                                                              |
| `$arch->qemu_binary`                           | The QEMU binary name.                                                                                              |
| `$arch->machine`                               | The `-M` machine string.                                                                                           |
| `$arch->tcg_cpu`                               | The `-cpu` model for software emulation.                                                                           |
| `$arch->firmware_paths`                        | The ordered list of absolute firmware paths.                                                                       |
| `$arch->firmware_glob`                         | One glob pattern for the versioned Homebrew paths.                                                                 |
| `$arch->accelerator($os, $host_machine, $kvm)` | Return `kvm`, `hvf` or `tcg` for one host. The method calls no syscall, so a test proves every branch on any host. |

### App::FuguVM::Config

| Method           | Change                                                                                                                                                   |
| ---------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `DEFAULT_ARCH`   | A new constant, `arm64`, beside `DEFAULT_VERSION`. This is the one home of the default.                                                                  |
| `load_vm($name)` | Apply `$vm->{arch} //= DEFAULT_ARCH`. Validate the value with `App::FuguVM::Arch->new`. Return `undef` when the value is unknown, and record the reason. |
| `error`          | A new method. Return the reason of the last failed `load_vm`, or `undef`.                                                                                |

### App::FuguVM::CLI

`_load_vm` sets a new field, `$self->{load_exit}`. The field holds
`EXIT_CONFIG_ERROR` when `App::FuguVM::Config->error` reports a reason, and
`EXIT_VM_NOT_FOUND` otherwise. Each call site changes from
`or return EXIT_VM_NOT_FOUND` to `or return $self->{load_exit}`. Thus an unknown
value gives 3, and a VM that no file declares still gives 4.

`cmd_init` writes `arch = arm64` in the generated `vms/default.conf`, beside
`version`. The template already spells out every other default.

### App::FuguVM::Guest

| Method                   | Change                                                                                                                                                                                                                   |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `EXIT_CONFIG_ERROR`      | A new constant, 3, beside `EXIT_VM_RUNNING` and `EXIT_TIMEOUT`.                                                                                                                                                          |
| `_arch`                  | A new method. Return the `App::FuguVM::Arch` object of the configured value, and cache it. The method dies when the name has no entry: the configuration loader is the boundary, so an unknown value cannot arrive here. |
| `_qemu_path`             | A new method. Return the path of `$arch->qemu_binary` on `PATH`, or `undef`.                                                                                                                                             |
| `up`, `start`            | Call `_qemu_path` first. Return `EXIT_CONFIG_ERROR` when the binary is absent, with a message that names the binary and the architecture.                                                                                |
| `up`                     | Compare `$config->{arch}` with `App::FuguVM::State->get_installed_arch`. Return `EXIT_ERROR` on a difference. An absent record cannot prove a difference, so the check passes.                                           |
| `_start_qemu`            | Take the binary, the machine string and the firmware from `_arch`.                                                                                                                                                       |
| `_accel_args`            | Call `$arch->accelerator( $^O, _host_arch(), -w '/dev/kvm' ? 1 : 0 )`, and keep the `--emulate` branch. Pair `host` with hardware acceleration and `$arch->tcg_cpu` with `tcg`.                                          |
| `_find_efi_firmware`     | Walk `$arch->firmware_paths`, then `$arch->firmware_glob`.                                                                                                                                                               |
| `status`                 | Report `arch`.                                                                                                                                                                                                           |
| `QEMU_BINARY`, `TCG_CPU` | Delete both constants. The table replaces them.                                                                                                                                                                          |

### App::FuguVM::Miniroot

| Method                           | Change                                          |
| -------------------------------- | ----------------------------------------------- |
| `new($cache_dir, $proxy, $arch)` | Take the architecture name as a third argument. |
| `url($version)`                  | Build the path from `$self->{arch}`.            |
| `ARCH`                           | Delete the constant.                            |

The miniroot file name does not change: `_image_filename` returns
`miniroot78.img` for both architectures, and only the path segment differs.

### App::FuguVM::DiskCache

`key($vm_config)` reads `$vm_config->{arch}`. It returns `undef` with a warning
when the configuration carries no architecture, exactly as it does for an
installer script that it cannot read. The caller then has no key, and thus no
caching. The module no longer reads `App::FuguVM::Miniroot::ARCH`.

### App::FuguVM::State

| Method                  | Change                                                                                             |
| ----------------------- | -------------------------------------------------------------------------------------------------- |
| `mark_installed($arch)` | Record the architecture with the install mark. The argument is required, so no path can forget it. |
| `get_installed_arch`    | Return the recorded architecture, or `undef`.                                                      |

### App::FuguVM::Console

`run_install($config)` passes `$config->{arch}` as the fifth argument of
`install.exp`, after the root password and the proxy URL.

### share/fuguvm/expect/install.exp

The script takes a fifth argument, the architecture. It prints the usage line
and exits 1 when the argument list does not carry it. It does the same when the
value is neither `amd64` nor `arm64`. The configuration loader is the boundary
of the value, so `App::FuguVM::CLI` never reaches this exit.

These answers differ between the two architectures. Every other answer stays as
it is.

| Prompt             | `arm64` answer      | `amd64` answer                                       | Reason                                                                                                                                                   |
| ------------------ | ------------------- | ---------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `boot>`            | one carriage return | `stty com0 115200`, then `set tty com0`, then `boot` | The arm64 machine has no display adapter, so the loader already writes to the serial port. The amd64 machine has one, so the loader must move to `com0`. |
| `Use (W)hole disk` | `w`                 | the letter that selects a whole-disk GPT             | The amd64 guest boots UEFI, so its disk needs a GPT with an EFI system partition.                                                                        |

These answers stay the same, and the plan records why:

| Prompt                              | Answer                         | Reason                                                                                                                                                                                                           |
| ----------------------------------- | ------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Terminal type?`                    | the default                    | Both installers run on a serial console, and both propose the same type.                                                                                                                                         |
| `Which disk is the root disk?`      | the default                    | The working disk is the first `-drive` of the QEMU command line, and the install media is the second. The working disk is therefore the first virtio disk on both machines, and the script names no disk device. |
| `HTTP Server?`, `Server directory?` | `cdn.openbsd.org`, the default | The installer builds the architecture directory of the sets itself.                                                                                                                                              |
| `Set name(s)?`                      | `-game* -x*`                   | The set names hold no architecture.                                                                                                                                                                              |

A wrong answer costs one installation, and not a corrupt cache: the cache key
hashes `install.exp`, so a correction rotates the key.

## Load contract

The change adds no CPAN module, and it needs no `cpanfile` line.
`App::FuguVM::Arch` uses core Perl only. `App::FuguVM::Guest` keeps its `POSIX`
lazy `require` in `_host_arch`.

The change adds two external programs on a Linux host: `qemu-system-x86_64` and
an x86 EFI firmware file. `deps/Linux.txt` therefore gains `qemu-system-x86` and
`ovmf`, beside `qemu-system-arm` and `qemu-efi-aarch64`. The `qemu` package of
Darwin and of OpenBSD ships every target and the edk2 firmware files, so neither
manifest changes. One `make deps` on each platform must prove that claim before
the change merges.

## Files

| File                                                                                                                         | Content                                                                                                                                                                                                                                                        |
| ---------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `lib/App/FuguVM/Arch.pm`                                                                                                     | The new module: the architecture table                                                                                                                                                                                                                         |
| `lib/App/FuguVM/Arch.pod`                                                                                                    | The API sidecar of the new module                                                                                                                                                                                                                              |
| `lib/App/FuguVM.pod`                                                                                                         | One index entry for `App::FuguVM::Arch`                                                                                                                                                                                                                        |
| `lib/App/FuguVM/Config.pm`                                                                                                   | `DEFAULT_ARCH`, the validation in `load_vm`, and `error`                                                                                                                                                                                                       |
| `lib/App/FuguVM/Config.pod`                                                                                                  | The `arch` directive, the default, and `error`                                                                                                                                                                                                                 |
| `lib/App/FuguVM/CLI.pm`                                                                                                      | `$self->{load_exit}`, and `arch` in the `cmd_init` template                                                                                                                                                                                                    |
| `lib/App/FuguVM/CLI.pod`                                                                                                     | Exit code 3 for an unknown `arch` value and an absent QEMU binary. One sentence also becomes true again: `App::FuguVM::Guest` defines the codes that it returns, because `App::FuguVM::CLI` loads `App::FuguVM::Guest` and the reverse import would be a cycle |
| `lib/App/FuguVM/Guest.pm`                                                                                                    | `_arch`, `_qemu_path`, the machine and firmware selection, the accelerator call, the disk guard, `arch` in `status`, and the deletion of `QEMU_BINARY` and `TCG_CPU`                                                                                           |
| `lib/App/FuguVM/Guest.pod`                                                                                                   | One section on the architecture and the accelerator                                                                                                                                                                                                            |
| `lib/App/FuguVM/Miniroot.pm`                                                                                                 | The architecture argument, and the deletion of `ARCH`                                                                                                                                                                                                          |
| `lib/App/FuguVM/Miniroot.pod`                                                                                                | `new` and `url`                                                                                                                                                                                                                                                |
| `lib/App/FuguVM/DiskCache.pm`                                                                                                | `key` reads the architecture from the configuration                                                                                                                                                                                                            |
| `lib/App/FuguVM/DiskCache.pod`                                                                                               | The source of the architecture in the key                                                                                                                                                                                                                      |
| `lib/App/FuguVM/State.pm`                                                                                                    | `mark_installed($arch)` and `get_installed_arch`                                                                                                                                                                                                               |
| `lib/App/FuguVM/State.pod`                                                                                                   | The two methods                                                                                                                                                                                                                                                |
| `lib/App/FuguVM/Console.pm`                                                                                                  | `run_install` passes the architecture                                                                                                                                                                                                                          |
| `lib/App/FuguVM/Console.pod`                                                                                                 | The argument list of `run_install`                                                                                                                                                                                                                             |
| `share/fuguvm/expect/install.exp`                                                                                            | The fifth argument and the amd64 answers                                                                                                                                                                                                                       |
| `share/fuguvm/fuguvm.conf.sample`                                                                                            | The `arch` line in the sample `vm` block                                                                                                                                                                                                                       |
| `share/fuguvm/vms/default.conf.sample`                                                                                       | The `arch` line                                                                                                                                                                                                                                                |
| `share/fuguvm/vms/minimal.conf.sample`                                                                                       | The `arch` line                                                                                                                                                                                                                                                |
| `man/fuguvm/fuguvm.1`                                                                                                        | Five edits, listed below                                                                                                                                                                                                                                       |
| `deps/Linux.txt`                                                                                                             | `qemu-system-x86` and `ovmf`                                                                                                                                                                                                                                   |
| `CLAUDE.md`                                                                                                                  | The external program list gains `qemu-system-x86_64`, and the layout list gains the architecture module                                                                                                                                                        |
| `t/fuguvm/arch.t`                                                                                                            | The new unit test                                                                                                                                                                                                                                              |
| `t/fuguvm/config.t`, `t/fuguvm/guest.t`, `t/fuguvm/miniroot.t`, `t/fuguvm/diskcache.t`, `t/fuguvm/state.t`, `t/fuguvm/cli.t` | The tests below                                                                                                                                                                                                                                                |

`README.md` holds no architecture claim, so it needs no edit. `scripts/dist`
finds every module under `lib/` and builds the `MANIFEST` from the staged tree,
so the release needs no manifest edit. `share/fuguvm/cache-generation` does not
change.

The five edits of `man/fuguvm/fuguvm.1`:

1. `DESCRIPTION`: replace the paragraph that states that the guest architecture
   is fixed. Name the `arch` directive, the two values, and the default.
2. The `--emulate` option: replace the accelerator rule with the host match rule
   of this plan.
3. `FILES`: add `arch` to the per-VM key list.
4. `EXIT STATUS`: extend item 3 with the unknown value and the absent QEMU
   binary.
5. `EXAMPLES`: add an amd64 `vm` block and the `fuguvm ssh "uname -m"` output
   `amd64`, which FuguTTX `IAC-METAL-1` names.

The `IMAGE CACHE` section already lists the architecture as a key input, and the
key shape it documents does not change. It needs no edit.

## Tests

Every test uses `Test::More` with `done_testing()`, and each one mirrors a test
that stands in `t/fuguvm/` today.

`t/fuguvm/arch.t` proves:

- `new` answers for `amd64` and for `arm64`, and returns `undef` for an unknown
  name, for the empty string, and for `AMD64`.
- `names` returns `amd64` and `arm64`, sorted.
- The QEMU binary, the machine string and the TCG CPU model of each
  architecture.
- No firmware path of `amd64` names `aarch64`, and no firmware path of `arm64`
  names `x86_64`. Neither list is empty.
- `accelerator` returns `kvm` for Linux with a writable `/dev/kvm` and a
  matching host machine, for each host machine name of the architecture.
- `accelerator` returns `tcg` for Linux with a writable `/dev/kvm` and a host
  machine of the other architecture.
- `accelerator` returns `hvf` for Darwin with a matching host machine, and `tcg`
  for Darwin with a host machine of the other architecture.
- `accelerator` returns `tcg` for Linux without a writable `/dev/kvm`, and for
  `openbsd` with any host machine.

`t/fuguvm/config.t` proves:

- `arch` defaults to `arm64` when the block omits it.
- `arch amd64` and `arch arm64` both load, in the `key value` form and in the
  `key = value` form.
- An unknown value makes `load_vm` return `undef`, and `error` names the value
  and the two accepted values.
- `error` returns `undef` after a load that succeeds.

`t/fuguvm/guest.t` proves:

- `_arch` returns the object of the configured value, and dies on an unknown
  value.
- `_accel_args` keeps the `--emulate` behavior: `tcg` with the TCG model of the
  architecture.
- `_accel_args` pairs `host` with `kvm` and with `hvf`, and the TCG model with
  `tcg`, as it does today.
- `_qemu_path` returns `undef` when `PATH` holds no such binary, and returns the
  path of an executable stub when `PATH` holds one.
- `_find_efi_firmware` returns `undef` or a file that exists.
- `status` reports the configured architecture.

`t/fuguvm/miniroot.t` proves:

- `url` builds the `arm64` path and the `amd64` path, and both file names are
  `miniroot78.img`.
- `new` with no architecture is a programming error.
- The `ARCH` assertion is deleted with the constant.

`t/fuguvm/diskcache.t` proves:

- The key of an amd64 configuration matches `^7\.8-amd64-[0-9a-f]{8}$`.
- The key of an amd64 configuration differs from the key of an arm64
  configuration that is equal in every other field.
- `entry_dir` of the two keys differ, so neither entry can overwrite the other.
- `key` returns `undef` when the configuration carries no architecture.

`t/fuguvm/state.t` proves that `mark_installed` records the architecture, and
that `get_installed_arch` reads it back. It also proves that
`get_installed_arch` returns `undef` for a fresh state.

`t/fuguvm/cli.t` proves that a project with an unknown `arch` value exits 3. It
also proves that a project with a valid value and an undeclared VM name still
exits 4.

## Acceptance

- `make check` passes: `make lint`, `make test` and `make tidy`.
- `t/scripts/symbols.t` passes: every public sub has a caller in `lib/`, in
  `bin/`, or in a test.
- `t/fuguvm/boundary.t` passes: `App::FuguVM::Arch` adds no CPAN import and no
  `Protocol::` import.
- `make prettier` passes for the Markdown and the manifest changes.
- `mandoc -Tlint man/fuguvm/fuguvm.1` reports nothing.
- One recorded installer transcript for each architecture. Each transcript must
  confirm every answer of the two tables above. A transcript is the only proof
  that an installer prompt reads as the plan states.
- `fuguvm up`, then `fuguvm ssh "uname -m"`, prints `amd64` on an x86_64 Linux
  host with a writable `/dev/kvm`. The log names the `kvm` accelerator. FuguTTX
  `IAC-METAL-1` states this test.
- `fuguvm up`, then `fuguvm ssh "uname -m"`, prints `arm64` on the same host
  under TCG. The arm64 guest must not regress.
- The image cache holds both entries at the same time, one for each
  architecture, and each base image is mode 0400.
- `make deps` installs the new Linux packages, and the firmware search finds a
  file on each platform.

## Open questions

1. **The amd64 firmware console.** The plan states that the OVMF console reaches
   the serial port, so the `boot>` prompt arrives at the expect script. One
   transcript must confirm it. When it does not arrive, the console route needs
   another answer, and `autoinstall(8)` is that answer. An `autoinstall(8)`
   response file needs no console at all. Plan 004 owns that install mode, and
   this plan would then depend on it.
2. **The whole-disk answer of the amd64 installer.** The plan states that the
   amd64 installer offers a whole-disk MBR and a whole-disk GPT, and that the
   UEFI guest needs the GPT. The transcript must give the exact prompt and the
   exact letter.
3. **The x86 firmware file name on OpenBSD and on Darwin.** The arm64 list
   already uses `/usr/local/share/qemu/edk2-aarch64-code.fd`, which the OpenBSD
   `qemu` package installs. The plan assumes the x86 sibling file sits beside
   it. `make deps` on each platform must confirm it.
4. **The disk guard for a state file with no recorded architecture.** The plan
   lets the check pass, because an absent record cannot prove a difference. The
   cost is one failed boot for an operator who changes the directive on an old
   disk, and the QEMU log tail reports it. A stricter rule would ask every
   existing checkout for one `fuguvm destroy`.
