# Changelog

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
