# 005 — Mirror coverage: the ports tree, the distfiles, and a verified download

## Status

Proposed. Implements: GST-MIRROR.

This plan depends on Fugu LIB-SIGNIFY, the `Fugu::Signify` module of the Fugu
specification, and this plan is its first consumer. Read that unit first.

The module must reach FuguVM through a Fugu release. Each `deps/` manifest names
the stable asset:

```
runtime dist https://github.com/FuguBSD/Fugu/releases/latest/download/Fugu.tar.gz
```

`make deps` installs that tarball with cpanm. This plan therefore lands after a
Fugu release that carries `Fugu::Signify`.

The Fugu work leaves one question to this plan: who holds the OpenBSD release
keys on a Linux host and on a Darwin host. This plan answers it under "The
signify keys".

The Fugu work also states one test limit, and this plan must honor it: a unit
test cannot cover a real OpenBSD `SHA256` file and its release key. FuguVM
proves that path against a live mirror. The acceptance list below holds that
proof.

`App::FuguVM::Miniroot` holds the mirror host today, and `Miniroot->new` takes
the architecture as an argument:

```perl
use constant { CDN_HOST => 'cdn.openbsd.org', };
```

This plan moves the host into a new mirror module, which takes the version and
the architecture as arguments. The mirror module is then the one home of the
host, the version and the architecture.

Plan 002 is not a dependency. Its `fuguvm status` gains one key here,
`proxy_url`. The key set of `status` must stay stable, so the two plans must
agree on the shape of that report.

Plan 003 is not a dependency. Its `fuguvm put` carries a distfile that no
OpenBSD mirror serves into a guest, and this plan names that route where it
applies.

## Purpose

The mirror proxy caches the file sets and the packages of a release. It caches
no ports tree and no distfile, and it verifies nothing that it downloads. Three
changes close that gap:

1. The cache admits the source tarballs of a release. `ports.tar.gz` is the one
   that a consumer asks for.
2. The cache admits the OpenBSD distfile tree, under a size cap that an operator
   sets. The cap is off by default.
3. The tool verifies each file that it downloads. `Fugu::Signify` proves the
   signed SHA256 manifest of the release, and the installer in the guest stops
   skipping its own check.

## Why FuguVM holds this work

A consumer must never load an `App::FuguVM` module, because a sibling
application is not a library. `fuguvm` is consumable as a tool only: its
subcommands, its output and its exit codes. Every change below is a tool-surface
change.

Fugu holds the generic half of this work already. `Fugu::Proxy` holds the serve
loop, the URL-to-file cache and the metadata table. `Fugu::Signify` holds the
signature check. Neither one holds mirror policy, and the `Fugu::Proxy` sidecar
says so in its CAVEATS:

> The cache has no bound of its own and no expiry. Nothing removes an entry
> until the caller does. A caller whose URLs are version-scoped prunes by
> version; a caller whose URLs are not needs a policy that this module does not
> have.

This plan is that policy. Each piece of the policy is true of an OpenBSD mirror
and of nothing else:

- which URL is worth keeping;
- which key signs which file;
- what bounds a tree that no version scopes;
- which installer prompt the tool must not answer for the operator.

Fugu gains nothing here. The distfile trust chain rests on the ports tree of one
operating system, and the set names rest on one installer.

## Consumers and citations

| Repo       | Unit         | Rules                           | Need                                                                                                                            |
| ---------- | ------------ | ------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| FuguOracle | `ARCH-DEPS`  | ARCH-DEPS-5                     | The build and the regression tests run in the OpenBSD guest. The guest keeps the `comp` set, so it compiles the static program. |
| FuguOracle | `PKG-ORACLE` | PKG-ORACLE-6                    | The developer must build both ports on OpenBSD, and must run each test target there.                                            |
| FuguOracle | `PKG-SECP`   | PKG-SECP-3                      | "The `do-test` target must run the upstream test suite." A port test needs the distfile of the port in the guest.               |
| FuguTTX    | `VAR-CAND`   | none. The unit is `n-a`         | A port evaluation builds the port in a disposable guest. "A port builds, or it does not."                                       |
| FuguTTX    | `INF-ARM64`  | none. The unit holds prose only | The unit rebuilds `devel/libggml` with a new compiler flag, on arm64. A rebuild needs the ports tree and the distfile.          |

Four facts about these citations need a plain statement.

`PKG-SECP-3` exists today, in `FuguOracle/spec/packaging.md`. `ARCH-DEPS-5` and
`PKG-ORACLE-6` do not. `ARCH-DEPS` holds four rules today, and `PKG-ORACLE`
holds five, so each number above is the first free number of its unit. The
specification edit set of this workflow adds both rules.

`VAR-CAND` and `INF-ARM64` carry no numbered rule. The FuguTTX register lists
`VAR-CAND` as `n-a` and `INF-ARM64` as `open`. A rule must not enter an `n-a`
unit, so both rows cite the unit anchor only.

Every row above builds a port in a guest. Each build downloads the whole
distfile set of the port again today, because nothing on the host keeps a
distfile. `INF-ARM64` is the clearest case: it builds `devel/libggml` two times,
with one flag changed between the builds.

No decision blocks a consumer here. `fuguvm` is a development-host tool, like
qemu and the `scw` CLI, and no consumer loads a module from it. FuguTTX D7
therefore permits every row.

FuguPass needs no row. Its `QA-HARNESS` unit runs each leg of its suite in an
OpenBSD guest, under a rule that the edit set adds. It builds no port.

## Scope

In scope:

- The source tarballs of a release as cacheable content: `ports.tar.gz`,
  `src.tar.gz`, `sys.tar.gz` and `xenocara.tar.gz`.
- The `SHA256` and `SHA256.sig` files of the version directory, which sign those
  tarballs.
