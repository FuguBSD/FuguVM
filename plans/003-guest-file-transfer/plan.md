# 003 — Guest file transfer, an argument vector over ssh, and a console that attaches

## Status

Proposed.

This plan depends on plan 002,
[`plans/002-scriptable-and-parallel-guests/plan.md`](../002-scriptable-and-parallel-guests/plan.md).
Plan 002 adds the `bind_address` directive, whose default is `127.0.0.1`, and
the method `App::FuguVM::Guest->connect_address`. Each verb of this plan
connects to that address.

This plan also depends on Fugu plan 003. That plan lives in the Fugu repository,
at `plans/003-ssh-read-file-and-host-keys/plan.md`. It adds
`Fugu::SSH->read_file`, which `fuguvm get` needs. That plan lands in two parts:
part one adds `read_file`, and part two adds the strict host-key mode later. No
verb of this plan sets the strict mode.

## Purpose

A script needs three verbs that the tool does not give today.

`fuguvm put` copies a local file or a local directory into a running guest.
`fuguvm get` copies one guest file to the host. Both verbs move bytes over the
SFTP channel of `Fugu::SSH`.

`fuguvm ssh` gains an argument-vector form. The tool quotes each word, so the
remote shell splits the command at the word boundaries only. It expands nothing,
and it globs nothing.

`fuguvm console` attaches to the serial console of the guest. Today the verb
prints four lines and starts nothing. An operator who must diagnose a guest that
does not boot needs the console itself.

## Why FuguVM holds this work

`fuguvm` is the one tool that installs and operates an OpenBSD guest for the
FuguBSD projects. A consumer uses it as a command only: `App::FuguVM` is an
application, and a sibling application is not a library. Hard rule 1 of the
briefing states it, and `t/fuguvm/boundary.t` enforces it.

Four consumer harnesses must copy a source tree into a guest, run a build step
there, and copy a report back out. No consumer can hold that work, because a
consumer must not load an `App::FuguVM` module.

The transport half belongs in `Fugu::`, and it lands there: Fugu plan 003 adds
`Fugu::SSH->read_file`, beside the `write_file` that stands today. This plan
holds the tool half only: the verbs, the argument quoting, the local walk, the
publish order, and the exit codes. Fugu plan 003 assigns the quoting here in one
sentence of its "Out of scope" section:

> A list form of `run_command`. The method keeps its string argument. FuguVM
> plan 003 owns the quoting of an argument list.

The console half belongs to `App::FuguVM::Console`, which already drives the
serial console with expect(1) scripts. The attach verb is the same console, with
an operator at the keyboard instead of a script.

## Consumers and citations

| Repo       | Unit                                 | Rules          | Need                                                                                       |
| ---------- | ------------------------------------ | -------------- | ------------------------------------------------------------------------------------------ |
| FuguOracle | `ARCH-DEPS` (spec/architecture.md)   | ARCH-DEPS-5    | `fuguvm put` copies the source tree and the port files into the guest                      |
| FuguOracle | `TEST-INTEROP` (spec/testing.md)     | TEST-INTEROP-4 | One `fuguvm ssh` call for each step. The harness must load no `App::FuguVM` module         |
| FuguOracle | `TEST-INTEROP` (spec/testing.md)     | TEST-INTEROP-5 | The harness must read the exit code of each `fuguvm` call                                  |
| FuguOracle | `TEST-INTEROP` (spec/testing.md)     | TEST-INTEROP-7 | `fuguvm put` copies four inputs in, and `fuguvm get` copies the test report out            |
| FuguPass   | `QA-HARNESS` (spec/testing.md)       | QA-HARNESS-7   | `fuguvm put` copies the build and the vectors in, and `fuguvm ssh` runs each step          |
| FuguPass   | `QA-HARNESS` (spec/testing.md)       | QA-HARNESS-8   | `fuguvm expect` answers a readpassphrase(3) prompt on the console. The verb stands today   |
| FuguTTX    | `TRN-TRACES` (spec/training.md)      | — (prose only) | The rollout driver copies in, copies out, runs each step over the ssh verb, reads the code |
| FuguTTX    | `EVL-AGENTIC` (spec/evaluation.md)   | — (prose only) | The suite operates each guest with the `fuguvm` command, and links to no FuguVM module     |
| FuguTTX    | `IAC-METAL` (spec/infrastructure.md) | IAC-METAL-1    | `fuguvm ssh "uname -m"` must print `amd64` and must return exit code 0                     |

