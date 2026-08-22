# Implementation register

This register is the one record of implementation state. One row exists for each
unit of the specification. A unit is one design element of one specification
document. The [conventions](index.md#conventions) define the unit IDs. Each row
describes the current state only. A row must not carry a plan name or a
reference to an earlier state. A note can carry the date of a recorded fact.

## States

| State   | Meaning                                                              |
| ------- | -------------------------------------------------------------------- |
| open    | No code implements the unit.                                         |
| partial | Code implements a part of the unit. The note names each absent part. |
| done    | Code implements the full unit. The note links the code or the tests. |
| n-a     | No code can implement the unit. It exists for citation only.         |

The "Done by" column names a phase of the [roadmap](ROADMAP.md), or "—" when no
phase applies.

## Units

| Unit                                           | State   | Done by | Note                                                                                                                       |
| ---------------------------------------------- | ------- | ------- | -------------------------------------------------------------------------------------------------------------------------- |
| [ARC-NAMESPACE](architecture.md#arc-namespace) | done    | —       | [lib/App/FuguVM](../lib/App/FuguVM), [symbols.t](../t/scripts/symbols.t)                                                   |
| [ARC-BOUNDARY](architecture.md#arc-boundary)   | done    | —       | [boundary.t](../t/fuguvm/boundary.t)                                                                                       |
| [ARC-SHARE](architecture.md#arc-share)         | done    | —       | [share/fuguvm](../share/fuguvm), [miniroot.t](../t/fuguvm/miniroot.t)                                                      |
| [ARC-PROGRAMS](architecture.md#arc-programs)   | n-a     | —       | Citation only.                                                                                                             |
| [GST-INSTALL](guests.md#gst-install)           | done    | —       | [Guest.pm](../lib/App/FuguVM/Guest.pm), [guest.t](../t/fuguvm/guest.t), [miniroot.t](../t/fuguvm/miniroot.t)               |
| [GST-CACHE](guests.md#gst-cache)               | done    | —       | [DiskCache.pm](../lib/App/FuguVM/DiskCache.pm), [diskcache.t](../t/fuguvm/diskcache.t)                                     |
| [GST-LIFECYCLE](guests.md#gst-lifecycle)       | done    | —       | [Guest.pm](../lib/App/FuguVM/Guest.pm), [guest.t](../t/fuguvm/guest.t)                                                     |
| [GST-HOSTS](guests.md#gst-hosts)               | done    | —       | [deps](../deps), [config.t](../t/fuguvm/config.t)                                                                          |
| [GST-MIRROR](guests.md#gst-mirror)             | partial | —       | The signify verification of GST-MIRROR-1 is absent. [Proxy.pm](../lib/App/FuguVM/Proxy.pm), [proxy.t](../t/fuguvm/proxy.t) |
| [GST-ARCH](guests.md#gst-arch)                 | open    | —       | —                                                                                                                          |
| [GST-FLEET](guests.md#gst-fleet)               | open    | —       | —                                                                                                                          |
| [GST-TRANSFER](guests.md#gst-transfer)         | open    | —       | —                                                                                                                          |
| [GST-IMAGES](guests.md#gst-images)             | open    | —       | —                                                                                                                          |
| [REL-VERSION](release.md#rel-version)          | done    | —       | [Makefile](../Makefile)                                                                                                    |
| [REL-ASSETS](release.md#rel-assets)            | done    | —       | [release.yml](../.github/workflows/release.yml)                                                                            |
| [REL-BUILD](release.md#rel-build)              | done    | —       | [build.yml](../.github/workflows/build.yml)                                                                                |

## Update protocol

1. The change that implements a unit, or a part of a unit, sets the state of the
   unit in this register, in the same change.
2. A `partial` note names each absent rule or part.
3. A `done` note holds at least one relative link to code or to tests.

## Code roots

The drift gate maps each document to the code that implements it.

| Document        | Roots                                      |
| --------------- | ------------------------------------------ |
| architecture.md | `lib`, `share`, `t`                        |
| guests.md       | `lib`, `share`, `bin`, `t`                 |
| release.md      | `Makefile`, `scripts`, `.github/workflows` |

## Retired IDs

| ID  |
| --- |
