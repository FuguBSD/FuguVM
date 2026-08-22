# Decisions

This document holds the decisions that govern FuguVM. A plan must not go against
a decision. To change a decision, propose the change and get human approval
first.

| ID   | Decision                                                                                                                                                      | Rationale                                                                                  |
| ---- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| D-01 | The dependency direction is one way: `App::FuguVM` uses the installed `Fugu::` library and core Perl, never `Protocol::` and never another `App::` namespace. | A sibling application is not a library, and the codec layer stays below the utility layer. |
| D-02 | No module imports a CPAN module directly. Every CPAN module arrives through an optional `Fugu::` feature, declared in the manifests.                          | One dependency gate keeps the install surface small and audited.                           |
| D-03 | Shared files resolve through `Fugu::File->share_path`.                                                                                                        | A checkout and an installed distribution then behave the same.                             |
| D-04 | External programs are commands, never libraries. [ARC-PROGRAMS](architecture.md#arc-programs) names the programs.                                             | A command isolates a large foreign codebase behind a small argument surface.               |
| D-05 | The version derives from the latest `v*` tag. No `$VERSION` lives in a source module.                                                                         | One source of truth, stamped at dist build time.                                           |
