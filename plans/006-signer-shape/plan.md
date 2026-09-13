# 006 — The new signer shape in the mirror

## Status

Proposed. It can land now. Fugu v0.5.0 is released, and it carries the new
shape. The change is patch-level: no command, no directive and no cache layout
changes.

Extends: GST-MIRROR. Extends: ARC-BOUNDARY.

## Purpose

`App::FuguVM::Mirror` proves the `SHA256` manifest of a release under the
release key of that version. It drives `Fugu::Signify` in the shape of Fugu
v0.4.0. Fugu v0.5.0 holds a different shape, so the module stops.

Fugu v0.5.0 also changes what the proof needs. `Fugu::Signify` verifies with
core Perl under its `perl` engine, and that engine is the default. The host then
needs no signify(1) command for the proof.

This plan moves the module to the new shape. It deletes the install hint that
the new engine makes dead, and it names the Fugu version that the module needs.

## Evidence

`t/fuguvm/mirror.t` stops against Fugu v0.5.0 with the message "keys, file and
signature are necessary arguments". The subtest "the release manifest and the
file proofs" then runs no test. Each `deps/` manifest names
`releases/latest/download/Fugu.tar.gz`, so the next `make deps` takes v0.5.0.
The break is live, and no version pin holds it back.

`Fugu::Signify->new` takes no `keys` in v0.5.0. `verify` takes `keys`, `file`
and `signature` as named arguments. `Mirror.pm` calls `new( keys => [$key] )`
and `verify( $manifest, $signature )`, which are both the old shape.

Fugu v0.4.0 holds no `perl` engine, because the Ed25519 verifier landed after
that tag. Under v0.5.0 `is_available` answers 1 with no signify(1) command, and
`command_absent` stays 0 after a failed verification. The install hint of
`_signify_error` is then dead text.

The tests run signify(1) to make each fixture, with `-G` and `-S`. That need
stays, because a test must make a signed manifest. `_find_signify` of
`t/fuguvm/mirror.t` and of `t/fuguvm/cli.t` is a copy of the resolver that
`Fugu::Process->find_command` now owns.

Fugu REL-VERSION-2 stamps `our $VERSION` into each package of a distribution, so
a consumer can assert a minimum. D-05 keeps `$VERSION` out of a source module,
and a Fugu checkout therefore carries none. `use Fugu::Signify 0.5.0` stops
against a Fugu checkout on the include path. A developer who runs the two
checkouts together must install Fugu first. The reviewer must accept that cost,
or must reject the version assertion.

## The rule changes

### GST-MIRROR

- The text of GST-MIRROR-1 changes. The mirror fetch verifies the `SHA256`
  manifest through Fugu LIB-SIGNIFY under its `perl` engine. The engine verifies
  with core Perl, so the host needs no signify(1) command for the proof. The
  rule keeps the release key of the version as the anchor.

### ARC-BOUNDARY

- A new rule: a module that needs an interface of a named `Fugu::` release must
  assert that version at its `use` line. The manifests name the stable asset of
  the latest release, so no other part holds a floor. An older library must give
  a version error, and never a failure inside a method.

## The change

1. `lib/App/FuguVM/Mirror.pm` moves to the new shape. The `use` line becomes
   `use Fugu::Signify 0.5.0`. `manifest` builds the verifier with
   `Fugu::Signify->new`, and it calls `verify` with `keys`, `file` and
   `signature`.
2. `_signify` and `_signify_error` go. `_signify` answers a constructor call
   with no argument, and `_signify_error` answers one reason after the install
   hint goes. `manifest` holds both lines. The design note of `_signify`, which
   states why one key and not a key set, moves to the call site.
3. `lib/App/FuguVM/Mirror.pod` follows. The sentences that name the signature
   check state that the proof needs no signify(1) command.
4. `t/fuguvm/mirror.t` and `t/fuguvm/cli.t` make each fixture through
   `Fugu::Signify->generate` and `Fugu::Signify->sign`. `_find_signify` goes
   from both files. Each test that needs a fixture skips when the object answers
   `is_available` 0.
5. `spec/guests.md` and `spec/architecture.md` carry the rule changes.
   `spec/STATUS.md` keeps GST-MIRROR and ARC-BOUNDARY `done`.
6. This plan directory goes in the same change.

## What this plan does not do

It passes one key, and not a key set. The release directory of a numbered
release carries one signature, under the base key of that release. A second key
would accept a file that the version does not own.

It does not take `verify_manifest`. The digest check stays in this module. A
real OpenBSD release manifest repeats the install image lines, and
`Fugu::Signify` refuses a manifest with a duplicate name.

It asserts no version on another `use Fugu::` line. Only the changed interface
needs one now.

It changes no other consumer of `Fugu::`. `App::FuguVM::Mirror` is the one
module that drives a signer.
