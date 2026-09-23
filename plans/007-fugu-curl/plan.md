# 007 — The mirror downloads through Fugu::Curl

## Status

Work package 1 can land now. Work package 2 waits on work package 1, and the
operator runs it. Work package 3 waits on Tooling plan 011 work package 2.

Fugu v0.5.0 ships `Fugu::Curl`, and Fugu 0.5.1 is on CPAN. The module needs core
Perl only. Fugu LIB-CURL states the contract, and the unit is `done`.

- Extends: GST-MIRROR. The implementation adds a rule that names the transport
  and the bound, and a rule that names the log line.
- Defers: ARC-BOUNDARY. The `use` line takes a version, per ARC-BOUNDARY-3, and
  no rule of the unit changes.
- Defers: ARC-SHARE. ARC-SHARE-1 names no helper, so the drop of the share entry
  changes no rule.
- Defers: ARC-PROGRAMS. The unit carries no rule, and it stays `n-a`.
  `Fugu::Curl` holds the command that the tool runs.
- Defers: REL-VERSION. The test of the staged tree changes, and no rule of the
  unit changes.
- Defers: REL-ASSETS. The release of work package 2 uses the workflow that the
  unit states.

## Purpose

`App::FuguVM::Mirror` downloads each OpenBSD file with `scripts/ftp`, a POSIX
shell helper of the org pack of FuguBSD/Tooling. Fugu LIB-CURL now holds that
design, and `Fugu::Curl` holds the code. Its preamble states the swap: a
consumer that ships a shell helper over the same three commands replaces it with
this module.

This plan is the one blocker of Tooling plan 011 work package 2. That package
deletes `org/sync/scripts/ftp` from the org pack, and it waits on a release of
App-FuguVM that needs no helper.

## Scope

In scope:

- The `fetch` method of `lib/App/FuguVM/Mirror.pm`, and its POD.
- The share entry of `.toolingrc`, and the install line of `mk/local.mk`.
- The GST-MIRROR unit, and the tests of the download path.
- One release of App-FuguVM.

Out of scope:

- The deletion of `scripts/ftp`. The org pack holds the file, and Tooling
  deletes it.
- The design of the downloader. Fugu LIB-CURL owns it.
- The proxy path. `Fugu::Proxy` already serves the guest, and it does not
  change.
- A retry, a resume, and a progress meter. LIB-CURL states that the module holds
  none of the three.

## What the tree says

The measurements below come from the checkout, on 2026-09-23.

**One method calls the helper.** `App::FuguVM::Mirror::fetch` is the one home of
the call, and its head comment says so. It resolves the file with
`Fugu::File->share_path`, and it runs `sh` over it, because an installed share
tree drops the exec bit. Two methods call `fetch`: `ensure` and
`_ensure_unverified`.

**The helper is not a fallback chain.** `Mirror.pod` says that the helper falls
back through curl, wget and ftp. The helper switches on `uname` instead, and it
holds no fallback. An unknown system exits 1. The POD is wrong today.

**Five files name the helper outside the synced scripts.** They are
`lib/App/FuguVM/Mirror.pm`, `lib/App/FuguVM/Mirror.pod`, `.toolingrc`,
`mk/local.mk`, and `t/scripts/dist.t`. One comment of
`.github/workflows/integration.yml` names it too.

**The two install flows disagree.** `mk/local.mk` installs the helper with
mode 755. The dist flow installs it as a `PM` entry, and MakeMaker writes
mode 444. The `sh` of the call papers over that difference.

**A warm cache hides the breakage.** `ensure` returns a cache hit before it
calls `fetch`. An installed distribution without the helper therefore fails on a
cache miss alone.

**The mirror already asserts a Fugu version.** `Mirror.pm` holds
`use Fugu::Signify 0.5.0;`. That line is the precedent of ARC-BOUNDARY-3.