Every unit above exists today. This plan opened each document and verified each
anchor. Each rule number is the next free number of its unit, and the
specification edit set of this workflow adds it:

- FuguOracle `ARCH-DEPS` holds ARCH-DEPS-1 to ARCH-DEPS-4 today.
- FuguOracle `TEST-INTEROP` holds TEST-INTEROP-1 to TEST-INTEROP-3 today.
- FuguPass `QA-HARNESS` holds QA-HARNESS-1 to QA-HARNESS-5 today.
- FuguTTX `IAC-METAL` holds no numbered rule today.

FuguTTX `TRN-TRACES` and FuguTTX `EVL-AGENTIC` are prose anchors, and the
workflow changes their prose only. Each row therefore cites no rule.

FuguPass QA-HARNESS-8 needs no new code. `fuguvm expect` already accepts a
caller path, and this one line of `App::FuguVM::Console::run_script` proves it:

```perl
	my $path = -f $script ? $script : $self->script_path($script);
```

A path that exists wins over a shipped name. So a FuguPass test can point the
verb at its own expect(1) script. The plan states this so no reader adds a verb
that exists.

FuguTTX must not call `Fugu::SSH`. Decision D7 states that the client loads only
`Fugu::REPL` from the distribution. FuguTTX reaches this work as a command, like
qemu and the `scw` CLI, so no decision blocks it. FuguTTX plan 001 proposes the
D7 change, and it waits for a human.

The architecture check of IAC-METAL-1 needs an amd64 guest, which FuguVM plan
001 adds. The argument-vector form of the same command needs this plan.

## Scope

In scope:

- `fuguvm put <local> <remote>`, with a `--mode` option.
- `fuguvm get <remote> <local>`.
- An argument-vector form of `fuguvm ssh`, and one quoting rule for it.
- A `fuguvm console` verb that attaches to the serial console.
- One new module, `App::FuguVM::Remote`: the remote side of a running guest.
- One new method, `App::FuguVM::Console->attach`.
- A running-guest check on the four verbs.
- The terminal save and restore around the console child.

Out of scope:

- A recursive `fuguvm get`. `Fugu::SSH->read_file` reads one file, and the
  module gives no remote directory listing. One call copies one file.
- A second SFTP client. The transport stays in `Fugu::SSH`.
- A stdin path for the argument-vector form. `Fugu::SSH->run_command` opens no
  standard input for the remote command. The interactive form keeps the standard
  input of the caller, because ssh(1) inherits it.
- A remote symbolic link, a device node, a socket, and a fifo. The tool copies a
  regular file and a directory.
- A host key policy. Fugu plan 003 owns the `strict` and `known_hosts` options,
  and no verb of this plan sets either one.
- A telnet client of its own. QEMU serves the console with the telnet protocol,
  and telnet(1) speaks it.
- A `--timeout` option on the three SSH verbs. One constant bounds the session.
  See the open questions.

## Constraints that shape the design

**`cmd_ssh` gives one string to the remote shell today.** This is the whole
argument path of the verb:

```perl
	if (@args) {
		my $result = $ssh->run_command( join( ' ', @args ) );
		print $result->{stdout}        if $result->{stdout};
		print STDERR $result->{stderr} if $result->{stderr};
		return $result->{exit_code};
	}
	else {
		return $ssh->interactive;
	}
```

`run_command` hands the string to `$channel->exec($command)`, and sshd hands it
to the login shell. So the remote shell splits the string again. A file name
with a space becomes two words. A word with a `*` becomes a glob. A word with a
`$` becomes an expansion.

**Getopt::Long eats a remote word that starts with a hyphen.** `Fugu::CLI`
configures the per-command parser with two settings only:

```perl
	$sub->configure( 'bundling', 'no_ignore_case' );
```

