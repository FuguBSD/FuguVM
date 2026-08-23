# FuguVM

Install and manage OpenBSD virtual machines under QEMU.

`fuguvm` installs an OpenBSD guest without interaction, caches the installed
disk, and drives the lifecycle: boot, wait, ssh, snapshot, and shutdown. It also
carries an image through its whole life: an `autoinstall` directive builds it,
`fuguvm image export` publishes it as a file, and a `base_disk` directive
consumes that file on an other host. A project describes its guests in one
`.fuguvmrc` at its root. The tool exists so a test suite can run against a real
OpenBSD guest, on a Linux or Darwin host and in CI.

FuguVM is written in Perl (v5.36) over the
[Fugu](https://github.com/FuguBSD/Fugu) library. It adds no direct CPAN
dependency of its own. The specification in [spec/](spec/index.md) states the
design.

## Quick start

```sh
make deps
bin/fuguvm up && bin/fuguvm wait
bin/fuguvm ssh 'uname -a'
bin/fuguvm down
```

`make deps` installs the latest Fugu release, QEMU, and the SSH and HTTP modules
the optional features use. See [INSTALL.md](INSTALL.md) for full instructions.

## Layout

- `bin/fuguvm` — the CLI entry point, over `App::FuguVM::CLI`
- `lib/App/FuguVM/` — the modules, one concern each, every one with a `.pod`
  sidecar
- `man/fuguvm/fuguvm.1` — the mdoc(7) reference for the tool
- `share/fuguvm/` — the expect scripts, the cache-generation file, and the
  configuration samples
- `spec/` — the specification; `t/fuguvm/`, `t/scripts/`, `t/ci/` — the test
  tiers
- `deps/` — per-OS dependency manifests, installed by `make deps`; `scripts/` —
  the dependency, download, check and dist helpers

## Documentation

`man fuguvm` — or `mandoc man/fuguvm/fuguvm.1 | less` from a checkout — holds
the full command, option, and exit-code reference. Each module documents its API
in a `.pod` sidecar; start with `lib/App/FuguVM.pod`.

## Commands

```sh
make check          # lint + format + test + spec-check + ste-lint
make test           # prove -l t/{fuguvm,scripts,ci}/*.t
prove -l t/fuguvm/foo.t    # one test file
make format-fix     # auto-fix Perl formatting
make format-md      # Markdown/JSON/YAML formatting check
make dist           # build the release tarball
```

The tests need the Fugu library on `@INC`; a local build of the sibling checkout
works too: `cpanm --local-lib=local ../Fugu/build/Fugu-*.tar.gz`.

## Releases

Push a `v<MAJOR>.<MINOR>.<PATCH>` tag, and the release workflow publishes the
tarball to GitHub Releases and to PAUSE. The rules are in
[spec/release.md](spec/release.md).

## Commit scopes

`cli`, `config`, `console`, `disk`, `guest`, `miniroot`, `proxy`, `qmp`,
`state`, `spec`, `deps`, `ci`.

## License

ISC. See [LICENSE](LICENSE).