- The OpenBSD distfile tree as cacheable content, under one size cap.
- One `distfile_cache <size>` directive, one `verify <yes|no>` directive, and
  one `signify_dir <path>` directive.
- `App::FuguVM::Mirror`, a new module: the mirror URLs, the download helper, the
  key resolution and the verification.
- `trim_distfiles`, the eviction that holds the distfile tree under the cap.
- `fuguvm mirror fetch <file>` and `fuguvm mirror verify`.
- One `proxy_url` key in the report of `fuguvm status`.
- One `Distfiles:` line in the report of `fuguvm cache list`.
- The public keys of the supported releases, in the share tree.
- The end of the verification waiver in `share/fuguvm/expect/install.exp`.

Out of scope:

- A change to `Fugu::Proxy` or to `Fugu::Signify`. Both hold what this plan
  needs. The mirror policy lives here.
- A verification of a distfile by the host. The `distinfo` file of the port
  holds each distfile digest, the host verified the ports tree, and the guest
  runs the check. The chain closes in the guest.
- A verification of a package by the host. Each package carries its own signify
  signature, and `pkg_add` in the guest verifies it.
- An expiry by time. Nothing in this repository knows when a file stops being
  useful. A size cap and a version prune are the two bounds, and both are
  deterministic.
- A cache of an upstream distfile site. Such a site serves https, and the proxy
  caches no https body. See the constraints.
- A `/etc/mk.conf` in the guest, and an `http_proxy` in the guest environment. A
  ports build is consumer policy. The tool reports the proxy URL, and the
  consumer passes it.
- A mirror directive. `cdn.openbsd.org` stays the one host. No consumer asks for
  a second one, and a mirror choice would multiply the trees under `cache_dir`.
- A snapshot release, and `-current`. A snapshot carries the key of the next
  release, so the version-to-key rule of this plan does not hold for it.
- A new exit code. The plan reuses the codes that `fuguvm(1)` documents.

## Constraints that shape the design

**The cache admits eight patterns today.** `App::FuguVM::Proxy::Cache` holds the
whole mirror policy in one list, at line 87 of `lib/App/FuguVM/Proxy.pm`:

```perl
my @CACHEABLE = (
	qr{/pub/OpenBSD/\d+\.\d+/\w+/.*\.(tgz|img|gz)$},    # File sets
	qr{/pub/OpenBSD/syspatch/.*\.tgz$},                 # Patches
	qr{/pub/OpenBSD/\d+\.\d+/packages/\w+/.*\.tgz$},    # Packages
	qr{/pub/OpenBSD/\d+\.\d+/\w+/SHA256(\.sig)?$},      # Checksums
	qr{/pub/OpenBSD/\d+\.\d+/\w+/miniroot\d+\.img$},    # Miniroot images
	qr{/pub/OpenBSD/\d+\.\d+/\w+/bsd(\.mp|\.rd)?$},     # Kernel files
	qr{/pub/OpenBSD/\d+\.\d+/\w+/BUILDINFO$},           # Build info
	qr{/pub/OpenBSD/\d+\.\d+/\w+/.*\.txt$},    # Text files (index, etc)
);
```

Seven of the patterns name a version, and each of those seven names an
architecture after it. The syspatch pattern is the eighth, and the component
after `syspatch` is the version. The comment above the list states the reason:
"Every one of them is version-scoped, so nothing here outlives the release it
belongs to. That is what makes prune safe."

**The two gaps are gaps of path shape.** A ports tree sits at
`/pub/OpenBSD/<version>/ports.tar.gz`. The path holds a version, and it holds no
architecture component, so the first pattern cannot match it. That pattern needs
a `\w+` between the version and the file name. A distfile sits under
`/pub/OpenBSD/distfiles/`, and that path holds no version at all.

The manifest of the source tarballs has the same shape problem. It sits at
`/pub/OpenBSD/<version>/SHA256`, with its signature beside it. The fourth
pattern needs an architecture component. The cache thus admits the manifest of
the architecture directory, and it refuses the manifest of the version
directory.

**`prune` recognizes a version directory and nothing else.** The method reads
each version root and keeps only what the caller named:

```perl
	for my $version_root ( $self->_version_roots ) {
		opendir my $dh, $version_root or next;
		my @versions = sort grep { /\A[0-9]+\.[0-9]+\z/ } readdir $dh;
		closedir $dh;
```

`_version_roots` returns two directories for each cached host:

```perl
		push @roots, $release;
		push @roots, "$release/syspatch" if -d "$release/syspatch";
```

`$release` is `<root>/<host>/pub/OpenBSD`. The method comment states the safety
argument: "The method does not touch a directory whose name is not a version. In
practice there are none." A cache under `$HOME` is the wrong place to delete on
a guess.

Two results follow, and they differ.

`ports.tar.gz` needs no change to `prune`. The file sits inside the version
directory, and `prune` removes that whole directory with `File::Path`. A version
bump therefore takes the source tarballs with it.

The distfile tree needs a bound of another kind. `distfiles` is not a version
name, so the `grep` above refuses it and `prune` leaves the tree. That behavior
is correct, and it must stay. It also means that no version bump ever frees the
tree. A distfile belongs to a port and not to a release, and a port keeps its
distfile across releases. A version prune would therefore be the wrong rule,
even if the path allowed it.

**A cap is the bound that fits.** The operator sets a size, and the cache holds
the distfile tree under it. Eviction removes the oldest file first, by
modification time. The plan does not use the access time. A host can mount its
home directory with `noatime`, and a wrong order then evicts a file that a build
reads every day. The modification time is the store time of the file, because
`store` writes each file one time.

**The guest verifies its own sets, and the host must let it.**
`share/fuguvm/expect/install.exp` holds this block at lines 183 to 186:

```tcl
    "Continue without verification?" {
        respond "yes"
        exp_continue
    }
```