The `ssh` entry declares no option, so the parser knows `help|h` only, and it
permutes: it reads an option after a non-option argument. A recorded run proves
the result. `fuguvm ssh uname -m` prints `Unknown option: m` and exits 2 today.
`fuguvm ssh ls -l /tmp` fails the same way. Two documents already carry the
broken form: the SYNOPSIS of `lib/App/FuguVM.pod` shows `fuguvm ssh uname -a`.
FuguTTX IAC-METAL-1 names the quoted form `fuguvm ssh "uname -m"`, which works.

The `--` separator is the answer, and it works today. Getopt::Long stops at the
separator, removes it, and leaves the rest of the vector alone. So
`fuguvm ssh -- uname -m` reaches the command body as the two words `uname` and
`-m`. The tool must not try to see the separator: the parser removed it before
the body ran.

**One remote read costs one SSH handshake.** `Fugu::SSH` opens and closes a
connection for each operation:

```perl
sub _with_connection ( $self, $code )
{
	my $ssh2 = $self->_connect;
	return unless defined $ssh2;

	my $result = $code->($ssh2);
	$ssh2->disconnect;

	return $result;
}
```

`write_file` calls it once for each file. So a tree of N files costs N
handshakes. An emulated guest needs seconds for one handshake, so the design
must batch every operation that it can. The tool therefore creates every remote
directory in one call. It also publishes every file in one call. `BATCH_PATHS`
splits a call that would hold too many paths.

**The session timeout bounds a channel read.** `_connect` sets one value for the
whole session:

```perl
	my $ssh2 = Net::SSH2->new;
	$ssh2->timeout( $self->{timeout} * 1000 );    # milliseconds
```

`DEFAULT_TIMEOUT` is 10 seconds. A guest build is quiet for longer than that, so
the default truncates the output and reports a wrong exit code. The tool must
name a large value. One value bounds the connect too, so a caller must run
`fuguvm wait` before it runs work. FuguOracle TEST-INTEROP-4 already states that
order: "The harness must call `fuguvm up`, then `fuguvm wait`, then one
`fuguvm ssh` call for each step."

**`write_file` returns a status, and `read_file` returns data.** Fugu plan 003
records both shapes in one table:

| Method       | Success           | Failure |
| ------------ | ----------------- | ------- |
| `write_file` | 0, like a command | 1       |
| `read_file`  | the bytes         | `undef` |

So the tool must compare a write result with 0, and it must test a read result
with `defined`. An empty guest file returns the empty string, which is false. A
truth test would report a failure for a file that arrived whole.

**SFTP applies a mode only when it creates a file.** `write_file` opens with
`O_WRONLY | O_CREAT | O_TRUNC` and the mode. An existing remote file keeps its
own mode through that open. So a write over an existing file cannot set the mode
the caller asked for. The tool must write a new file each time, and it must then
move that file onto the destination. `Fugu::File->write_atomic` applies the same
rule on the host, and `Fugu::File->write` states the reason: "An existing file
keeps its own mode through the open."

**`Fugu::Process->run` cannot drive an interactive child.** The passthrough path
gives the child a pipe on its standard input, and the parent closes the writing
end at once:

```perl
	pipe my $in_r, my $in_w or return _run_error("Cannot create pipe: $!");
	...
			open STDIN, '<&', $in_r
```

A telnet child would read an end of file immediately. expect(1) does not care,
because it opens a pseudo-terminal of its own. So the console verb must call
`system` and must map the status with `Fugu::Process->exit_code`.
`Fugu::SSH->interactive` sets that precedent:

```perl
	return Fugu::Process->exit_code( system(@cmd) );
```

**telnet(1) leaves the terminal raw when it dies.** telnet turns off ICANON,
ECHO and ISIG while it holds the terminal. A telnet that a signal kills restores
nothing, and the operator then has an unusable shell. The tool owns the
terminal, so the tool must restore it.

**The guest never closes the console.** `share/fuguvm/expect/install.exp`
records the fact:

```
# The install is complete once the system halts. Do NOT wait for eof.
# OpenBSD's halt stops at the "press any key to reboot" prompt and
# does not close the console. Thus telnet stays connected and no eof
# ever arrives.
```

So no end of file ends an attachment. The operator must end it, with the telnet
escape key.

**The console takes one client.** `App::FuguVM::Guest` gives QEMU one serial
chardev:

