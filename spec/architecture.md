# Architecture

FuguVM is one Perl application namespace over the Fugu library. This document
specifies the namespace, the dependency boundary, and the shared files.

<a id="arc-namespace"></a>

## Namespace

- **ARC-NAMESPACE-1** — The repository holds one Perl namespace, `App::FuguVM::`
  (`lib/App/FuguVM/`), with `lib/App/FuguVM.pm` as the lead module of the
  App-FuguVM distribution.
- **ARC-NAMESPACE-2** — One module holds one concern: the CLI, the
  configuration, the guest lifecycle, the console, the disk, the disk cache, the
  miniroot, the mirror proxy, QMP, and the state.
- **ARC-NAMESPACE-3** — Every module must have a `.pod` sidecar and a test.

<a id="arc-boundary"></a>

## The dependency boundary

The dependency direction is one way.

- **ARC-BOUNDARY-1** — `App::FuguVM` must use only the installed `Fugu::`
  library and core Perl. It must not use `Protocol::`, and it must not use
  another `App::` namespace: a sibling application is not a library.
- **ARC-BOUNDARY-2** — No module imports a CPAN module directly. Every CPAN
  module it reaches comes through an optional `Fugu::` feature, declared in the
  manifests.

<a id="arc-share"></a>

## Shared files

- **ARC-SHARE-1** — The expect scripts, the cache-generation file, and the
  configuration samples live in `share/fuguvm/`.
- **ARC-SHARE-2** — A module must resolve a shared file with
  `Fugu::File->share_path`, passing `from => __FILE__` and
  `dist => 'App-FuguVM'`, so a checkout and an installed distribution both work.

<a id="arc-programs"></a>

## External programs

The tool drives `qemu-system-aarch64`, `qemu-system-x86_64`, `qemu-img`,
`expect`, `telnet`, and `ssh` as commands, never as libraries.
