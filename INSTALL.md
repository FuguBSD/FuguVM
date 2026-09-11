# Install FuguVM

FuguVM runs on Perl v5.36 or later over the Fugu library, with QEMU as the
hypervisor. There are two install flows: from a checkout with make, and from
CPAN with cpanm.

## From a checkout

```sh
git clone https://github.com/FuguBSD/FuguVM.git
cd FuguVM
make deps
doas make install
```

`make deps` installs the latest
[Fugu release](https://github.com/FuguBSD/Fugu/releases/latest), the QEMU
packages, `expect`, `telnet`, `signify`, and the SSH and HTTP modules.
`make install` copies `bin/fuguvm`, the modules, the manual, and the share tree.
`make uninstall` removes them.

## From CPAN

Every release goes to CPAN as the
[App-FuguVM](https://metacpan.org/dist/App-FuguVM) distribution. The
distribution does not name Fugu as a prerequisite, so name both:

```sh
cpanm --notest Fugu App::FuguVM
```

The cpanm flow installs the modules, the binary, and the share tree. The mdoc(7)
manual ships in the tarball but installs through the make flow. The QEMU,
expect, telnet, and signify packages come from the OS package manager either
way. The signify package is `signify-openbsd` on Linux and `signify-osx` on
Darwin; OpenBSD base holds signify(1).

## Set up a project

Write a `.fuguvmrc` at the project root. Copy the samples from
`share/fuguvm/fuguvm.conf.sample` and `share/fuguvm/vms/default.conf.sample`.
Then:

```sh
fuguvm up && fuguvm wait
```

## Verify

```sh
fuguvm status
fuguvm ssh -- uname -a
```
