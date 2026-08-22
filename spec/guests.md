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
  release under its release key, through Fugu LIB-SIGNIFY, and a verification
  failure must leave no file in the cache.

<a id="gst-arch"></a>

## Guest architecture

- **GST-ARCH-1** — A `vm` block must accept `arch amd64` or `arch arm64`, and
  the value must select the QEMU binary, the firmware, and the miniroot.

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

- **GST-IMAGES-1** — The tool must build, publish, fetch, and prune guest
  images, so a fleet starts from a published image instead of a local install.