```perl
	push @cmd, '-serial', "tcp::$console_port,server,telnet,nowait";
```

An installation and `fuguvm expect` both attach to that one port. So an operator
must not attach while either runs.

**The connect address comes from the guest.** `cmd_ssh` already carries the
reason for an address and not a name:

```perl
	# The connection uses the SSH agent for authentication. Connect
	# over IPv4: QEMU forwards the guest SSH port on 127.0.0.1 only.
	# On dual-stack hosts, for example CI runners, 'localhost'
	# resolves to ::1 first.
```

`cmd_console` prints `localhost` today. Plan 002 adds
`App::FuguVM::Guest->connect_address`, and each verb of this plan must take the
address from that method.

**`--quiet` hides the whole console verb today.** The four lines go through the
logger, and `_prepare` builds a quiet logger for `--quiet`. So today
`fuguvm --quiet console` prints nothing and does nothing at all.

## The tool surface

### `fuguvm ssh`

```
fuguvm ssh
fuguvm ssh [--] <command> [argument ...]
```

With no argument the verb opens an interactive session, as it does today. It
returns the exit code of ssh(1).

With arguments the verb runs one remote command. Each argument is one word of
the argument vector. The tool quotes every word, so the remote shell performs no
splitting, no expansion, and no globbing. The words arrive exactly as the caller
wrote them.

A caller must write `--` before any word that starts with a hyphen. The option
parser reads such a word as an option of the tool, and it fails with exit
code 2.

A caller that wants a remote shell asks for one:

```sh
fuguvm ssh -- sh -c 'cd /src && make regress'
```

The verb returns the exit code of the remote command. `Fugu::SSH->run_command`
reports a connect failure as exit code 1, with a diagnostic. So the tool must
add no code of its own after it loads the VM. A remote exit code of 4, 5, 7, 9
or 11 therefore reads like a tool code. The diagnostic on standard error tells
the two apart, and the man page must state it.

The remote command gets no terminal and no standard input. The interactive form
keeps the standard input of the caller, because ssh(1) inherits it.

Standard output of the remote command arrives when the command ends, because
`run_command` collects it whole. A build that writes for ten minutes shows
nothing until then.

### `fuguvm put`

```
fuguvm put [--mode=<octal>] <local> <remote>
```

`<local>` names a regular file or a directory. `<remote>` names the destination,
and it must be an absolute path. `<remote>` is never a container:
`put src /root` writes the content of `src` into `/root`, and it adds no `src`
component.

The verb works in this order:

1. It validates the arguments. It refuses a wrong argument count and a relative
   `<remote>`. It refuses a `--mode` value that is not 3 or 4 octal digits. It
   refuses a `<local>` that is neither a regular file nor a directory. Each one
   exits 2.
2. It walks `<local>` and builds one entry list, in sorted order. A symbolic
   link, a device node, a socket and a fifo each fail the whole call, before the
   tool writes one byte.
3. It refuses a file above `MAX_TRANSFER_SIZE`, before it reads the file.
4. It creates every remote directory with one `mkdir -p` call.
5. It writes each file to a temporary name beside its destination.
6. It publishes every temporary file with one call of `mv -f` commands.

A failure after step 4 removes every temporary file that the tool wrote, with
one `rm -f` call. So a failed run leaves no partial destination file. A
directory copy is not atomic as a whole, and the man page must state that limit.

`BATCH_PATHS` splits step 4, step 6 and the removal. A tree of 500 files
therefore costs 500 writes and a small number of batched calls.

`--mode` sets the mode of each file that the tool writes. Without the option the
tool uses the permission bits of the local file, masked with 0777. The tool must
not copy a setuid bit or a setgid bit. `--mode` can name all four digits,
because the caller then asks for them.

The mode reaches the file at its open, through `write_file`, and mv(1) keeps it.
No chmod call runs.

`--mode` does not apply to a directory. `mkdir -p` gives each directory the mode
that the remote umask allows.

### `fuguvm get`

```
fuguvm get <remote> <local>
```

`<remote>` names one regular file in the guest, and it must be an absolute path.
`<local>` names the destination file on the host, and it must not be an existing
directory. Each violation exits 2.

