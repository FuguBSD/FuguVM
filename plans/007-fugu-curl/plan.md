# 007 — The mirror downloads through Fugu::Curl

## Status

Work package 2 can run now, and the operator runs it. Work package 3 waits on
Tooling plan 011 work package 2.

Fugu v0.5.0 ships `Fugu::Curl`, and Fugu 0.5.1 is on CPAN.

- Defers: REL-ASSETS. The release of work package 2 uses the workflow that the
  unit states.

## Purpose

This plan is the one blocker of Tooling plan 011 work package 2. That package
deletes `org/sync/scripts/ftp` from the org pack, and it waits on a release of
App-FuguVM that needs no helper.

## Scope

In scope:

- One release of App-FuguVM.
- The roster of `scripts/` in `t/scripts/conventions.t`.

Out of scope:

- The deletion of `scripts/ftp`. The org pack holds the file, and Tooling
  deletes it.

## What the tree says

The measurements below come from the checkout, on 2026-09-23.

**A warm cache hides the download path.** `ensure` returns a cache hit before it
calls `fetch`. An installed distribution therefore reaches the downloader on a
cache miss alone, so the proof of work package 2 needs an empty cache.

**The helper file stays in the tree.** The org pack ships it, and
`t/scripts/conventions.t` pins the roster of `scripts/`. This repository owns
that test, and no pack holds it. The file therefore stays until Tooling deletes
it from the pack. The change that takes that sync drops the roster entry.

## Work packages

### WP2 — App-FuguVM ships a release without the helper

The operator runs the package, because an agent cannot push a tag.

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

## Rollback

After the release of work package 2, an operator pins App-FuguVM 0.2.0. That
release holds the helper in its share tree.

## Open questions

1. App-FuguVM declares no Fugu prerequisite, so `cpanm` installs any Fugu.
   `INSTALL.md` can name the floor of Fugu 0.5.0. That sentence belongs to this
   plan, or to a change of its own.