The installer asks that question when it cannot verify the sets. The script
answers yes, so the guest installs a file set that nothing verified. The
installer of a numbered release carries the release key in `bsd.rd`. The proxy
caches `SHA256.sig` beside each set already, so the installer can verify by
itself. The prompt is therefore a report of a broken mirror, and the tool must
not hide it.

**The host must verify the miniroot, because the guest cannot.** The miniroot is
the boot medium, so no code in the guest inspects it before it runs.
`App::FuguVM::Miniroot::download` tests the size and nothing else:

```perl
	# Make sure that the download wrote a file
	if ( !-f $tmp_path || -z $tmp_path ) {
		warn "Download succeeded but file is empty\n";
		return;
	}
```

The method then calls `store_from_file`, so an unverified image enters the cache
and every later run boots it.

**The trust chain has five links, and the tool owns two of them.**

| Content                               | The signature                                                  | The verifier                             |
| ------------------------------------- | -------------------------------------------------------------- | ---------------------------------------- |
| A file set, a kernel, the miniroot    | `/pub/OpenBSD/<version>/<arch>/SHA256.sig`, under the base key | The host, and the installer in the guest |
| `ports.tar.gz` and the other tarballs | `/pub/OpenBSD/<version>/SHA256.sig`, under the base key        | The host                                 |
| A package                             | An embedded signify signature, under the package key           | `pkg_add` in the guest                   |
| A syspatch set                        | Its own signature, under the syspatch key                      | `syspatch` in the guest                  |
| A distfile                            | The digest line of `distinfo`, in the ports tree               | `make checksum` in the guest             |

The tool verifies the first two rows. The last three rows verify themselves in
the guest, so the tool must not claim them. The distfile row is the reason that
an unsigned distfile cache is still safe:

- The host verified the ports tree.
- The ports tree holds each `distinfo`.
- The guest refuses a distfile that does not match.

**The scheme does not enter the cache path.** `Fugu::Proxy::Cache->cache_path`
maps a URL to `<dir>/proxy/<host>/<path>`, and it drops the scheme. The host can
therefore download over https, and the guest can read the same file over http
through the proxy. `t/fuguvm/proxy.t` proves the layout today: it seeds files
under `cdn.openbsd.org/pub/OpenBSD` and reads back `http://` URLs from `list`.

**An https body never enters the cache.** The serve loop answers `GET` and
`HEAD`, and it forwards every other method with `LWP::UserAgent`. It handles no
`CONNECT` tunnel. A ports build that fetches from an upstream site over https
therefore caches nothing. Only a fetch of `http://cdn.openbsd.org/...` reaches
the cache.

**The proxy child takes two arguments.** `Fugu::Proxy->start` spawns it with a
fixed list:

```perl
		args      => [ $port, $self->{cache}->dir ],
```

The size cap must therefore reach the child another way. The child reads it from
its environment, which it inherits from `fuguvm`. `App::FuguVM::Console` sets
the same precedent: "The scripts read their timeout from FUGUVM_TIMEOUT in the
environment themselves."

**The metadata table needs no invalidation after an eviction.** A
`Fugu::Proxy::Meta` entry "whose file is gone, or whose size or modification
time changed, is not valid and reads as absent". An eviction in the child is
therefore safe between two requests.

**The serve loop handles one client at a time.** A ports fetch is sequential, so
the loop fits it. A parallel `make` in the guest would queue on the proxy, and
the operator must expect that.

**A cache miss holds the whole body in memory.** `_process_request` passes
`$response->content` to `store`. A file set of hundreds of megabytes already
takes that path today, so a distfile adds no new class of cost.

**signify(1) must exist on the host.** `Fugu::Signify->is_available` reports the
truth, and `verify yes` with no signify(1) must fail the run. The command is in
OpenBSD base. It is a package on Linux and on Darwin, so each of those manifests
needs a runtime line.

## The tool surface

### The cacheable patterns

The list gains three patterns:

```perl
	qr{/pub/OpenBSD/\d+\.\d+/(ports|src|sys|xenocara)\.tar\.gz$},
	qr{/pub/OpenBSD/\d+\.\d+/SHA256(\.sig)?$},
	qr{/pub/OpenBSD/distfiles/(?:[^/]+/)*[^/]+$},
```

The first names the four source tarballs. The plan names them, and it uses no
wildcard. A wildcard at the version level would admit any file that a mirror
puts there. The second admits the manifest of the version directory, which signs
those four files. The existing manifest pattern stays, because it admits the
manifest of the architecture directory.

The third admits a distfile. It requires a file name at the end, so a directory
listing with a trailing solidus stays outside the cache. It filters no
extension, because a distfile carries every extension and sometimes none.

The distfile pattern is conditional. `_is_openbsd_content` takes the size cap as
a second parameter, and it admits a distfile URL only when the cap is above
zero. A cache that grows with no bound in a home directory is the failure that
this plan must not create. The default answer is therefore no.

### The `distfile_cache` directive

```
distfile_cache 4G
```

The directive is a global or project setting, beside `cache_dir` and
`image_cache`. The value is a size: a bare number of bytes, or a number with a
`K`, `M` or `G` suffix. The suffix is 1024-based, and the letter case does not
matter. The default is `0`, and `0` turns the distfile cache off.

`App::FuguVM::Config->distfile_cache` returns the cap in bytes. An unparsable
value gives one warning and the value 0. `_bool` sets that precedent for a
switch: an unrecognized spelling must not silently mean its opposite, and the
operator hears about it. Off is also the closed state for a cache, so the
failure is safe.

The cap reaches the proxy child through `FUGUVM_DISTFILE_LIMIT`, which holds the
byte count. `App::FuguVM::Guest` sets the variable before it starts the proxy.
`App::FuguVM::Proxy->run_child` reads it, and it passes the value to the cache.
An absent variable means 0.