The verb reads the whole file with `Fugu::SSH->read_file`, with
`MAX_TRANSFER_SIZE` as the cap. It creates the parent directory of `<local>`
with `Fugu::File->ensure_dir`. It then writes the bytes with
`Fugu::File->write_atomic`, mode 0644.

That order leaves no partial local file. Fugu plan 003 states the same order,
and it is the reason `read_file` returns bytes and not a stream.

`get` does not read the mode of the remote file, because `read_file` returns
bytes only. A caller that needs a mode sets it on the host.

### `fuguvm console`

```
fuguvm console
```

The verb attaches the terminal of the operator to the serial console of the
guest. It runs telnet(1) against the connect address of the guest and the
`console_port` of the VM.

The verb logs one line before it attaches: the address, the port, and how to
leave. The line goes through the logger, so `--quiet` drops it and the
attachment still happens.

The session ends in one of three ways. The operator types the telnet escape key,
`Ctrl-]`, and then `quit`. Or telnet(1) exits because it cannot connect. Or a
signal kills telnet(1). No end of file arrives from the guest, because the guest
never closes the console.

The verb restores the terminal on every exit path. The man page must state that
`fuguvm expect` and an installation each hold the same port. Therefore an
operator must not attach while one runs.

### Exit codes

The verbs add no exit code. They use the codes that `lib/App/FuguVM/CLI.pod`
already documents:

| Code | Meaning for these four verbs                                   |
| ---- | -------------------------------------------------------------- |
| 0    | Success                                                        |
| 1    | The guest does not run, a transfer failed, or a connect failed |
| 2    | A bad argument count, a relative path, or a bad `--mode` value |
| 4    | The named VM is not in the configuration                       |

`fuguvm ssh` with a command returns the exit code of the remote command instead,
once it connects.

### `App::FuguVM::Remote`, a new module

The module holds the remote side of one running guest. It owns the `Fugu::SSH`
object, the argument quoting, the local walk, and the publish order. Thus
`App::FuguVM::CLI` keeps three thin command bodies, and one module holds the
session timeout.

| Method                              | Contract                                                                                             |
| ----------------------------------- | ---------------------------------------------------------------------------------------------------- |
| `new(host => $host, port => $port)` | Build the object. It opens nothing. `host` is the connect address of the guest, and `user` is `root` |
| `run(@argv)`                        | Run one argument vector. Return the hash of `Fugu::SSH->run_command`                                 |
| `interactive()`                     | Open an interactive session. Return the exit code of ssh(1)                                          |
| `put($local, $remote, %args)`       | Copy a file or a directory in. Return 1, or `undef`. `%args` takes `mode`                            |
| `get($remote, $local)`              | Copy one guest file out. Return 1, or `undef`                                                        |
| `quote_argv(@argv)`                 | Return one remote command string. A class method                                                     |

`new` dies when the caller gives no host, and it dies when the caller gives no
port. Each one is a programming error. `run` dies on an empty vector, for the
same reason. Every other failure is a return value, and the module reports each
reason through `Fugu::Log->default`.

`quote_argv` wraps each word in single quotes, and it replaces each single quote
inside a word with `'\''`. An empty word becomes `''`. The words join with one
space. `run` and `put` both call it: `put` builds its `mkdir -p`, `mv -f` and
`rm -f` commands from quoted paths.

Three constants carry the numbers:

| Constant            | Value              | Reason                                                                         |
| ------------------- | ------------------ | ------------------------------------------------------------------------------ |
| `SSH_TIMEOUT`       | 3600               | Seconds. It holds a guest build and a large transfer, and it still ends a hang |
| `MAX_TRANSFER_SIZE` | 64 \* 1024 \* 1024 | Bytes, for one file. `write_file` and `read_file` each hold a file in memory   |
| `BATCH_PATHS`       | 100                | Paths for each batched remote command, so no command line grows too long       |

Four private methods each have one caller in the module: `_entries`, `_mkdir`,
`_publish` and `_discard`. The `.pod` must not document them, because a sidecar
documents public API only.

### `App::FuguVM::Console->attach`

`attach()` attaches the terminal of the caller to this console. It returns the
exit code of telnet(1).

The method works in this order:

1. It saves the terminal attributes of standard input, when standard input is a
   terminal. `POSIX::Termios` reads them. `require POSIX` stays lazy, as
   `App::FuguVM::Guest` already does it.
