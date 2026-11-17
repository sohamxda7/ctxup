# Changelog

## 0.1.1

Found by running the installer in virtual machines with a desktop, SELinux
and real reboots.

- Fixed: after removing a client that had App Protection, RHEL 9 with
  SELinux enforcing was left with a stale `/etc/ld.so.preload`, and every
  command printed a loader error after the next reboot. `ctxup` now removes
  the entry itself.
- `uninstall` repairs that state on machines already affected, even when the
  client is no longer installed.
- `uninstall` removes the dangling `/usr/local/bin/nsgcepa` link left by the
  EPA plug-in and clears the failed state of removed services.
- `--app-protection` asks for confirmation on systems where Citrix does not
  support it, and is refused on RHEL 8: Citrix builds its App Protection
  service against glibc 2.34, so there it installs but never starts.
- `check` reports an App Protection service that is installed but not
  running.
- Linux Mint 22.3 and LMDE 7 are now part of the container matrix.
- `tests/vm` holds the scripts for the virtual machine run.
- The README describes how the project is tested, including the virtual
  machine run.

## 0.1.0

First release.

- Detects Ubuntu, Debian, Fedora and RHEL-compatible distributions,
  including derivatives such as Linux Mint, Pop!_OS and LMDE.
- Interactive menu that returns after each action.
- Lists the releases Citrix publishes for Linux and installs the latest or
  any chosen one.
- Verifies each download against the SHA-256 published by Citrix.
- Installs the libraries the Citrix packages need but do not declare.
- Handles an existing installation: in-place upgrade, reinstall, downgrade,
  and switching from a tarball install.
- Adds the system CA certificates to the client keystore.
- `check` reports missing libraries, service state and the result of
  Citrix's own `workspacecheck.sh`.
- `uninstall`, with `--purge` to remove settings as well.