### `App::FuguVM::Proxy::Cache`

| Method                              | Change                                                                                                                   |
| ----------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| `new($cache_dir, $limit = 0)`       | Take the distfile cap in bytes. Keep it on the object, and close over it in the `cacheable` callback.                    |
| `_is_openbsd_content($url, $limit)` | Take the cap. Admit a distfile URL only when the cap is above zero.                                                      |
| `store($url, $content)`             | Call the parent, and then call `trim_distfiles` when the URL is a distfile. A set store must not walk the distfile tree. |
| `trim_distfiles`                    | Hold the distfile tree under the cap. Return the removed files as `[ { path, size } ]`.                                  |
| `distfile_size`                     | Return the bytes of the distfile tree, over every cached host.                                                           |
| `distfile_limit`                    | Return the cap in bytes.                                                                                                 |
| `_distfile_roots`                   | Return `<root>/<host>/pub/OpenBSD/distfiles` for each cached host that holds one.                                        |
| `prune(@keep)`                      | No change. `distfiles` is not a version name, so the method leaves the tree. A test must prove that it stays.            |

`trim_distfiles` collects each file with the inherited `walk`, sorts the list by
modification time, and unlinks the oldest until the total fits the cap. A cap of
0 removes the whole tree, because the operator turned the cache off. The method
removes files and leaves the directories, because a later fetch refills them.

The eviction runs in the child, which is the only writer. The cap is therefore
true between two requests, and not only after a run.

### The signify keys

The tool needs the public key of the release that it installs. The version names
the key: 7.8 gives `openbsd-78-base.pub`. The dot goes away, which is the same
transform that `_image_filename` makes for `miniroot78.img`.

`App::FuguVM::Mirror->key_path` resolves the file in this order:

1. The `signify_dir` directive, when the operator set it.
2. `/etc/signify/`, when that directory holds the file. An OpenBSD host holds
   the authentic key from its own installation, which is a better anchor than a
   copy in a repository.
3. `share/fuguvm/signify/`, resolved with `Fugu::File->share_path`, with
   `from => __FILE__` and `dist => 'App-FuguVM'`. A checkout and an installed
   distribution both work.

The method returns `undef` when no directory holds the file, and `error` then
names the key and each directory that it tried.

The share tree holds one file for each release that the tool supports. Today
that is the default release, so it holds `openbsd-78-base.pub`. A key in a
repository is a trust anchor, so a human must add each one. The reviewer must
compare the new file against `/etc/signify/` on an OpenBSD installation of that
release, and must say so in the commit message. The commit that adds a key is
the commit that raises `DEFAULT_VERSION`.

The key list of `Fugu::Signify` holds one key here. The release directory of a
numbered release carries one signature, under the base key of that release. A
second key would therefore accept a file that the version does not own.

### `App::FuguVM::Mirror`, a new module

The module owns the mirror: the host, the URLs, the download helper, the key and
the verification. It uses `Fugu::File`, `Fugu::Log`, `Fugu::Process` and
`Fugu::Signify`, and it adds no CPAN import.

`new(%args)` takes these arguments:

| Argument   | Meaning                                                                        |
| ---------- | ------------------------------------------------------------------------------ |
| `cache`    | An `App::FuguVM::Proxy::Cache`. This argument is necessary.                    |
| `version`  | The OpenBSD version, as `7.8`. This argument is necessary.                     |
| `arch`     | The architecture name, as `arm64`. This argument is necessary.                 |
| `keys_dir` | The directory of the signify public keys. The default is the resolution order. |
| `verify`   | 1 or 0. The default is 1.                                                      |

`new` dies when `cache`, `version` or `arch` is absent. Each one is a
programming error.

| Method                              | Contract                                                                                                                                                             |
| ----------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `host`                              | Return the mirror host. `CDN_HOST` is `cdn.openbsd.org`, and this module is its one home.                                                                            |
| `url($file)`                        | Return `https://<host>/pub/OpenBSD/<version>/<arch>/<file>`.                                                                                                         |
| `source_url($file)`                 | Return `https://<host>/pub/OpenBSD/<version>/<file>`.                                                                                                                |
| `key_path`                          | Return the resolved public key file, or `undef`.                                                                                                                     |
| `fetch($url)`                       | Download the URL to a temporary file with the `scripts/ftp` helper. Return the `File::Temp` object, or `undef`. This is the one home of the helper call.             |
| `manifest($scope)`                  | Make sure that `SHA256` and `SHA256.sig` of the scope are cached, and prove the signature with `Fugu::Signify->verify`. Return the cached manifest path, or `undef`. |
| `verify_file($scope, $name, $path)` | Verify one local file against the manifest of the scope. Return 1, or `undef`.                                                                                       |
| `ensure($scope, $file)`             | Return the cached path of a file. Fetch, verify and store it when the cache misses. Return `undef` on any failure.                                                   |
| `verify_cache`                      | Verify every cached file that the two manifests name. Return `{ ok, failed, unknown }`, each one a sorted list of names.                                             |
| `error`                             | Return the reason of the most recent failure, or `undef`. Every public method clears the reason before it starts.                                                    |

`$scope` is `release` for the architecture directory and `source` for the
version directory. The two scopes have one manifest each, and the module caches
each manifest path for the length of the object.

`ensure` works in this order:

1. It returns the cached path when the cache holds the file.
2. It calls `manifest($scope)`. A failure returns `undef`, and it fetches
   nothing.
3. It calls `fetch` on the URL of the scope.
4. It calls `verify_file` on the temporary path, under the manifest name of the
   file.
5. It calls `store_from_file` on the cache, and it returns the cached path.

The order matters. The file must verify before it enters the cache, because the
cache is what a later run reads. `Fugu::Signify->verify_manifest` accepts a
manifest name that differs from the local path, which is what step 4 needs.