2. It installs a handler for `INT`, `TERM` and `HUP`. The handler restores the
   attributes, sets the handler back to `DEFAULT`, and raises the same signal
   again. Thus the exit status of the tool stays honest.
3. It runs `system( 'telnet', $self->{host}, $self->{port} )`.
4. It restores the attributes, and it returns
   `Fugu::Process->exit_code($status)`.

`Fugu::Process->exit_code` maps an absent telnet(1) to 1, and it maps a signal
death to 128 plus the signal number. So the verb needs no code of its own.

The restore is idempotent, and step 4 runs it even when step 2 already ran it.

`App::FuguVM::CLI` builds the object with `host => $vm->connect_address`.
`cmd_expect` keeps `localhost`, because a change there is a behavior change
outside this plan.

### `App::FuguVM::CLI`

The `%COMMANDS` table gains two entries, and two entries change:

| Entry     | Change                                                                    |
| --------- | ------------------------------------------------------------------------- |
| `put`     | New. `usage` is `[--mode=<octal>] <local> <remote>`. One option, `mode=s` |
| `get`     | New. `usage` is `<remote> <local>`                                        |
| `ssh`     | `usage` becomes `[--] [command [argument ...]]`                           |
| `console` | `summary` becomes `Attach to the VM serial console`                       |

The module gains `cmd_put`, `cmd_get` and one private helper,
`_require_running($vm)`. The helper logs one line and returns 0 when the guest
does not run. The four verbs each call it, because a clear message beats a
"Failed to connect" from libssh2.

`cmd_ssh` and `cmd_console` lose their bodies of today. `cmd_ssh` builds an
`App::FuguVM::Remote` object instead of a `Fugu::SSH` object, so `use Fugu::SSH`
leaves the module.

## Load contract

The change adds no CPAN module. The `cpanfile` needs no line, and no `deps/`
manifest changes. `App::FuguVM::Remote` uses `Fugu::File`, `Fugu::Log`,
`Fugu::SSH` and core `File::Find`. `App::FuguVM::Console` gains a lazy
`require POSIX`.

`t/fuguvm/boundary.t` proves the contract: `Module::CoreList::is_core` accepts
`File::Find` and `POSIX`, and every other import names `Fugu::` or
`App::FuguVM::`.

The change adds no external program. telnet(1) is already a runtime dependency.
`deps/Linux.txt` and `deps/Darwin.txt` each hold `runtime pkg telnet`.
`deps/OpenBSD.txt` names no telnet package, because the base system ships it.
All three shipped expect(1) scripts already spawn telnet.

`fuguvm get` needs `Fugu::SSH->read_file`, which Fugu plan 003 adds. The `dist`
line of each manifest fetches `releases/latest/download/Fugu.tar.gz`, and a
release asset carries no version. So `cmd_get` must test
`Fugu::SSH->can('read_file')` first. When the method is absent the verb must log
one line that names the needed Fugu release, and it must return exit code 1. A
stack trace is not a diagnosis.

## Files

| File                         | Content                                                                                                                         |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| `lib/App/FuguVM/Remote.pm`   | The new module: `new`, `run`, `interactive`, `put`, `get`, `quote_argv`, the three constants, and the four private methods      |
| `lib/App/FuguVM/Remote.pod`  | The API sidecar of the new module                                                                                               |
| `lib/App/FuguVM.pod`         | One index entry for `App::FuguVM::Remote`. The SYNOPSIS line `fuguvm ssh uname -a` becomes `fuguvm ssh -- uname -a`             |
| `lib/App/FuguVM/CLI.pm`      | `cmd_put`, `cmd_get`, `_require_running`, the rewritten `cmd_ssh` and `cmd_console`, four `%COMMANDS` edits, and no `Fugu::SSH` |
| `lib/App/FuguVM/CLI.pod`     | The two new verbs, the argument-vector rule, and the exit-code text of the four verbs                                           |
| `lib/App/FuguVM/Console.pm`  | `attach`                                                                                                                        |
| `lib/App/FuguVM/Console.pod` | `attach`, the escape key, and the one-client rule                                                                               |
| `man/fuguvm/fuguvm.1`        | Five edits, listed below                                                                                                        |
| `README.md`                  | The quick-start line becomes `bin/fuguvm ssh -- uname -a`                                                                       |
| `CLAUDE.md`                  | The layout list gains the remote module                                                                                         |
| `t/fuguvm/remote.t`          | The new unit test                                                                                                               |
| `t/fuguvm/cli.t`             | The new subtests                                                                                                                |