**The temporary file survives the rename.** `Fugu::Curl` writes a sibling file
and renames it onto the destination. A run of that sequence over a
`File::Temp->new` path keeps the bytes, and the object still removes the path at
destruction. The return contract of `fetch` therefore needs no change.

## Constraints that shape the design

**D-04 holds.** `Fugu::Curl` runs curl, wget or the ftp of OpenBSD as a command,
through `Fugu::Process`. It links no library, so the external program stays a
command.

**D-02 holds.** `Fugu::Curl` needs core Perl only, and it is a `Fugu::` module.
`t/fuguvm/boundary.t` accepts it.

**The `use` line takes a version.** ARC-BOUNDARY-3 makes an old library give a
version error, and never a failure inside a method. `Fugu::Curl` first shipped
in Fugu v0.5.0, so the line reads `use Fugu::Curl 0.5.0;`.

**The operator loses the progress meter.** The helper writes its progress, and a
download of a hundred megabytes is a wait that an operator wants to see.
LIB-CURL-8 forbids a progress meter, and the module offers no callback. The tool
therefore logs the URL before each fetch. This is a deliberate loss, and the
alternative is a change of Fugu.

**A set file is large, and the default bound is short.** LIB-CURL-6 gives 600
seconds by default. A set file of OpenBSD is hundreds of megabytes, so the
mirror sets its own bound.

**One mirror resolves the command one time.** LIB-CURL-1 resolves in `new`, and
it runs no process there. The module therefore holds one downloader for the life
of the mirror.

**A caller must read the filename.** `Fugu::Curl` renames its own sibling file
onto the path of the temporary file. `File::Temp` then removes that path through
its fallback: the inode check of `unlink1` fails, and `DESTROY` runs a bare
`unlink`. The filehandle of the object holds the old inode after the rename. A
caller must therefore read `$tmp->filename`, and must never read the object as a
filehandle. The two callers of `fetch` in `lib/App/FuguVM/Mirror.pm` already
obey this, because each one reads `filename`.

**The helper file stays in the tree.** The org pack ships it, and
`t/scripts/conventions.t` pins the roster of `scripts/`. This repository owns
that test, and no pack holds it. The file therefore stays until Tooling deletes
it from the pack. The change that takes that sync drops the roster entry.

## The interface contract

`fetch` keeps its signature, and it keeps its return contract. It returns the
`File::Temp` object on success. It returns undef on every failure, with the
reason in `error`.

The reasons change, because the module reports more than the helper did. An
absent downloader gives the `error` of the downloader object. A failed transfer
gives the reason of the module, and that reason already names the URL. A
transfer that writes no bytes keeps its own reason.

The new rules read as follows. A plan names no rule number, because a number
exists after the rule lands.

- A rule of GST-MIRROR: "A mirror fetch must download through Fugu LIB-CURL, and
  must bound the fetch at 3600 seconds. A set file is large, and a stalled
  connection must not hold the tool forever."
- A rule of GST-MIRROR: "The tool must log the URL of each fetch that reaches
  the network, because the downloader writes no progress."

## Work packages

### WP1 — The mirror fetches through `Fugu::Curl`

The package can land now. It depends on no other package.

1. Add `use Fugu::Curl 0.5.0;` to the `use` block of `lib/App/FuguVM/Mirror.pm`.
2. Build one `Fugu::Curl` in the constructor of the mirror, with a timeout of
   3600 seconds.
3. Rewrite `fetch` over that object, and keep the `File::Temp` return contract.
4. Report an absent downloader with the `error` of the downloader object.
5. Report a failed transfer with the reason of the module, which already names
   the URL.
6. Log the URL with `Fugu::Log` before each fetch.
7. Rewrite the `fetch` section of `lib/App/FuguVM/Mirror.pod`, which describes
   the helper wrongly today.
8. Name `Fugu::Curl` in the DESCRIPTION of that file, in place of the helper.
9. Add `Fugu::Curl` to the SEE ALSO section of that file.
10. Repair the head comment of `lib/App/FuguVM/Mirror.pm`, which names the
    helper.