Step 2 and step 4 both prove the signature, because `verify_manifest` proves it
on each call. The double proof is deliberate: step 2 fails a bad key and a bad
signature before any download, and one signify(1) run costs milliseconds.

`verify_cache` makes one `verify_manifest` call for each scope, with every
cached name in one `files` hash. One call verifies the signature one time, so a
tree of a hundred files costs one signify(1) run for each scope. A cached file
that no manifest names is `unknown`: `index.txt` and a package are both in that
class. The module reports them and fails on none of them.

With `verify` set to 0, `ensure` skips step 2 and step 4, and it logs one
warning. `verify_file` and `manifest` then return `undef` with a reason, because
a method must not report a proof that it did not make.

### `App::FuguVM::Miniroot`

| Method                                        | Change                                                                                        |
| --------------------------------------------- | --------------------------------------------------------------------------------------------- |
| `new($cache_dir, $proxy, $mirror)`            | Take the mirror object. It carries the version, the architecture and the verification switch. |
| `ensure($version)`                            | Call `$mirror->ensure('release', $self->_image_filename($version))`.                          |
| `url($version)`                               | Call `$mirror->url` on the image file name.                                                   |
| `download`, `_ftp_script`, `CDN_HOST`, `ARCH` | Delete each one. The mirror module holds the download and the mirror facts.                   |

The module keeps `path`, `ensure`, `_image_path` and `_image_filename`. Its
concern is the install media, and the miniroot file name is part of that
concern. The download and the verification are mirror work, so they move.

The size check of the old `download` goes away with it. A verified digest proves
the size too, and a second check of one invariant belongs nowhere.

`t/scripts/symbols.t` fails on a sub that no module and no test names. The test
of `download` and the test of `_ftp_script` therefore go with the subs.

### `App::FuguVM::Config`

| Method                | Change                                                                                                                                 |
| --------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| `distfile_cache`      | A new method. Return the cap in bytes. Warn and return 0 for an unparsable value.                                                      |
| `verify`              | A new method. Return 1 or 0. The default is 1. It reads the setting with `_bool`.                                                      |
| `signify_dir`         | A new method. Return the resolved directory, or `undef`. It expands a tilde, and it resolves a relative path against the project root. |
| `_parse_size($value)` | A new private helper. Return the byte count, or `undef`.                                                                               |
| `load_vm($name)`      | Carry `verify` and `signify_dir` into the VM hash, in the way that `image_cache` and `cache_dir` arrive today.                         |

`distfile_cache` stays out of the VM hash. The distfile tree is one tree under
`cache_dir`, and each guest of a project shares it, so a per-guest cap would
have no meaning.

### `fuguvm mirror`

```
fuguvm mirror fetch <file>
fuguvm mirror verify
```

`fetch` downloads one file of the release, verifies it, and stores it in the
proxy cache. It writes the cached path to standard output, so a script can read
it. The scope comes from the manifests. The tool uses the `release` scope when
the manifest of the architecture directory names the file, and the `source`
scope otherwise. Both manifests are authoritative lists, so the tool guesses
nothing.

`fuguvm mirror fetch ports.tar.gz` is the call that a consumer makes. The guest
then reads a verified ports tree from the cache, over http, through the proxy.

`verify` verifies every cached file of the version and the architecture of the
invoked guest. It writes one line for each file that failed, and one summary
line with the three counts. It removes each file that failed, because a file
that fails a digest must not stay in a cache that a later run reads. It exits 1
when one file failed, and 0 otherwise. The verb is idempotent: a second run over
a clean cache removes nothing and exits 0.

`verify` must not remove an `unknown` file. A name that no manifest holds is not
a failure, and `index.txt` is such a name on every mirror.

### `fuguvm cache list` and `fuguvm cache clear`

`cache list` gains one line, after the per-version lines:

```
Distfiles: 1.2G of 4.0G
```

The line reads `Distfiles: 1.2G, caching off` when the cap is 0 and the tree
holds bytes. It stays absent when the tree is empty. `_format_size` writes both
sizes, so the line matches every other size in the report.

`_proxy_list` must exclude the distfile tree from the per-version grouping. The
method groups a URL by the version in its path today, and it counts a URL with
no version under `-`. A distfile URL holds no version. Every distfile would land
in that bucket, and it would hide the one URL class of the bucket.

`cache clear` needs no change. `Fugu::Proxy::Cache->clear` removes the whole
mirrored tree, so it takes the distfile tree with it.

`cache clear --stale` keeps the distfile tree, and it calls `trim_distfiles` to
re-apply the cap. A distfile carries no version, so the version rule of
`--stale` cannot decide about it. A refill is also expensive, and the point of
the flag is to keep what the invoked guest needs.

### `fuguvm status`

The report gains one key:

| Key         | Value                                                           |
| ----------- | --------------------------------------------------------------- |
| `proxy_url` | The proxy URL as the guest reaches it, or empty when none runs. |

`App::FuguVM::Proxy->guest_url` returns the value, and it returns `undef` while
the proxy does not run. The key set stays stable, so the key appears on every
run with an empty value when the proxy is stopped.

The guest reaches the proxy at the QEMU gateway, and the port changes between
runs, because `Fugu::Proxy->start` finds a free port. A consumer therefore reads
the URL from `status` and must not write it in a file.

### `share/fuguvm/expect/install.exp`

The script takes one more argument, `verify`, which holds `yes` or `no`. The
block at lines 183 to 186 becomes two branches:

- With `verify` set to `yes` the script must not answer the prompt. It writes a
  diagnostic that names the prompt and the mirror, and it exits 1. The tool
  reports exit code 9, because `EXIT_EXPECT_FAILED` already carries that
  meaning.
- With `verify` set to `no` the script answers yes, and it writes a warning line
  that says the guest installs unverified sets.