`scripts/dist` finds every module under `lib/` and builds the `MANIFEST` from
the staged tree, so the release needs no manifest edit. `share/fuguvm/` does not
change. `cpanfile` and `deps/*.txt` do not change.

The five edits of `man/fuguvm/fuguvm.1`:

1. The command list: add `put` and `get`. Name the argument order, the `--mode`
   rule, the absolute-path rule, and the non-atomic limit of a directory copy.
2. The command list: replace the `ssh` entry. Name the argument vector, the `--`
   separator, the absent terminal, and the absent standard input.
3. The command list: replace the `console` entry. Name the attachment, the
   `Ctrl-]` escape key, and the one-client rule.
4. `EXIT STATUS`: state that `fuguvm ssh` with a command returns the code of the
   remote command. State also that a remote code can read like a tool code. Name
   the diagnostic on standard error as the way to tell them apart.
5. `EXAMPLES`: `fuguvm ssh "uname -a"` becomes `fuguvm ssh -- uname -a`. Add one
   `put`, `ssh` and `get` sequence, which FuguOracle TEST-INTEROP-7 describes.

`SECURITY CONSIDERATIONS` also gains two sentences. `put` and `get` reach the
guest as root, over the forwarded SSH port. The console port carries no
authentication of its own, and the guest login prompt is the only gate.

## Tests

Every test uses `Test::More` with `done_testing()`, and each one mirrors a test
that stands in `t/fuguvm/` today. `t/fuguvm/remote.t` keeps the `plan skip_all`
shape of `t/fuguvm/cli.t` for an absent `Net::SSH2`.

`t/fuguvm/remote.t` proves:

- `quote_argv` wraps one plain word in single quotes.
- `quote_argv` keeps a word with a space as one word.
- `quote_argv` turns a word with a single quote into the `'\''` form.
- `quote_argv` returns `''` for an empty word.
- `quote_argv` leaves no unquoted `*`, `$`, `;`, `&` or backtick in its result.
- `quote_argv` joins several words with one space.
- `new` stores the port, and it dies with no port.
- `run` dies on an empty vector.
- The three constants hold the documented values.
- `_entries` lists a single regular file as one entry, with its destination
  path.
- `_entries` lists a directory tree in sorted order, with every directory and
  every file.
- `_entries` maps each relative path under the destination, and it adds no
  component for the source directory name.
- `_entries` returns `undef` for a tree that holds a symbolic link, a fifo, or a
  file above `MAX_TRANSFER_SIZE`.
- `_entries` returns the local permission bits, masked with 0777, and it drops a
  setuid bit.
- `_entries` returns the `--mode` value for every file when the caller gives
  one.
- `put` returns `undef` for a closed port, and it does not die.
- `get` returns `undef` for a closed port, and it does not die.
- `get` returns `undef` when `<local>` is an existing directory.
- A batched command holds no more than `BATCH_PATHS` paths.

`t/fuguvm/cli.t` proves:

- `fuguvm put` with one argument exits 2.
- `fuguvm put` with a relative `<remote>` exits 2.
- `fuguvm put --mode=8888` exits 2, and `--mode=0755` and `--mode=755` both pass
  the validation.
- `fuguvm put` with a `<local>` that does not exist exits 2.
- `fuguvm get` with three arguments exits 2.
- `fuguvm ssh`, `fuguvm put`, `fuguvm get` and `fuguvm console` each exit 4 for
  a VM that the configuration does not declare.
- Each of the four verbs exits 1 for a declared VM that does not run, and the
  message names the VM.
- `fuguvm ssh -- uname -m` reaches the command body with the two words `uname`
  and `-m`. This is the regression guard for the parser rule above.
- `fuguvm ssh --help` exits 0.
- The `%COMMANDS` table declares `put` and `get`, and the `put` entry declares
  the `mode=s` option.

