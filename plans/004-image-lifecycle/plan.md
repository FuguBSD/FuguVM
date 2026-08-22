# 004 — The image lifecycle: an autoinstall mode, an image export, and an imported base disk

## Status

Proposed. Implements: GST-IMAGES.

This plan builds on the `arch` directive of
[GST-ARCH](../../spec/guests.md#gst-arch). A Scaleway import needs an amd64
guest that boots under UEFI, with the loader at `\EFI\Boot\bootx64.efi`. FuguTTX
`IAC-HOSTS` states that requirement, and it states the reason: "Scaleway rejects
legacy BIOS". The tool builds such a guest: `arch amd64` selects the amd64
machine, the x86 EFI firmware, and the accelerator. An arm64 export stays useful
for a FuguBSD developer, but no Scaleway host can boot it.

The code holds two features that help this work, and this plan names each one
where it applies. The two features are the lock around the first population of
one cache entry, and the `bind_address` directive.

## Purpose

Three changes carry an OpenBSD disk image through its whole life. The tool
builds one image, it publishes the image as a file, and an other host consumes
that file.

1. An `autoinstall <file>` directive on a `vm` block. The tool then installs the
   guest from an autoinstall(8) response file. The shipped expect installer
   stays the default.
2. `fuguvm image export <path>` writes the installed base disk of the invoked VM
   as a full-disk image. `--format=raw` writes the raw form.
3. A `base_disk <path>` directive makes an existing qcow2 file the base image of
   a guest. The tool then installs nothing.

## Why FuguVM holds this work

A consumer must never load an `App::FuguVM` module, because a sibling
application is not a library. `fuguvm` is consumable as a tool only: its
subcommands, its output and its exit codes. All three changes are tool-surface
changes.

Fugu holds no part of this work. Each piece is QEMU policy or OpenBSD installer
policy:

- The response file is an autoinstall(8) artifact, and only the installer of a
  guest reads it.
- The image export is one `qemu-img convert` call over the disk of one guest.
- The imported base disk is a qcow2 backing file under the image cache of the
  tool.
- The host address that the guest fetches from is the QEMU gateway address, and
  `App::FuguVM::Proxy` already owns it:
  `use constant HOST_GATEWAY => '10.0.2.2';`

One new capability could look generic: a small HTTP server that answers one
file. It must stay in FuguVM. The file that it serves is an installer response
file, and the address that it serves to is a QEMU gateway. Both facts are FuguVM
policy. `Fugu::Proxy` answers a proxy request, and it holds no origin-server
mode. This plan must not change that, because no second consumer needs one.

## Consumers and citations

| Repo    | Unit           | Rules             | Need                                                                                                                                                              |
| ------- | -------------- | ----------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| FuguTTX | `IAC-IMAGE`    | IAC-IMAGE-1       | The image build must drive `autoinstall(8)` with the tool, and it must export the installed disk as a qcow2 file. The response file lives in the stack directory. |
| FuguTTX | `IAC-IMAGE`    | IAC-IMAGE-2       | The tool must accept an existing qcow2 file as the base disk of a guest, so the suite installs nothing per host. A raw export serves the Elastic Metal route.     |
| FuguTTX | `IAC-HOSTS`    | prose of the unit | Four requirements on a project-built image, and the two import routes of Scaleway. The unit states that Scaleway offers no OpenBSD image.                         |
| FuguTTX | `AGT-RUNTIME`  | AGT-RUNTIME-1     | Each guest of the agentic suite is amd64, and the `.fuguvmrc` of the repository declares each guest.                                                              |
| FuguTTX | `AGT-RUNTIME`  | prose of the unit | "A bootable OpenBSD qemu image with snapshot support must be available on the host." The `infra/image` stack produces it.                                         |
| FuguTTX | `AGT-FEEDBACK` | AGT-FEEDBACK-1    | Each harness change runs against a guest snapshot. The imported image must therefore carry `snapshot save` and `snapshot restore`.                                |
| FuguTTX | `EVL-RUNS`     | EVL-RUNS-1        | The suite operates each OpenBSD guest with the `fuguvm` command, and the amd64 guests use KVM on the development host.                                            |
| FuguTTX | `EVL-RUNS`     | EVL-RUNS-3        | The suite operates several named guests at the same time, and the guests share one read-only image cache.                                                         |
| FuguTTX | `IAC-DEV`      | IAC-DEV-1         | The host declares one guest for each parallel scenario, and the guests share one read-only image cache.                                                           |
| FuguTTX | `EVL-AGENTIC`  | prose of the unit | The guest image comes from `IAC-IMAGE`.                                                                                                                           |

Every unit above exists today, and this plan opened `infrastructure.md`,
`agents.md` and `evaluation.md` and verified each anchor and each register row.
`IAC-IMAGE`, `IAC-HOSTS`, `AGT-RUNTIME`, `AGT-FEEDBACK`, `IAC-DEV`, `EVL-RUNS`
and `EVL-AGENTIC` carry no rule today. Every rule number above is therefore the
first free number of its unit. The specification edit set of this workflow adds
each cited rule.

No decision blocks a consumer here. `fuguvm` is a development-host tool, like
qemu and the `scw` CLI, and the repository loads no module from it. FuguTTX D7
therefore permits every row above.

Two facts of the consumer specification already state the need, and both stand
today. FuguTTX `IAC-HOSTS` states that "An OpenBSD host on Scaleway therefore
needs a project-built image". FuguTTX `IAC-IMAGE` states that `make image-build`
"runs `autoinstall(8)` under qemu in CI and emits a qcow2 file".

## Scope

In scope:

- One `autoinstall <file>` directive in a `vm` block.
- One `base_disk <path>` directive in a `vm` block.
- One `root_password_file <path>` directive in a `vm` block.
- Three derived install modes: `expect`, `autoinstall` and `import`.
- The response file in the image-cache key, because the file shapes the
  installed disk.
- One HTTP responder that answers one file to one guest.
- One expect script that starts an autoinstall over the serial console.
- The `-no-reboot` option of QEMU on an autoinstall run.
- `fuguvm image export <path>`, with `--format=qcow2` and `--format=raw`.
- One home for the `qemu-img convert` call.
- The publication of an outside image as a cache entry, so that every existing
  cache verb and snapshot verb keeps working.

Out of scope:

- A generated response file. The response file is the artifact of the consumer,
  and FuguTTX `IAC-IMAGE-1` puts it in the stack directory. The tool must not
  write an answer that the operator did not give.
- A validator of the response file grammar. autoinstall(8) owns that grammar,
  and a second reading of it here would disagree with it one release later.
- A `fuguvm image import <path>` verb. `up` needs the base image anyway, so the
  directive alone reaches it. A verb would be a second way to do one thing.
- An export of the working disk. `fuguvm image export` writes the base disk, so
  the exported image holds no per-checkout SSH key and no scenario state.
- An upload of the image to object storage. FuguTTX `IAC-IMAGE` states that
  `make image-publish` does that with the `scw` CLI.
- A signature or a manifest beside the image. Fugu LIB-SIGNIFY covers
  `Fugu::Signify`, and plan 005 consumes it for the mirror. No consumer asks for
  a signed image export today.
- An `--arch` option on the export. A disk belongs to one architecture for its
  whole life, and the disk guard of `App::FuguVM::Guest` enforces that rule.
- A conversion to VMDK or to VHD. Scaleway takes a qcow2 for the Instance route
  and a raw image for the Elastic Metal route, and `IAC-HOSTS` names both.

## Constraints that shape the design

- **The tool accepts no outside disk today.** `up` gets a disk in exactly two
  ways. The first way is the image cache:

  ```perl
  	# Restore from the installed-image cache when there is no disk yet
  	if ( !$state->disk_exists && defined $cache_key ) {
  		$self->_cache_restore( $cache, $cache_key );
  	}
  ```

  `_cache_restore` accepts one source only, and that source is an entry of the
  cache:

  ```perl
  	my $hit = $cache->lookup($key);
  	if ( !defined $hit ) {
  		$log->info("No cached image for $key, installing");
  		return 0;
  	}
  ```

  `lookup` reads `installed/<key>/base.qcow2`, and only `store` writes there.
  The second way is a blank disk that the installer then fills:
  `$disk->create( $config->{name}, $config->{disk_size} )`. No third way exists.
  An outside file has no key, so `lookup` cannot see it, and FuguTTX
  `IAC-IMAGE-2` is unreachable today.

- **A disk outside the cache cannot be snapshotted.**
  `App::FuguVM::DiskCache->key_for_path` refuses every path outside the cache:

  ```perl
  	my $installed = $self->installed_dir . '/';
  	return if index( $path, $installed ) != 0;
  ```

  `App::FuguVM::CLI::_disk_cache_key` calls it with the backing file of the
  working disk, and `_snapshot_save` then stops:

  ```perl
  "This disk is not built on a cached image, so it cannot be snapshotted."
  ```

  FuguTTX `AGT-FEEDBACK-1` needs `snapshot save` and `snapshot restore` on the
  imported image. `AGT-RUNTIME` states that the host needs "A bootable OpenBSD
  qemu image with snapshot support". An overlay on a file in some download
  directory therefore fails two consumers. The tool must publish the outside
  file as a cache entry, and every existing verb then works unchanged.

- **The cache key must cover the response file.** The key hashes each input that
  shapes an installed disk:

  ```perl
  	my @inputs = (
  		"version=$version",
  		"arch=$arch",
  		"disk_size=$disk_size",
  		'install=' . Digest::SHA::sha256_hex($installer),
  		'generation=' . Digest::SHA::sha256_hex($generation),
  	);
  ```

  The comment of `key` states the contract: "It covers nothing else. Thus memory
  and port changes keep hitting the same entry." A response file answers every
  installer question, so it shapes the disk as much as `install.exp` does. Two
  response files must give two keys, two entry directories and two immutable
  base images.

- **The key must not hash a script that the install never ran.** The `install=`
  input names `install.exp` today, through
  `App::FuguVM::Console->script_path(INSTALL_SCRIPT)`. An autoinstall run does
  not use that script, and an import runs no script at all. The key must
  therefore hash the driver of the mode that runs. An imported entry must
  survive a change to a shipped expect script, because that script never touched
  the image.

- **The record change rotates every key one time.** The record gains an
  `install_mode` input, so each existing key changes once, and each guest
  installs once more. That cost is correct and small. The `arch` change rotated
  every key the same way, because it changed `install.exp`.
  `share/fuguvm/cache-generation` must not change: the record change rotates the
  key by itself.

- **The base image is immutable, compacted and read-only.** `store` sets the
  mode before it publishes the entry: `chmod 0400, $base or do {`. An export
  reads that file, and an import writes one. Neither operation may change an
  existing entry, because entries are write-once.

- **A live overlay is not consistent.** `_snapshot_save` refuses a running
  guest, and its comment gives the reason: "A live overlay is not consistent.
  Thus the command refuses a running VM and does not copy it." An export must
  follow the same rule, with the same exit code. A running QEMU also holds an
  exclusive lock on the working disk.

- **An overlay inherits the size of its base.** `App::FuguVM::Disk->create`
  states it: "The overlay then inherits the virtual size of `$backing_image`."
  The `disk_size` directive therefore shapes an installed disk, and it does not
  shape an imported one. The key of an imported entry must exclude it.

- **The tool cannot know the password of an image that it did not install.**
  `up` generates the password today, `Fugu::Random->random_password(32)`, and
  `_cache_store` records it in the metadata of the entry. A response file sets
  the password itself, and an outside image carries the password of its
  publisher. `_complete_ssh_setup` fails without one:

  ```perl
  			"No root password stored - cannot complete SSH setup");
  ```

  The operator must therefore supply the password, or the guest must trust a key
  already. `_needs_ssh_key_update` covers the second case today:
  `return 0 if !defined $configured_key || $configured_key eq '';`

- **An autoinstall run reboots itself.** `install.exp` answers the last prompt
  with a halt, and it says why: "The `(R)eboot?` prompt marks the end of the
  install. Choose halt instead of reboot. Then fuguvm can restart from the
  installed disk without the miniroot attached." An autoinstall asks nothing, so
  it reboots, and the miniroot is still attached. The guest would install a
  second time. The tool must therefore make the reboot an exit.

- **The proxy port changes on every run.** `Fugu::Proxy->start` takes a free
  port from a range, so a static response file cannot name the proxy. The
  responder must put the live URL into the file that it serves.

- **The mirror cache must hold mirror content only.** The comment of
  `App::FuguVM::Proxy::Cache` states the contract: "Every one of them is
  version-scoped, so nothing here outlives the release it belongs to. That is
  what makes prune safe." A response file is not mirror content. The tool must
  not seed it into that cache, and it must not depend on a `http_proxy` setting
  of the installer to fetch it.

- **The guest reaches the host with no port forward.** QEMU user-mode networking
  puts the host at `10.0.2.2`, and `App::FuguVM::Proxy` already depends on that
  route. The responder therefore needs no `hostfwd` rule.

- **The response file can hold a secret.** A response file answers the root
  password question. The responder must bind the loopback address only, and the
  tool must not copy the file into the cache or into the state directory.

- **Validate each input once, at its boundary.** `App::FuguVM::Config` is the
  boundary of every directive. It validates each path, it rejects each
  contradiction, and no module downstream repeats a check.

## The tool surface

### The install modes

The tool derives the mode from the directives. There is no `install_mode`
directive.

| Directives                            | Mode          | What `up` does                                                      |
| ------------------------------------- | ------------- | ------------------------------------------------------------------- |
| Neither `autoinstall` nor `base_disk` | `expect`      | Install with `install.exp` over the serial console, as today.       |
| `autoinstall <file>`                  | `autoinstall` | Install from the response file. Answer two console prompts only.    |
| `base_disk <path>`                    | `import`      | Publish the file as a cache entry, overlay it, and install nothing. |
| Both                                  | —             | Exit code 3. One guest has one origin.                              |

### The `autoinstall` directive

```
vm "openbsd-amd64" {
	arch         amd64
	version      7.8
	autoinstall  install.conf
	disk_size    8G
}
```

| Rule                | Contract                                                                                    |
| ------------------- | ------------------------------------------------------------------------------------------- |
| Grammar             | One `key value` line, or the `key = value` form. Both come from `Fugu::Config`.             |
| The value           | A path to an autoinstall(8) response file.                                                  |
| A relative path     | Resolves against the project root. A leading tilde expands with `Fugu::File->expand_tilde`. |
| An absent file      | Exit code 3, with a message that names the resolved path.                                   |
| An unreadable file  | Exit code 3.                                                                                |
| An absent directive | The tool installs with `install.exp`, exactly as it does today.                             |
| The cache key       | The bytes of the file enter the key. See the `App::FuguVM::DiskCache` section.              |
| The content         | The tool reads the file, and it validates no answer in it. autoinstall(8) owns the grammar. |

The tool serves the file byte for byte, with one exception. It replaces every
occurrence of the token `@PROXY_URL@` with the guest URL of the mirror proxy.
The substitution happens at serve time. It does not change the cache key,
because a proxy port does not shape the installed disk. The comment of `key`
already states that rule for a port.

A response file with no token installs its sets straight from the mirror. The
download is then not cached, and a second installation pays for it again.

### How the response file reaches the guest

`up` follows this order in the `autoinstall` mode:

1. `up` starts the mirror proxy, as it does today. `_ensure_proxy` already runs
   before the install.
2. `up` starts the responder. The responder binds `127.0.0.1` and takes a free
   port from 8181 to 8280.
3. `up` starts QEMU with the miniroot attached and with `-no-reboot`.
4. `up` runs `autoinstall.exp` over the serial console. The script answers the
   first installer prompt with `a`, and it then types the response-file URL.
5. The guest fetches `http://10.0.2.2:<port>/install.conf`. The QEMU gateway
   carries the request to the responder, and no port forward is needed.
6. The installer applies every answer of the file. The guest fetches its sets
   through the mirror proxy, because the `@PROXY_URL@` token named it.
7. The install ends and the guest reboots. `-no-reboot` makes QEMU exit instead,
   so the guest cannot install a second time.
8. `up` publishes the disk as a cache entry, exactly as it does today.
9. `up` stops the responder. `down` and `destroy` also stop it.

`up` must stop the responder on every path out of the install, and a failed
install is one of those paths. QEMU exits by itself in step 7, so `_qmp_quit`
finds no monitor and returns 0. `_wait_exit` then returns 1 for a process that
is already gone, and the capture proceeds. The existing code needs no change for
that case.

### App::FuguVM::Autoinstall, a new module

The module holds the response file and the responder. It uses core Perl and
`Fugu::` only, and it loads no other module of the distribution except
`App::FuguVM::Proxy`, for the gateway address.

| Constant        | Value                                       |
| --------------- | ------------------------------------------- |
| `RESPONSE_PATH` | `/install.conf`                             |
| `PORTS`         | `[ 8181, 8280 ]`, one range above the proxy |
| `BIND_ADDRESS`  | `127.0.0.1`                                 |
| `PROXY_TOKEN`   | `@PROXY_URL@`                               |
| `READY_TIMEOUT` | 10 seconds                                  |

| Method                                | Contract                                                                                                                                      |
| ------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| `new(%args)`                          | Take `file`, `pidfile`, `store`, `proxy_url`, `logfile` and `log`. Open nothing.                                                              |
| `path`                                | Return the response-file path.                                                                                                                |
| `start`                               | Take a free port, spawn the child, record the PID and the port, and wait until the port answers. Return the port, or `undef` with the reason. |
| `stop`                                | Stop the child and forget the port. Return 1.                                                                                                 |
| `is_running`                          | Report whether the child is alive. The check reaps first.                                                                                     |
| `port`                                | Return the recorded port, or `undef`.                                                                                                         |
| `error`                               | Return the reason of the last failed `start`, or `undef`.                                                                                     |
| `guest_url`                           | Return `http://` with `App::FuguVM::Proxy::HOST_GATEWAY`, the port, and `RESPONSE_PATH`.                                                      |
| `run_child($port, $file, $proxy_url)` | The entry point of the child. Serve the file until a `SIGTERM`.                                                                               |
| `render($bytes, $proxy_url)`          | Return the bytes with every `PROXY_TOKEN` replaced. The method is pure, so a test proves it with no socket.                                   |

`start` follows the shape of `Fugu::Proxy->start`, which spawns its child the
same way: `code => "use $child; $child->run_child(\@ARGV)"`. It uses
`Fugu::Process->spawn_perl`, `Fugu::Pidfile`, `Fugu::StateFile` and
`Fugu::Timeout::wait_until`. The module must not run a shell, because the
command is a list.

The child answers one path:

| Request                   | Answer                                                       |
| ------------------------- | ------------------------------------------------------------ |
| `GET /install.conf`       | 200, with the rendered bytes and `Content-Type: text/plain`. |
| `HEAD /install.conf`      | 200, with the headers only.                                  |
| Any other path            | 404.                                                         |
| Any other method          | 405.                                                         |
| A request line above 8 KB | 400, and the child closes the connection.                    |

The child reads the request line, and it reads nothing else. It sets
`Content-Length` and `Connection: close` on every answer. It must not log the
file content, and it must not write the file to disk. It uses
`IO::Socket::INET`, which is core Perl, so `t/fuguvm/boundary.t` stays green.

### The `base_disk` directive

```
vm "scenario-1" {
	arch      amd64
	version   7.8
	base_disk ~/images/openbsd-78-amd64.qcow2
}
```

| Rule                              | Contract                                                                                                      |
| --------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| The value                         | A path to a full-disk image. `qemu-img` reads a qcow2 file and a raw file.                                    |
| A relative path                   | Resolves against the project root. A leading tilde expands.                                                   |
| An absent file                    | Exit code 3, with a message that names the resolved path.                                                     |
| `image_cache no`                  | Exit code 3. An imported base needs the cache, because the cache is where the entry lives.                    |
| With `autoinstall`                | Exit code 3.                                                                                                  |
| The first `up`                    | Publish the file as the cache entry of the derived key, then overlay the working disk on the published entry. |
| A later `up`                      | The entry exists, so `up` overlays it and reads the file no more.                                             |
| The source file                   | Read-only to the tool. The tool must not write to it and must not remove it.                                  |
| A cache miss and an absent source | Exit code 1, with a message that names the path and the key.                                                  |
| Several guests                    | Every guest of the project derives the same key, so one entry serves the whole fleet.                         |

The publication costs one `qemu-img convert` of the whole image, and it happens
one time for each host. The image cache locks the first population of one entry.
With that lock a parallel fleet publishes one time, and each other guest waits
and then overlays.

### `fuguvm image export`

```
fuguvm image export <path> [--format=qcow2|raw]
```

| Rule                           | Contract                                                                                                    |
| ------------------------------ | ----------------------------------------------------------------------------------------------------------- |
| The source                     | The base image of the cache entry that backs the working disk.                                              |
| A standalone disk              | The working disk itself. Such a disk comes from `--no-cache` or from `image_cache no`.                      |
| A running guest                | Exit code 5. A live overlay is not consistent, and `snapshot save` refuses a running guest for that reason. |
| An existing target             | Exit code 1. The tool must not overwrite an image that an operator published.                               |
| A missing path argument        | Exit code 2.                                                                                                |
| An unknown `--format` value    | Exit code 2. The message names `qcow2` and `raw`.                                                           |
| An absent parent directory     | Exit code 1. The tool creates no directory for the operator.                                                |
| A guest with no installed disk | Exit code 1.                                                                                                |
| The write                      | One temporary sibling, `<path>.tmp.<pid>`, and then one rename. A failure leaves no partial file behind.    |
| The default format             | `qcow2`.                                                                                                    |
| The raw form                   | Sparse. The apparent size is the virtual size of the disk.                                                  |

The source resolution uses three methods that exist today:

- `App::FuguVM::Disk->backing_file` returns the backing file of the working
  disk.
- `App::FuguVM::DiskCache->key_for_path` returns the key of the entry that holds
  it.
- `App::FuguVM::DiskCache->base_path` returns the base image of that key.

A snapshot layer resolves to the same key. The reason is that `key_for_path`
accepts a snapshot path: "The path can point to a base image or to a snapshot."

The command writes one `key: value` line for each field to standard output, in
sorted key order:

| Key      | Value                                          |
| -------- | ---------------------------------------------- |
| `bytes`  | The size of the written file                   |
| `format` | `qcow2` or `raw`                               |
| `key`    | The cache key of the source, or an empty value |
| `path`   | The absolute path of the written file          |
| `source` | The absolute path of the source image          |

The report uses the printer of `fuguvm status`. That printer writes to standard
output, and it holds the stable-key rule.

### The credentials of an installed image

The tool generates a root password only in the `expect` mode. In the
`autoinstall` mode the response file owns every credential. In the `import` mode
the publisher of the image owns them.

| Configuration                                                             | What `up` does                                                                        |
| ------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| A mode other than `expect`, with `ssh_pubkey` and `root_password_file`    | Read the password from the file, store it, and install the key over a password login. |
| A mode other than `expect`, with no `ssh_pubkey`                          | Wait for SSH with the key of the operator. The image must trust that key already.     |
| A mode other than `expect`, with `ssh_pubkey` and no `root_password_file` | Exit code 3. The message names both remedies.                                         |

`root_password_file <path>` names a file whose first line is the password. The
tool reads the file where it needs the secret, and `App::FuguVM::Config`
validates the path only. Thus the secret has a short life in the process, and no
configuration hash carries it. The tool logs a warning when the file mode lets a
group or another user read it.

A published image and a consuming host therefore share one credential:

- The response file of the build sets the root password.
- The stack keeps the password in a file.
- Each consuming host names that file.

The tool then installs the key of the host over a password login, exactly as it
does after a local install.

### The four requirements of FuguTTX IAC-HOSTS

`IAC-HOSTS` states four requirements on a project-built image. Each one has one
owner.

| Requirement                                                        | Who meets it                   | How                                                                                                                                                                                                                                                                  |
| ------------------------------------------------------------------ | ------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| UEFI boot, with a loader at `\EFI\Boot\bootx64.efi`                | The tool and the response file | The `arch amd64` directive gives the amd64 machine and the x86 EFI firmware. The response file must answer the disk-layout question with the whole-disk GPT choice. The installer then makes the EFI system partition, and installboot(8) writes the loader into it. |
| A full disk image, not an ISO and not a root file system           | The tool                       | `fuguvm image export` converts the whole base disk. The image holds the partition table, the EFI system partition and every OpenBSD partition. `--format=raw` writes the form that the Elastic Metal route needs.                                                    |
| A root device set by DUID                                          | The OpenBSD installer          | The installer writes DUID entries into `/etc/fstab`. The tool must not change them, and the response file must not answer over them. One acceptance step reads `/etc/fstab` in the guest.                                                                            |
| An `rc.local` that reads `http://169.254.42.42/conf` with `ftp(1)` | The response file              | The response file must name a `siteXX.tgz` set that carries the file, or an `install.site` script that writes it. The tool copies no file into the guest, and the exported base disk holds only what the installer wrote.                                            |

The last row carries an open question. The tool serves the response file and no
other file, so a site set needs its own location. Open question 3 names the
fallback.

### App::FuguVM::Config

| Method                  | Change                                                                                                                                                                       |
| ----------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `load_vm($name)`        | Resolve and validate `autoinstall`, `base_disk` and `root_password_file`. Derive `install_mode`. Return `undef` and record the reason on any invalid value or contradiction. |
| `_resolve_path($value)` | A new private method. Expand a tilde, then make a relative path absolute against the project root.                                                                           |
| `error`                 | The existing accessor. This plan reports every new reason through it.                                                                                                        |

`App::FuguVM::CLI` reads the reason through its existing `load_exit` field, so
an invalid directive gives 3 and an undeclared guest still gives 4.

The `install_mode` value of the returned hash is `expect`, `autoinstall` or
`import`. Every module downstream reads that one field, and no module compares
the directives again.

### App::FuguVM::DiskCache

| Method or constant      | Change                                                                                                                       |
| ----------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `AUTOINSTALL_SCRIPT`    | A new constant, `autoinstall.exp`, beside `INSTALL_SCRIPT`.                                                                  |
| `key($vm_config)`       | Read `install_mode`, and build the record of that mode. Return `undef` when an input cannot be read, exactly as it does now. |
| `_driver_script($name)` | `_install_script` under its true name. It resolves a shipped script through `App::FuguVM::Console->script_path`.             |
| `_convert`              | Deleted. `App::FuguVM::Disk->convert` becomes the one home of `qemu-img convert`.                                            |

The record of each mode:

| Mode          | Hashed inputs                                                                                                                                                   | Key string                 |
| ------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------- |
| `expect`      | `version`, `arch`, `disk_size`, `install_mode=expect`, the digest of `install.exp`, the digest of the generation file                                           | `<version>-<arch>-<hash8>` |
| `autoinstall` | `version`, `arch`, `disk_size`, `install_mode=autoinstall`, the digest of `autoinstall.exp`, the digest of the response file, the digest of the generation file | `<version>-<arch>-<hash8>` |
| `import`      | `version`, `arch`, `install_mode=import`, the digest of the generation file                                                                                     | `<version>-<arch>-<hash8>` |

The `import` record holds no script digest and no `disk_size`, and the plan
states why above. No script shaped the image, and an overlay inherits the
virtual size of its base. An imported entry therefore survives a change to a
shipped expect script, and each host of a fleet derives one key.

Each mode keeps the key shape, so `entry_dir`, `lookup`, `store`,
`key_for_path`, `snapshot_store` and `sweep_temp` need no change. Every `cache`
verb and every `snapshot` verb then works on an imported entry, and
`cache clear --stale` keeps it, because `_current_cache_key` derives the same
key.

### App::FuguVM::Disk

| Method                             | Change                                                                                                                                                                                                                                       |
| ---------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `convert($source, $target, %opts)` | A new method, and the one home of `qemu-img convert`. `format` is `qcow2` or `raw`, and the default is `qcow2`. `backing` names a parent, and the call then adds `-B` and `-F qcow2`. Return the target path, or `undef` after a diagnostic. |

The method runs the command with `Fugu::Process->run`, like every other method
of the module. The deleted `_convert` of `App::FuguVM::DiskCache` used
`system(@cmd)`, which captures nothing, so a failure printed the raw `qemu-img`
message.

### App::FuguVM::Guest

| Method                       | Change                                                                                                                                                                                                       |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `up`                         | Publish the base disk in the `import` mode before the cache restore. Drive the autoinstall in the `autoinstall` mode. Generate no root password outside the `expect` mode. Stop the responder on every path. |
| `_import_base($cache, $key)` | A new method. Publish `base_disk` with `$cache->store`, and record `imported_from` and the mode in the metadata. Return 1 on success.                                                                        |
| `_autoinstall`               | A new method. Build the `App::FuguVM::Autoinstall` object over the state and the proxy URL.                                                                                                                  |
| `_stop_autoinstall`          | A new method. Stop the responder when it runs. It follows `_stop_proxy`.                                                                                                                                     |
| `_root_password`             | A new method. Return the generated password in the `expect` mode, and the first line of `root_password_file` in every other mode.                                                                            |
| `_start_qemu`                | Add `-no-reboot` when the install media is attached and the mode is `autoinstall`.                                                                                                                           |
| `down`, `destroy`            | Stop the responder, as they stop the proxy today.                                                                                                                                                            |

The metadata of an imported entry holds no root password, so `_cache_restore`
seeds the installed mark and no password. That is correct: the tool must not
invent a credential for an image that it did not install.

### App::FuguVM::Console

| Method                     | Change                                                                                                  |
| -------------------------- | ------------------------------------------------------------------------------------------------------- |
| `run_autoinstall($config)` | A new method. Run `autoinstall.exp` with the response-file URL. It calls `_expect`, like `run_install`. |

The method must not use `run_script`, because `run_script` needs the execute bit
and an installed share tree does not keep it. `App::FuguVM::Miniroot` records
the same fact for the `ftp` helper.

### App::FuguVM::State

| Method                | Change                                                                             |
| --------------------- | ---------------------------------------------------------------------------------- |
| `autoinstall_pidfile` | A new method. Return the `Fugu::Pidfile` of the responder, beside `proxy_pidfile`. |

The PID file lives in the state directory of the guest, so an interrupted run
leaves no listener that nothing owns. flock(2) is not involved here: the
responder is a child with a PID file, exactly like the proxy child.

### App::FuguVM::CLI

| Element         | Change                                                                                                                         |
| --------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `%COMMANDS`     | A new `image` entry: the summary, the usage `export <path> [--format=...]`, the option `format=s`, and the method `cmd_image`. |
| `cmd_image`     | A new method. Accept the `export` action only, and give exit code 2 for every other word. It follows `cmd_snapshot`.           |
| `_image_export` | A new method. Resolve the source, refuse a running guest, convert, rename, and report.                                         |
| `cmd_init`      | Write no new directive. The generated `vms/default.conf` installs with the shipped script, which is the default.               |

The export lives in `App::FuguVM::CLI`, beside the snapshot verbs. Those verbs
already resolve a cache key from a working disk, with `_disk_cache_key` and
`_current_cache_key`, and the export needs the same resolution.

### share/fuguvm/expect/autoinstall.exp

The script takes `<host> <port> <url>`. `App::FuguVM::Console::_expect` passes
the host and the port first, and the URL follows. The script reads
`FUGUVM_TIMEOUT` from the environment, as the other scripts do.

| Step | Prompt                               | Answer              |
| ---- | ------------------------------------ | ------------------- |
| 1    | The telnet connection line           | One carriage return |
| 2    | The install prompt                   | `a`                 |
| 3    | The response-file location prompt    | The URL             |
| 4    | The completion line of the installer | Exit 0              |

The script exits 1 on a timeout, and it exits 1 on an end of file before step 4.
It exits 0 on an end of file after step 4, because `-no-reboot` makes QEMU exit
and the console then closes. The script answers nothing else: the response file
answers every installer question.

### Exit codes

| Code | Cause                                                                                                                                                |
| ---- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1    | The target of an export exists. The export failed. The base disk of an import is absent at a cache miss.                                             |
| 2    | `image` with no action, with no path, or with an unknown `--format` value.                                                                           |
| 3    | An absent or unreadable `autoinstall` file. An absent `base_disk` file. Two origins. `base_disk` with `image_cache no`. A key with no password file. |
| 5    | An export of a running guest.                                                                                                                        |
| 9    | The autoinstall expect script failed. `EXIT_EXPECT_FAILED` already carries that meaning.                                                             |

Code 1 is `EXIT_ERROR`, code 2 is `EXIT_INVALID_ARGS`, code 3 is
`EXIT_CONFIG_ERROR` and code 5 is `EXIT_VM_RUNNING`. `App::FuguVM::CLI` imports
each one from `Fugu::CLI` or defines it today, and this plan adds no number.

## Load contract

The change adds no CPAN module, and it needs no `cpanfile` line.
`App::FuguVM::Autoinstall` uses `IO::Socket::INET`, `Digest::SHA` and `Fugu::`
only, and each of the first two is core Perl. `t/fuguvm/boundary.t` proves the
rule for every module under `lib/App`.

The change adds no external program. `qemu-img` and `expect` are runtime
dependencies today, and each `deps/` manifest names them. No manifest changes.

## Files

| File                                                                                                                     | Content                                                                                                    |
| ------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------- |
| `lib/App/FuguVM/Autoinstall.pm`                                                                                          | The new module: the response file and the responder                                                        |
| `lib/App/FuguVM/Autoinstall.pod`                                                                                         | The API sidecar of the new module                                                                          |
| `lib/App/FuguVM.pod`                                                                                                     | One index entry for `App::FuguVM::Autoinstall`                                                             |
| `lib/App/FuguVM/Config.pm`                                                                                               | The three directives, `_resolve_path`, and the derived `install_mode`                                      |
| `lib/App/FuguVM/Config.pod`                                                                                              | The three directives, the modes, and each refusal                                                          |
| `lib/App/FuguVM/DiskCache.pm`                                                                                            | `AUTOINSTALL_SCRIPT`, the record of each mode, `_driver_script`, and the deletion of `_convert`            |
| `lib/App/FuguVM/DiskCache.pod`                                                                                           | The key inputs of each mode                                                                                |
| `lib/App/FuguVM/Disk.pm`                                                                                                 | `convert`                                                                                                  |
| `lib/App/FuguVM/Disk.pod`                                                                                                | `convert`                                                                                                  |
| `lib/App/FuguVM/Guest.pm`                                                                                                | The install modes, `_import_base`, `_autoinstall`, `_stop_autoinstall`, `_root_password`, and `-no-reboot` |
| `lib/App/FuguVM/Guest.pod`                                                                                               | One section on the install modes and the credentials                                                       |
| `lib/App/FuguVM/Console.pm`                                                                                              | `run_autoinstall`                                                                                          |
| `lib/App/FuguVM/Console.pod`                                                                                             | `run_autoinstall` and its argument list                                                                    |
| `lib/App/FuguVM/State.pm`                                                                                                | `autoinstall_pidfile`                                                                                      |
| `lib/App/FuguVM/State.pod`                                                                                               | `autoinstall_pidfile`                                                                                      |
| `lib/App/FuguVM/CLI.pm`                                                                                                  | The `image` command, `cmd_image` and `_image_export`                                                       |
| `lib/App/FuguVM/CLI.pod`                                                                                                 | The `image` command and its exit codes                                                                     |
| `share/fuguvm/expect/autoinstall.exp`                                                                                    | The new expect script                                                                                      |
| `share/fuguvm/fuguvm.conf.sample`                                                                                        | One commented `autoinstall` line and one commented `base_disk` line                                        |
| `share/fuguvm/vms/default.conf.sample`                                                                                   | One commented `autoinstall` line                                                                           |
| `man/fuguvm/fuguvm.1`                                                                                                    | Six edits, listed below                                                                                    |
| `CLAUDE.md`                                                                                                              | The layout list gains the autoinstall module                                                               |
| `README.md`                                                                                                              | One line in the quick start, if the file lists the verbs                                                   |
| `t/fuguvm/autoinstall.t`                                                                                                 | The new unit test                                                                                          |
| `t/fuguvm/config.t`, `t/fuguvm/diskcache.t`, `t/fuguvm/disk.t`, `t/fuguvm/guest.t`, `t/fuguvm/state.t`, `t/fuguvm/cli.t` | The tests below                                                                                            |

`share/fuguvm/cache-generation` must not change. `scripts/dist` finds every
module under `lib/` and builds the `MANIFEST` from the staged tree, so the
release needs no manifest edit.

The six edits of `man/fuguvm/fuguvm.1`:

1. `DESCRIPTION`: add the `image` command to the command list, with the `export`
   action and the `--format` option.
2. `DESCRIPTION`: state the three install modes under the `up` command.
3. `IMAGE CACHE`: replace the key-input paragraph. Name the inputs of each mode,
   and state that an imported entry hashes no script.
4. `IMAGE CACHE`: add one paragraph on an imported entry. State that the entry
   is write-once, like every other entry, and that its snapshots work the same
   way.
5. `FILES`: add `autoinstall`, `base_disk` and `root_password_file` to the
   per-VM key list.
6. `EXIT STATUS` and `SECURITY CONSIDERATIONS`: extend item 1, item 2 and item 3
   with the causes of this plan. State that the responder binds the loopback
   address, and that a response file can hold the root password.

## Tests

Every test uses `Test::More` with `done_testing()`, and each one mirrors a test
that stands in `t/fuguvm/` today.

`t/fuguvm/autoinstall.t` proves:

- `render` replaces every `@PROXY_URL@` token, and it changes nothing else.
- `render` returns the bytes unchanged when the file holds no token.
- `guest_url` names the gateway address, the recorded port and `/install.conf`.
- `start` returns a port, and the port answers a `GET /install.conf` with the
  rendered bytes and a correct `Content-Length`.
- The responder answers 404 for another path, and 405 for a `POST`.
- The responder listens on the loopback address, and a connection to another
  local address fails.
- `stop` ends the child, and `is_running` then returns 0.
- `port` returns `undef` after `stop`.
- The test skips gracefully when it cannot bind a port in the range.

`t/fuguvm/config.t` proves:

- `autoinstall` resolves a relative path against the project root, and it
  expands a tilde.
- `install_mode` is `expect`, `autoinstall` or `import` for the three
  configurations.
- An absent `autoinstall` file makes `load_vm` return `undef`, and `error` names
  the resolved path.
- An absent `base_disk` file behaves the same way.
- `autoinstall` with `base_disk` returns `undef`, and `error` names both
  directives.
- `base_disk` with `image_cache no` returns `undef`.
- `ssh_pubkey` with no `root_password_file` returns `undef` in the `autoinstall`
  mode and in the `import` mode, and it loads in the `expect` mode.
- `error` returns `undef` after a load that succeeds.

`t/fuguvm/diskcache.t` proves:

- The key of an `autoinstall` configuration differs from the key of an `expect`
  configuration that is equal in every other field.
- The key changes when one byte of the response file changes.
- The key holds when the `disk_size` of an `import` configuration changes, and
  it changes when the version changes.
- `key` returns `undef` when the response file cannot be read.
- `store` publishes an outside image as an entry, and `lookup` then finds it.
- `key_for_path` resolves the base image of an imported entry, so a snapshot of
  that entry is possible.
- `snapshot_store` and `snapshot_lookup` work over an imported entry.
- A second `store` under one key returns `undef`, and the first entry stays.

`t/fuguvm/disk.t` proves:

- `convert` writes a qcow2 file, and `info` reports the qcow2 format.
- `convert` with `format => 'raw'` writes a raw file.
- `convert` with `backing` records the parent, and `backing_file` reads it back.
- `convert` returns `undef` for an absent source, and it writes no target.

`t/fuguvm/guest.t` proves:

- `_start_qemu` adds `-no-reboot` for an `autoinstall` run with install media.
- `_start_qemu` adds no `-no-reboot` for the restart with no media, and none in
  the `expect` mode.
- `_root_password` returns the first line of `root_password_file`, with no
  trailing newline.
- `_root_password` generates a password in the `expect` mode only.

`t/fuguvm/state.t` proves that `autoinstall_pidfile` returns a `Fugu::Pidfile`
under the state directory of the guest, and that its path differs from the proxy
PID file.

`t/fuguvm/cli.t` proves:

- `image` with no action exits 2, and `image export` with no path exits 2.
- `image export` with an unknown `--format` value exits 2.
- `image export` onto an existing file exits 1, and the file stays unchanged.
- `image export` of a guest whose PID file holds a live process exits 5. The
  test writes its own process ID, because `Fugu::Process->is_alive` then reports
  a live guest.
- `image export` of a guest with no disk exits 1.

## Acceptance

- `make check` passes: `make lint`, `make test` and `make tidy`.
- `t/scripts/symbols.t` passes: every public sub has a caller in `lib/`, in
  `bin/`, or in a test.
- `t/fuguvm/boundary.t` passes: `App::FuguVM::Autoinstall` adds no CPAN import
  and no `Protocol::` import.
- `make prettier` passes for the Markdown changes.
- `mandoc -Tlint man/fuguvm/fuguvm.1` reports nothing.
- One recorded autoinstall transcript for an amd64 guest. The transcript must
  show the install prompt, the response-file prompt, the fetch of the file, and
  the completion line. A transcript is the only proof that an installer prompt
  reads as the plan states.
- The guest log of that run must show the request line of the responder. The
  responder must show one 200 answer and no other answer.
- `fuguvm up` with an `autoinstall` directive, then `fuguvm disk check`, reports
  `ok`. The `-no-reboot` exit must leave a consistent disk.
- The image cache holds one entry for the `expect` mode and one for the
  `autoinstall` mode at the same time. Each base image is mode 0400.
- `fuguvm image export /tmp/openbsd.qcow2` writes the file, and `qemu-img info`
  reports the qcow2 format and no backing file.
- `fuguvm image export /tmp/openbsd.raw --format=raw` writes a raw file, and a
  second export onto the same path exits 1.
- A second project with `base_disk /tmp/openbsd.qcow2` runs `fuguvm up`, and
  `fuguvm ssh "uname -m"` prints `amd64`. The project installs nothing, and the
  QEMU log shows no install media.
- `fuguvm snapshot save base` and `fuguvm snapshot restore base` both succeed on
  that imported guest. FuguTTX `AGT-FEEDBACK-1` needs both.
- In the guest of the exported image, `/etc/fstab` names a DUID for the root
  device.
- In the guest of the exported image, the EFI system partition holds the loader
  at `/efi/boot/bootx64.efi`. That is the path that FuguTTX `IAC-HOSTS` writes
  as `\EFI\Boot\bootx64.efi`.
- The exported qcow2 file boots under QEMU with the amd64 EFI firmware, from a
  directory outside the project. An image that boots only in its own cache entry
  is not a published image.

## Open questions

1. **The two console prompts.** The plan states that the installer offers an
   autoinstall at its first prompt. It then asks for the location of the
   response file. The exact text of both prompts must come from a transcript.
   The expect script matches on a prefix, so a small difference costs one script
   edit and one cache-key rotation.
2. **The loopback bind.** The plan binds the responder to `127.0.0.1`, because
   the guest reaches the host through the QEMU gateway. One guest fetch must
   prove that route to a loopback-only listener. If it fails, the responder must
   bind the address that the QEMU network reaches. The plan must then state that
   the file is readable on that address for the length of the install.
3. **The site set of `rc.local`.** `IAC-HOSTS` needs an `rc.local` in the image,
   and an autoinstall response file reaches a file only through a `siteXX.tgz`
   set. The tool serves the response file and no other file. Whether one
   response file can name a second sets location needs a transcript. The
   fallback is a provision after the install. `fuguvm put` and `fuguvm ssh` of
   plan 003 write the file, and the export then needs the working disk. That
   fallback would add `fuguvm image export --from=disk`, which flattens the
   working disk onto the base. This plan does not add that option, and no
   consumer asks for it yet.
4. **The whole-disk GPT answer.** The response file must select a GPT layout, so
   the installer makes the EFI system partition. The expect installer answers
   the question `Use (W)hole disk MBR, whole disk (G)PT or (E)dit?` with `g`,
   and a recorded transcript proves it. The autoinstall(8) form of the same
   answer must come from a test of the response file.
5. **The password file of a published image.** The plan gives the consuming host
   the password through `root_password_file`. A stack that prefers no shared
   password must bake an authorized key into the image, and must then leave
   `ssh_pubkey` unset for that guest. Both shapes work today. FuguTTX must state
   which one `infra/image` publishes, and no rule of the specification names it
   yet.