The installer of a numbered release verifies each set by itself, so a run with
`verify yes` must never reach that prompt. The prompt then means that the mirror
data is wrong, and a stop is the correct answer.

`App::FuguVM::Console->run_install` passes the flag. The script reads its
arguments by position, so the tool and the script must land in one commit. Plan
001 adds the architecture argument, and this plan adds this one after it.

`share/fuguvm/cache-generation` must not change. The image-cache key already
hashes the contents of `install.exp`, so this edit invalidates every cached
image by itself.

### A ports build in the guest

The tool writes no file in the guest for this. Two lines of guest configuration
make the cache work, and the consumer owns both:

1. `http_proxy` must name the `proxy_url` value of `fuguvm status`. ftp(1) in
   the guest reads that variable. Plan 002 adds the one-key form,
   `fuguvm status proxy_url`, which a `make` target can read with no text
   filter.
2. The ports tree must fetch each distfile from the OpenBSD distfile mirror,
   over http. A fetch from an upstream site over https reaches no cache.

`fuguvm(1)` documents both lines in a new section, with one worked example over
`fuguvm ssh`. A distfile that the OpenBSD mirror does not carry never enters the
cache. A new port with a GitHub distfile is such a case, and `PKG-SECP` is such
a port. A guest snapshot after the fetch is the route that saves that download,
and `fuguvm put` of a host copy is the other.

### Exit codes

| Code | Cause                                                                                                                        |
| ---- | ---------------------------------------------------------------------------------------------------------------------------- |
| 1    | A download failed. A signature failed. A digest failed. `mirror verify` found one bad file. `verify yes` with no signify(1). |
| 2    | `mirror` with no action, with an unknown action, or `mirror fetch` with no file.                                             |
| 3    | An absent or unreadable `signify_dir`. An absent public key for the version.                                                 |
| 9    | The installer asked to continue without verification, and `verify` was `yes`.                                                |

Code 1 is `EXIT_ERROR`, code 2 is `EXIT_INVALID_ARGS`, code 3 is
`EXIT_CONFIG_ERROR` and code 9 is `EXIT_EXPECT_FAILED`. This plan adds no
number. A verification failure is a general error, and no consumer asks for a
code of its own.

## Load contract

The change adds no CPAN module, so the `cpanfile` needs no line.
`App::FuguVM::Mirror` loads `Fugu::File`, `Fugu::Log`, `Fugu::Process` and
`Fugu::Signify`, and each one needs core Perl only. `t/fuguvm/boundary.t` proves
the rule for every module under `lib/App`. `App::FuguVM` uses `Fugu::` and core
Perl, it never uses `Protocol::`, and it never uses another `App::` namespace.

The change adds one external command, signify(1). OpenBSD base holds it, so
`deps/OpenBSD.txt` needs no line. `deps/Linux.txt` and `deps/Darwin.txt` need
one runtime line each:

```
runtime pkg signify-openbsd
```

```
runtime pkg signify-osx
```

The tier is `runtime` and not `test`, because `fuguvm up` verifies a download.
`scripts/deps` installs a Linux `pkg` line with `apt-get install -y`, and a
Darwin `pkg` line with `brew install`.

The Fugu release that this plan needs must carry `Fugu::Signify`. The `dist`
line of each manifest fetches `releases/latest/download/Fugu.tar.gz`. The order
of the two repositories is thus fixed. Fugu releases first, and FuguVM lands
after it.

## Files

| File                                                                                                 | Content                                                                                                                               |
| ---------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| `lib/App/FuguVM/Mirror.pm`                                                                           | The new module: the URLs, the download helper, the key resolution and the verification                                                |
| `lib/App/FuguVM/Mirror.pod`                                                                          | The API sidecar of the new module                                                                                                     |
| `lib/App/FuguVM.pod`                                                                                 | One index entry for `App::FuguVM::Mirror`                                                                                             |
| `lib/App/FuguVM/Proxy.pm`                                                                            | The three patterns, the cap in `new`, the `store` override, `trim_distfiles`, `distfile_size`, `distfile_limit` and `_distfile_roots` |
| `lib/App/FuguVM/Proxy.pod`                                                                           | The new patterns, the cap, the eviction order, and the reason that `prune` leaves the tree                                            |
| `lib/App/FuguVM/Miniroot.pm`                                                                         | The mirror argument, the delegation, and the deletion of `download`, `_ftp_script`, `CDN_HOST` and `ARCH`                             |
| `lib/App/FuguVM/Miniroot.pod`                                                                        | The mirror argument, and the removed methods                                                                                          |
| `lib/App/FuguVM/Config.pm`                                                                           | `distfile_cache`, `verify`, `signify_dir`, `_parse_size`, and the two new VM keys                                                     |
| `lib/App/FuguVM/Config.pod`                                                                          | The three directives, the size grammar, and each refusal                                                                              |
| `lib/App/FuguVM/Guest.pm`                                                                            | The mirror object, the manifest gate before the install, `FUGUVM_DISTFILE_LIMIT`, the verify flag, and `proxy_url` in `status`        |
| `lib/App/FuguVM/Guest.pod`                                                                           | One section on the verification of an install                                                                                         |
| `lib/App/FuguVM/Console.pm`                                                                          | The verify argument of `run_install`                                                                                                  |
| `lib/App/FuguVM/Console.pod`                                                                         | The argument list of `install.exp`                                                                                                    |
| `lib/App/FuguVM/CLI.pm`                                                                              | `cmd_mirror`, `_mirror_fetch`, `_mirror_verify`, the distfile line of `_proxy_list`, and the cap in each cache construction           |
| `lib/App/FuguVM/CLI.pod`                                                                             | The `mirror` command and its exit codes                                                                                               |
| `share/fuguvm/expect/install.exp`                                                                    | The verify argument, and the end of the waiver                                                                                        |
| `share/fuguvm/signify/openbsd-78-base.pub`                                                           | The trust anchor of the default release                                                                                               |
| `share/fuguvm/fuguvm.conf.sample`                                                                    | One commented line for each of the three directives                                                                                   |
| `man/fuguvm/fuguvm.1`                                                                                | Seven edits, listed below                                                                                                             |
| `deps/Linux.txt`                                                                                     | `runtime pkg signify-openbsd`                                                                                                         |
| `deps/Darwin.txt`                                                                                    | `runtime pkg signify-osx`                                                                                                             |
| `deps/OpenBSD.txt`                                                                                   | No change. signify(1) is in base                                                                                                      |
| `cpanfile`                                                                                           | No change. The plan adds no CPAN library                                                                                              |
| `INSTALL.md`                                                                                         | The two package sentences name signify                                                                                                |
| `CLAUDE.md`                                                                                          | The layout list gains the mirror module                                                                                               |
| `t/fuguvm/mirror.t`                                                                                  | The new unit test                                                                                                                     |
| `t/fuguvm/proxy.t`, `t/fuguvm/miniroot.t`, `t/fuguvm/config.t`, `t/fuguvm/cli.t`, `t/fuguvm/guest.t` | The tests below                                                                                                                       |

