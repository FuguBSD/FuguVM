# Guests

`fuguvm` makes a real OpenBSD guest available to a test suite, on a Linux or
Darwin host and in CI. This document specifies the install, the cache, the
lifecycle, the hosts, and the target design of the open work.

<a id="gst-install"></a>

## Unattended install

- **GST-INSTALL-1** — `fuguvm` must install an OpenBSD guest without
  interaction, driven by the expect scripts and the miniroot.
- **GST-INSTALL-2** — A project must describe its guests in one `.fuguvmrc` at
  its root.

<a id="gst-cache"></a>

## The disk cache

- **GST-CACHE-1** — An installed disk must land in the cache, keyed by the
  cache-generation file, so a later `up` skips the install.

<a id="gst-lifecycle"></a>

## The lifecycle

- **GST-LIFECYCLE-1** — The tool must drive the guest lifecycle: boot, wait,
  ssh, snapshot, and shutdown.
- **GST-LIFECYCLE-2** — A repeatable operation must stay idempotent, and a
  failure must leave no orphaned process and no corrupt state.

<a id="gst-hosts"></a>

## Hosts

- **GST-HOSTS-1** — The tool must run on Linux and Darwin hosts, and on OpenBSD.

<a id="gst-mirror"></a>

## The mirror proxy

The mirror proxy caches the OpenBSD sets that an install fetches.

- **GST-MIRROR-1** — A mirror fetch must verify the `SHA256` manifest of the
  release under its release key, through Fugu LIB-SIGNIFY.
- **GST-MIRROR-2** — A verification failure must leave no file in the cache.

<a id="gst-arch"></a>

## Guest architecture

- **GST-ARCH-1** — A `vm` block must accept `arch amd64` or `arch arm64`, and
  the value must select the QEMU binary, the firmware, and the miniroot.
- **GST-ARCH-2** — The tool must select KVM or HVF only when the host machine
  runs the instruction set of the guest. It must select TCG in every other case.

<a id="gst-fleet"></a>

## Scriptable and parallel guests

- **GST-FLEET-1** — A project must drive several guests in one run, scriptable,
  parallel, and private to the run.

<a id="gst-transfer"></a>

## File transfer

- **GST-TRANSFER-1** — The tool must transfer files to and from a guest over
  SSH, with quoting that the tool owns, and with exit codes that a script can
  read.

<a id="gst-images"></a>

## Image lifecycle

Three tool surfaces carry an OpenBSD disk image through its whole life: the tool
builds one image, it publishes the image as a file, and an other host consumes
that file. Every surface is a tool surface, because a consumer must never load
an `App::FuguVM` module.

- **GST-IMAGES-1** — An `autoinstall <file>` directive must install the guest
  from an autoinstall(8) response file, and the shipped expect installer must
  stay the default. The tool must serve the file to the guest from the loopback
  address only, and it must validate no answer in the file.
- **GST-IMAGES-2** — `fuguvm image export <path>` must write the installed base
  disk of the invoked VM as a full-disk image, as qcow2 by default and as a
  sparse raw image with `--format=raw`, and it must not overwrite an existing
  target.
- **GST-IMAGES-3** — A `base_disk <path>` directive must make an existing
  full-disk image the base image of a guest, published as one write-once cache
  entry for the whole project, so the tool installs nothing and every cache verb
  and snapshot verb works on the imported entry.
- **GST-IMAGES-4** — The image-cache key must hash each input that shapes the
  installed disk of its install mode, the response file included, and it must
  hash no script that the install never ran.