11. Delete the `dist.share-extra scripts/ftp` line of `.toolingrc`.
12. Delete the `scripts` install lines of `mk/local.mk`.
13. Delete the two `scripts/ftp` assertions of `t/scripts/dist.t`.
14. Repair the comment of `.github/workflows/integration.yml`.
15. Add the two rules to GST-MIRROR, per the section "The interface contract".
16. Keep the GST-MIRROR row of `spec/STATUS.md` at `done`, per `spec/CLAUDE.md`.
17. Name the new assertions of `t/fuguvm/mirror.t` in the note of that row.

Acceptance:

- `make check` passes.
- `git grep -n 'scripts/ftp' -- lib mk t .toolingrc .github` reports nothing.
- A staged distribution holds no `scripts/ftp`, and its `Makefile.PL` names no
  such entry.
- `fuguvm mirror fetch` downloads one file on a host with curl, and on a host
  with wget alone.
- Each new assertion of `t/fuguvm/mirror.t` fails against a mutated `fetch`.

### WP2 — App-FuguVM ships a release without the helper

The package waits on work package 1. The operator runs it, because an agent
cannot push a tag.

1. Dispatch the Release workflow with the version `v0.3.0`.
2. Wait for the CPAN upload, and read the release page.
3. Tell Tooling that plan 011 work package 2 can start.

Acceptance:

- The release page of FuguVM holds App-FuguVM 0.3.0.
- The tarball of that release holds no `scripts/ftp`.
- An installed App-FuguVM 0.3.0 downloads one file with an empty cache.

### WP3 — The sync drops the helper

The package waits on Tooling plan 011 work package 2. That package deletes
`org/sync/scripts/ftp` from the org pack.

1. Sync the org pack.
2. Drop `ftp` from the roster of `t/scripts/conventions.t`.

Acceptance:

- `make check` passes.
- `sync --check` reports no drift.

## Tests

`t/fuguvm/mirror.t` holds the new assertions. It must reach no network. A stub
program on a private `PATH` serves the downloader, as `t/fugu/curl.t` of Fugu
does. It must assert:

- `fetch` returns the temporary file when the stub writes bytes.
- `fetch` returns undef and names the URL when the stub fails.
- `fetch` returns undef when the stub writes an empty output file. The stub must
  create that file at the path of the argument list. A stub that creates no file
  stops the fetch at the rename, and the zero-byte branch never runs.
- `fetch` returns undef and states the reason when `PATH` holds no downloader.
- The mirror holds one downloader, and it resolves the command one time.

The subtests that stub `App::FuguVM::Mirror::fetch` keep their shape. They test
the callers, and this plan does not change the contract of the method.

`t/fuguvm/boundary.t` needs no change. `Fugu::Curl` is a `Fugu::` module, and
the test accepts it.

## What this repository cannot prove

The three dialects of the downloader. Fugu LIB-CURL owns that oracle, and
`t/fugu/curl.t` holds it with a loopback server and a stub for each dialect.
This repository holds no copy, and it must not add one.

A real download over the network. `.github/workflows/integration.yml` installs a
guest on a runner, and that job fetches the sets through the mirror. That job is
the one end-to-end proof, and it runs on a push that touches these paths.

## Rollback

A revert of the work package 1 commit restores the helper call. The org pack
still ships `scripts/ftp` until Tooling plan 011 work package 2 lands, so the
revert needs no sync.

After the release of work package 2, an operator pins App-FuguVM 0.2.0. That
release holds the helper in its share tree.

## Open questions

1. The bound of 3600 seconds rests on no measurement. A set file of hundreds of
   megabytes needs minutes on a fast link, and an hour on a slow one. A reviewer
   must accept the number, or must name a measurement that fixes it.
2. App-FuguVM declares no Fugu prerequisite, so `cpanm` installs any Fugu.
   `INSTALL.md` can name the floor of Fugu 0.5.0. That sentence belongs to this
   plan, or to a change of its own.