`scripts/dist` stages every file under `share/`, so the new key file ships with
no manifest edit. `share/fuguvm/cache-generation` must not change.

The seven edits of `man/fuguvm/fuguvm.1`:

1. `DESCRIPTION`: add the `mirror` command, with the `fetch` action and the
   `verify` action.
2. `DESCRIPTION`: extend the `cache` entry. State that `list` reports the
   distfile tree, and that `clear --stale` keeps it under the cap.
3. A new `MIRROR CACHE` section, after `IMAGE CACHE`. State what the cache
   admits, and how the version prune bounds the release trees. State how the cap
   bounds the distfile tree, and which key verifies which file. Hold the trust
   chain table of this plan.
4. The same section: the two guest-side lines of a ports build, with one worked
   example over `fuguvm ssh`.
5. `FILES`: add `distfile_cache`, `verify` and `signify_dir` to the `.fuguvmrc`
   key list, and add `share/fuguvm/signify/`.
6. `EXIT STATUS`: extend item 1, item 3 and item 9 with the causes of this plan.
7. `SECURITY CONSIDERATIONS` and `SEE ALSO`: state that the host verifies each
   download under the release key. State that the guest installer verifies its
   own sets, and that a distfile verifies against the ports tree in the guest.
   Add signify(1) to the reference list.

## Tests

Every test uses `Test::More` with `done_testing()`, and each one mirrors a test
that stands in `t/fuguvm/` today. No test reaches the network.

`t/fuguvm/mirror.t` proves:

- `host` returns `cdn.openbsd.org`.
- `url` builds `https://cdn.openbsd.org/pub/OpenBSD/7.8/arm64/base78.tgz`.
- `source_url` builds `https://cdn.openbsd.org/pub/OpenBSD/7.8/ports.tar.gz`.
- `new` dies without `cache`, without `version`, and without `arch`.
- `key_path` maps 7.8 to `openbsd-78-base.pub`.
- `key_path` prefers the `keys_dir` argument over every other directory.
- `key_path` returns `undef` when no directory holds the key, and `error` names
  the file and each directory.
- `manifest` returns `undef` when the key does not resolve, and it fetches
  nothing.
- `ensure` returns the cached path with no fetch when the cache holds the file.
- `ensure` with `verify` set to 0 stores a file and logs a warning.
- `verify_file` with `verify` set to 0 returns `undef` with a reason.

These subtests need signify(1), and each one calls
`plan skip_all => 'signify(1) not available'` when the command is absent. The
test generates its own key pair with `-G`, and writes a manifest in the
`sha256(1)` line form. It signs the manifest with `-S`, and seeds both files
into the cache at their mirror paths. The manifest is then local, so the module
fetches nothing:

- `manifest('release')` returns the cached path for a good signature.
- `manifest('release')` returns `undef` for a tampered manifest, and `error`
  names the file.
- `verify_file` returns 1 for a file whose digest matches.
- `verify_file` returns `undef` for a file whose digest does not match.
- `verify_file` returns `undef` for a name that the manifest does not hold.
- `ensure` refuses to store a file that fails its digest, and the cache stays
  empty.
- `verify_cache` reports a good file under `ok`.
- `verify_cache` reports a bad file under `failed`.
- `verify_cache` reports a cached file that no manifest names under `unknown`.
- `manifest('source')` verifies the manifest of the version directory.

`t/fuguvm/proxy.t` proves:

- `ports.tar.gz`, `src.tar.gz`, `sys.tar.gz` and `xenocara.tar.gz` of a version
  are cacheable.
- The `SHA256` and the `SHA256.sig` of a version directory are cacheable.
- A distfile URL is cacheable with a cap above 0.
- The same URL is not cacheable with a cap of 0.
- A distfile URL that ends with a solidus is not cacheable.
- A distfile URL in a subdirectory of `distfiles` is cacheable.
- `prune` removes `ports.tar.gz` with the version tree that holds it.
- `prune` leaves the distfile tree, and the tree keeps every byte.
- `trim_distfiles` removes the oldest file first, and it stops when the tree
  fits the cap.
- `trim_distfiles` returns each removed path and its size.
- `trim_distfiles` with a cap of 0 empties the tree.
- `trim_distfiles` leaves every file of the release tree.
- `store` of a distfile trims the tree.
- `store` of a file set leaves an over-cap distfile tree alone.
- `distfile_size` counts the tree over two cached hosts.
- A `Fugu::Proxy::Meta` entry for an evicted file reads as absent.