Three paths need a real guest, and no unit test can build one:

- A successful `put` of a directory, and the mode of each arrived file.
- A successful `get` of a file, and of an empty file.
- The console attachment, and the terminal state after it.

The plan states all three limits, because a reader must not believe that the
unit tests cover a transfer or an attachment. The acceptance list below covers
them.

## Acceptance

- `make check` passes: `make lint`, `make test` and `make tidy`.
- `make prettier` passes for the Markdown changes.
- `t/scripts/symbols.t` passes: every public sub has a caller in `lib/`, in
  `bin/`, or in a test.
- `t/fuguvm/boundary.t` passes: `App::FuguVM::Remote` adds no CPAN import and no
  `Protocol::` import.
- `mandoc -Tlint man/fuguvm/fuguvm.1` reports nothing.
- The `.pod` sidecar of each changed module documents every public sub.
- FuguVM passes against a build of the Fugu branch of Fugu plan 003:
  `cpanm --local-lib=local ../Fugu/build/Fugu-*.tar.gz`, then `make check`.
- One recorded live run against a guest proves the transfer. The run holds these
  steps, in this order:
  - `fuguvm up`
  - `fuguvm wait`
  - `fuguvm put lib /root/lib`
  - `fuguvm ssh -- find /root/lib -type f`
  - `fuguvm get /root/lib/App/FuguVM.pm /tmp/out.pm`
  - a byte comparison of the two local files
- The same run proves the mode: a local executable file arrives executable, and
  `fuguvm put --mode=0600` gives mode 0600.
- The same run proves the quoting: `fuguvm ssh -- touch '/root/a b'` creates one
  file, and `fuguvm ssh -- echo '*'` prints one asterisk.
- The same run proves the exit code: `fuguvm ssh -- false` exits 1, and
  `fuguvm ssh -- sh -c 'exit 42'` exits 42.
- One recorded run proves the read bound. A remote command that stays quiet for
  more than 10 seconds returns its whole output and its true exit code.
- One recorded console attachment proves the terminal contract. The operator
  attaches, types `Ctrl-]` and `quit`, and the shell that follows echoes each
  keystroke.
- A second recorded attachment proves the signal path. A `kill` of the tool ends
  the session, and the shell that follows echoes each keystroke.

## Open questions

1. **The session timeout is one value.** `Fugu::SSH` bounds the connect and the
   channel read with the same number. So `SSH_TIMEOUT` of 3600 seconds lets a
   connect to a booting guest wait for an hour. The plan accepts it, because
   FuguOracle TEST-INTEROP-4 puts `fuguvm wait` before every `fuguvm ssh` call.
   A second connect option in `Fugu::SSH` would remove the trade, and no Fugu
   plan holds one today.
2. **The read bound rests on a documentation claim.** The plan states that the
   session timeout of Net::SSH2 bounds a channel read. The acceptance list holds
   one recorded run to confirm it. When the claim is wrong, the constant is
   harmless and the truncation needs another answer.
3. **A directory copy costs one handshake for each file.** The batched
   `mkdir -p` and `mv -f` calls cost two more. A tree of 500 files therefore
   opens 502 connections, which an emulated guest serves slowly. The alternative
   is one archive: write one tar file and extract it in the guest. That answer
   needs the host tar and the guest tar to agree on one format, and this plan
   cannot prove that agreement. A measured run of TEST-INTEROP-7 must decide it.
4. **A bare `fuguvm ssh uname -m` exits 2.** The option parser reads `-m` as an
   option. The working form is `fuguvm ssh -- uname -m`. FuguVM plan 001 uses
   the quoted form `fuguvm ssh "uname -m"`, which works today.
5. **`cmd_expect` still uses `localhost`.** The attach verb uses the connect
   address of the guest, for the reason that `cmd_ssh` records. A dual-stack
   host can therefore serve the two verbs differently. One line would align
   them, and that line is a behavior change outside this plan.
6. **`get` copies one file.** FuguTTX `TRN-TRACES` copies "each transcript" out,
   which is one call for each file. A run that must copy a whole result
   directory needs a remote listing, and `Fugu::SSH` gives none. A caller can
   build one archive in the guest and copy that file instead.
