# FuguVM specification

FuguVM installs and manages OpenBSD virtual machines under QEMU, driven by
`bin/fuguvm` and a `.fuguvmrc` at the project root. It installs a guest without
interaction, caches installed disks, and drives the lifecycle. It runs on Linux
and Darwin hosts, and on OpenBSD.

This document is the entry point of the specification. It holds the plan
contract, the ID conventions, and the document tables.

## Plan contract

- Read [DECISIONS.md](DECISIONS.md) before you make a plan.
- A plan must not go against a decision. To go against a decision, propose a
  change to [DECISIONS.md](DECISIONS.md) and get human approval first.
- A plan must cite each unit that it implements, for example
  `Implements: GST-ARCH`.
- A plan can exclude a rule from a cited unit with `without`, for example
  `Implements: GST-ARCH without GST-ARCH-1`.
- A plan must cite each unit that it touches but defers, for example
  `Defers: GST-IMAGES`.
- The change that implements a unit, or a part of a unit, must set the state of
  the unit in [STATUS.md](STATUS.md) in the same change.

<a id="conventions"></a>

## Conventions

A unit is one implementable design element. An invisible HTML anchor marks each
unit, and the unit ID is the anchor in upper case:

```markdown
<a id="gst-arch"></a>

## Guest architecture

- **GST-ARCH-1** — A `vm` block must …
```

- The anchor of a unit must start with the code of its document, in lower case,
  followed by a hyphen.
- A unit extends from its anchor to the next unit anchor or heading, whichever
  comes first.
- A rule ID names one requirement inside a unit. A rule is a bold-lead list
  item: the bold rule ID, one em dash, then the requirement text, as the example
  above shows.
- Rule numbers only append: never renumber a rule, and never reuse a number.
- An ID must not change. To retire a unit: delete its anchor and its register
  row, and add the ID to the "Retired IDs" table of [STATUS.md](STATUS.md).
- Each document describes the target design in the current state only. Only
  [ROADMAP.md](ROADMAP.md) and [STATUS.md](STATUS.md) say when work occurs.
- A citation of a unit of a sibling repository is a prose token with the
  repository name in front, for example Fugu LIB-SSH. It is never a link, and it
  never names a plan.

## Specification documents

Each document specifies one area of work. The code of a document prefixes the
IDs of its units.

| Code | Document                           | Area                                       |
| ---- | ---------------------------------- | ------------------------------------------ |
| ARC  | [architecture.md](architecture.md) | Namespace, boundaries, and shared files    |
| GST  | [guests.md](guests.md)             | The guest lifecycle and the tool behavior  |
| REL  | [release.md](release.md)           | Versioning, the dist, and the release flow |

## Governance documents

These documents carry no units.

| Document                     | Role                                                  |
| ---------------------------- | ----------------------------------------------------- |
| [DECISIONS.md](DECISIONS.md) | The decisions. A plan must not go against a decision. |
| [ROADMAP.md](ROADMAP.md)     | The schedule of the work.                             |
| [STATUS.md](STATUS.md)       | The implementation register.                          |