`t/fuguvm/miniroot.t` proves:

- `ensure` returns the cached path when the image is cached.
- `ensure` returns `undef` when the mirror cannot verify, and it stores nothing.
- `url` returns the URL that the mirror builds, so the host has one home.
- The module names no host of its own: `App::FuguVM::Miniroot->can('CDN_HOST')`
  is false.

`t/fuguvm/config.t` proves:

- `distfile_cache` parses `4G`, `512M`, `64K` and `1024`.
- `distfile_cache` accepts a lower-case suffix.
- `distfile_cache` returns 0 for `0`, and 0 for an absent directive.
- `distfile_cache` warns and returns 0 for an unparsable value.
- The project file wins over the global file for each of the three directives.
- `verify` defaults to 1, and it reads `no` as 0.
- `signify_dir` expands a tilde, and it resolves a relative path against the
  project root.
- `load_vm` carries `verify` and `signify_dir` into the VM hash.

`t/fuguvm/cli.t` proves:

- `mirror` with no action exits 2.
- `mirror` with an unknown action exits 2.
- `mirror fetch` with no file exits 2.
- `mirror verify` over an empty cache exits 0.
- `cache list` prints the distfile line with the size and the cap.
- `cache list` groups no distfile under the version report.
- `status` holds the `proxy_url` key, and the value is empty with no proxy.

`t/fuguvm/guest.t` proves:

- `status` reports `proxy_url` from `guest_url`.
- The install argument list carries the verify flag.
- `up` sets `FUGUVM_DISTFILE_LIMIT` from the configuration before it starts the
  proxy.

## Acceptance

- `make check` passes: `make lint`, `make test` and `make tidy`.
- `t/scripts/symbols.t` passes: every public sub has a caller in `lib/`, in
  `bin/`, or in a test. The deleted subs of `App::FuguVM::Miniroot` take their
  tests with them.
- `t/fuguvm/boundary.t` passes: `App::FuguVM::Mirror` adds no CPAN import and no
  `Protocol::` import.
- `make prettier` passes for the Markdown changes.
- `mandoc -Tlint man/fuguvm/fuguvm.1` reports nothing.
- `make deps` installs signify(1) on Linux and on Darwin, and
  `Fugu::Signify->is_available` then returns 1.
- `fuguvm mirror fetch ports.tar.gz` verifies a real `SHA256` of a live mirror
  under a real release key, and it prints the cached path. A unit test cannot
  cover this path, so this run is the proof of record.
- The same command against a manifest with one byte changed exits 1, and the
  cache holds no ports tree afterwards.
- `fuguvm mirror verify` over a warm cache of a completed install exits 0. The
  report lists each set under `ok`, and it lists `index.txt` under `unknown`.
- A cold `fuguvm up` with `verify yes` completes, and the recorded transcript
  shows no "Continue without verification?" prompt. A transcript is the only
  proof that an installer prompt reads as the plan states.
- The miniroot in the cache verifies against the release manifest after that
  run.
- `fuguvm up` with `verify yes` on a host with no signify(1) exits 1, and the
  diagnostic names the command and the package.
- A ports build in the guest, over `fuguvm ssh` with `http_proxy`, downloads
  each distfile one time. The second build of the same port downloads none, and
  the proxy log shows a cache hit for each file.
- The distfile tree stays under `distfile_cache` after that build, and
  `fuguvm cache list` reports the size and the cap.
- `fuguvm cache clear --stale` keeps the distfile tree and removes the downloads
  of every other version.
- `fuguvm cache clear` removes the distfile tree with everything else.
- A second project on the same host shares the distfile tree, because the tree
  hangs off `cache_dir`.

## Open questions

1. **The installer prompt.** The plan makes "Continue without verification?" a
   failure under `verify yes`. The installer of a numbered release must verify
   each set by itself, and a transcript must prove that it does. If the prompt
   appears for a benign reason, the tool must instead pre-fetch and verify each
   selected set on the host. The script must then answer yes under a flag that
   records the host proof. The fallback costs one method on
   `App::FuguVM::Mirror` and one more argument on the script.
2. **The key of the source manifest.** The plan verifies
   `/pub/OpenBSD/<version>/SHA256` under `openbsd-<NN>-base.pub`. One fetch from
   a live mirror must prove it before the code lands. A separate key would add
   one entry to the key resolution and nothing else.
3. **The digest form of `distinfo`.** The ports tree writes each distfile digest
   as a base64 SHA256, and not as the hex `sha256(1)` line form that
   `Fugu::Signify` parses. The plan therefore keeps the distfile check in the
   guest. A reader must confirm the form in a real `distinfo` before any code
   depends on it.
4. **The distfile mirror override in the guest.** The ports tree must fetch each
   distfile from `http://cdn.openbsd.org/pub/OpenBSD/distfiles/`, and the exact
   `/etc/mk.conf` variable must come from bsd.port.mk(5) on the guest. The man
   page holds the example, so a wrong name costs one documentation fix.
5. **Which release keys ship.** The plan ships one key for the default release.
   A guest of an older release then needs `/etc/signify/` or `signify_dir`. The
   alternative is one key for each supported release in the share tree, which
   grows the trust anchor set. FuguVM must state a support window first.
6. **A code of its own for a verification failure.** A harness would read a
   dedicated exit code more easily than exit code 1. No consumer asks for one
   today, so the plan adds no number. FuguOracle `TEST-INTEROP-5`, which the
   edit set adds, reads exit codes 11, 5 and 7. A verification code would join
   that list.
7. **The default cap.** The plan makes the distfile cache off by default,
   because an unbounded tree in a home directory is the failure to avoid. A
   consumer that wants the cache must set `distfile_cache` in its `.fuguvmrc`.
   FuguOracle and FuguTTX must each choose a size, and neither specification
   names one yet.
