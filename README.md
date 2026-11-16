# ctxup

[![Lint and unit tests](https://github.com/sohamxda7/ctxup/actions/workflows/lint.yml/badge.svg)](https://github.com/sohamxda7/ctxup/actions/workflows/lint.yml)
[![Security checks](https://github.com/sohamxda7/ctxup/actions/workflows/security.yml/badge.svg)](https://github.com/sohamxda7/ctxup/actions/workflows/security.yml)
[![Distribution matrix](https://github.com/sohamxda7/ctxup/actions/workflows/matrix.yml/badge.svg)](https://github.com/sohamxda7/ctxup/actions/workflows/matrix.yml)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/sohamxda7/ctxup/badge)](https://scorecard.dev/viewer/?uri=github.com/sohamxda7/ctxup)

One script to install, update and remove **Citrix Workspace™ app** on Linux.

Getting the Citrix client onto a Linux machine usually means clicking through
a download page, picking the right file out of ten, answering installer
prompts, and then finding out which libraries the package forgot to ask for.
`ctxup` does all of that for you:

- detects your distribution and picks the right package (`.deb`, `.rpm` or
  tarball)
- lists every release Citrix publishes for Linux and installs the one you choose
- checks the download against the SHA-256 published by Citrix
- installs the libraries the client needs, including the ones the Citrix
  packages do not declare
- upgrades, reinstalls or downgrades an existing installation safely
- adds your system's CA certificates to the client, which avoids the common
  "SSL error 61"
- verifies the result, and removes everything again when you ask

It is a single bash file with no dependencies beyond `curl` and the tools every
distribution ships.

## Quick start

```sh
curl -fsSLO https://github.com/sohamxda7/ctxup/releases/latest/download/ctxup
chmod +x ctxup
./ctxup
```

Running it without arguments opens a menu:

```
ctxup 0.1.0 - Citrix Workspace app for Linux

System:     Ubuntu 24.04.5 LTS (ubuntu 24.04, amd64)
Installed:  nothing

  1) Install the latest release (2608)
  2) Choose a version to install
  3) Check the installation
  4) Uninstall
  q) Quit
Choice:
```

Type the number and press Enter. Option 2 shows the full version list and you
pick one by its number. `ctxup` asks for `sudo` only when it starts changing
the system.

## Commands

| Command | What it does |
| --- | --- |
| `ctxup` | Interactive menu |
| `ctxup install` | Install or update to the latest release |
| `ctxup install --version 2604.10` | Install a specific release |
| `ctxup list` | Show the releases Citrix publishes for Linux |
| `ctxup status` | Show the detected system and what is installed |
| `ctxup check` | Verify an installed client |
| `ctxup uninstall` | Remove the client, keep your settings |
| `ctxup uninstall --purge` | Remove the client and all settings |
| `ctxup download` | Download and verify a package without installing it |

Useful options (see `ctxup --help` for all of them):

| Option | Meaning |
| --- | --- |
| `--yes`, `--accept-eula` | Unattended run. The licence needs its own flag on purpose. |
| `--from-file PATH` | Install a package you already downloaded (offline machines) |
| `--clean` | Remove the existing copy first instead of upgrading in place |
| `--with-usb` | Also install the USB redirection package |
| `--app-protection` | Install App Protection. It cannot be switched off afterwards. |
| `--dry-run` | Show what would happen and stop |

Unattended example:

```sh
sudo ./ctxup install --yes --accept-eula
```

## About LTSR

Citrix publishes Long Term Service Releases only for the Windows client. For
Linux there are only Current Releases, so `ctxup list` shows every Linux build
as a Current Release and there is no LTSR option to choose.

## Supported distributions

Each release below was taken through the full test cycle (install the previous
release, upgrade to the latest, repeat install, check, clean reinstall,
downgrade, uninstall, purge) in a systemd container on 2026-11-16, with Citrix
Workspace app 2604.10 and 2608.

| Distribution | Releases | Package used | Result |
| --- | --- | --- | --- |
| Ubuntu | 22.04, 24.04 | `.deb` | All steps pass |
| Ubuntu | 26.04, 26.10 | `.deb` | All steps pass with 2608. Release 2604.10 installs but cannot run there (it needs `libxml2.so.2`), and ctxup reports that. |
| Debian | 12, 13 | `.deb` | All steps pass |
| Rocky Linux, AlmaLinux (RHEL-compatible) | 8, 9 | `.rpm` | All steps pass |
| Rocky Linux, AlmaLinux (RHEL-compatible) | 10 | tarball | All steps pass with 2608. Release 2604.10 installs, but its self-service window does not start. |

Red Hat Enterprise Linux itself is detected the same way as Rocky and Alma but
was not part of the container run, because the Red Hat base images cannot
install the graphical libraries without a subscription.

Derivatives are mapped to their base release through `/etc/os-release`: Linux
Mint, Pop!_OS, Zorin OS and elementary OS to their Ubuntu base; LMDE, MX Linux
and Raspberry Pi OS to their Debian base. Only detection is tested for these,
not a full install.

Other releases are refused by default. `--force` lets you try anyway.

Not supported: Fedora and openSUSE. Fedora no longer ships the WebKitGTK
version Citrix's RPM requires.

Architectures: x86_64 everywhere; ARM64 on Debian and Ubuntu, where Citrix
provides a package. The ARM64 path is covered by unit tests only.

## How an existing installation is handled

| Situation | What ctxup does |
| --- | --- |
| Nothing installed | Installs |
| Older version, same package type | Upgrades in place, settings kept |
| Same version | Does nothing in unattended mode; asks in interactive mode; `--clean` reinstalls |
| Newer version installed | Asks, then removes it and installs the older one |
| Installed another way (for example from the tarball) | Asks, then removes it first. Citrix does not support mixing install methods. |
| App Protection present | Removes the old copy first, as Citrix does not support upgrading over it, and tells you to reboot |

Your personal settings in `~/.ICAClient` survive all of these. Only
`uninstall --purge` removes them.

## What `check` verifies

- every shared library the session client (`wfica`), the self-service window
  and the helper daemons link against can be found
- which optional features (scanner redirection, Kerberos SSO, webcam effects
  and so on) are missing a library
- the logging service is running
- the number of certificates in the client keystore
- the summary of Citrix's own `workspacecheck.sh`, with the full output saved
  to a file

Citrix's script always exits successfully and raises false alarms on systems
without a display, so `ctxup` treats it as information and bases its own
verdict on the library scan.

## Known limits

- **X11 only.** Citrix does not support Wayland. Sessions run through
  XWayland and may misbehave.
- **RHEL 10 family.** Citrix's RPM requires WebKitGTK 4.0, which RHEL 10 does
  not have, so `ctxup` installs the Citrix tarball there and enables EPEL for
  WebKitGTK 4.1 (after asking). USB redirection and App Protection cannot be
  installed unattended on this route. Release 2604.10 installs, but its
  self-service window does not start; expect the same from older releases.
- **Ubuntu 26.04 and newer.** Use release 2608 or newer. Release 2604.10
  links against a library Ubuntu no longer ships; `ctxup` installs it if asked
  and reports exactly what is missing.
- **deviceTRUST and EPA** can only be selected on Debian and Ubuntu.
- **Not tested here:** opening a real session, USB redirection and App
  Protection. They need a desktop, hardware or a full boot, which the
  container tests do not have.
- The download step depends on the layout of citrix.com. If Citrix changes
  its pages, `ctxup` stops with a clear message rather than guessing; use
  `--from-file` until it is updated.

## Is it safe to run?

Read it first: it is one file. Beyond that, this repository runs the following
checks, and it is worth knowing what each one does and does not prove.

| Check | What it tells you |
| --- | --- |
| ShellCheck, shfmt | The script has no known shell pitfalls and is consistently formatted |
| Unit tests | Version parsing, OS detection and upgrade decisions behave as documented |
| Distribution matrix | The real Citrix packages install, upgrade and uninstall on every supported release |
| CodeQL, zizmor, actionlint | The GitHub workflows themselves are not exploitable or misconfigured |
| gitleaks | No credentials were committed |
| OpenSSF Scorecard | An outside score of the repository's security practices |
| Dependabot | Keeps the pinned GitHub Actions up to date. It does not scan shell code. |
| Build provenance | A release file was built by this repository's workflow from the tagged commit |

None of these can certify that code is free of malice; they make tampering
visible and catch mistakes. To verify a downloaded release:

```sh
gh attestation verify ctxup --repo sohamxda7/ctxup
sha256sum -c SHA256SUMS
```

See [SECURITY.md](SECURITY.md) for what the script does on your machine.

## Running the tests

Unit tests need [bats](https://github.com/bats-core/bats-core):

```sh
bats tests/unit
```

The distribution matrix needs podman and about 2 GB of Citrix packages, which
are fetched once into `tests/.cache`:

```sh
tests/fetch-packages.sh
tests/matrix.sh                 # all releases
tests/matrix.sh debian-13       # just one
```

Each target is built from the official base image with systemd added, then
taken through install, upgrade, repeat install, check, reinstall, downgrade
and uninstall. Logs land in `tests/.results`.

## Licence and trademarks

`ctxup` is released under the [MIT licence](LICENSE).

It contains no Citrix software. The client is downloaded from citrix.com on
your machine and is subject to the
[Citrix licence agreement](https://www.cloud.com/content/dam/cloud/documents/legal/end-user-agreement.pdf),
which you are asked to accept before anything is installed.

Citrix and Citrix Workspace are trademarks of Cloud Software Group, Inc.
and/or its subsidiaries. This project is not affiliated with, endorsed by or
sponsored by Citrix or Cloud Software Group.
