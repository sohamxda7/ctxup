# ctxup

[![Lint and unit tests](https://github.com/sohamxda7/ctxup/actions/workflows/lint.yml/badge.svg)](https://github.com/sohamxda7/ctxup/actions/workflows/lint.yml)
[![Distribution matrix](https://github.com/sohamxda7/ctxup/actions/workflows/matrix.yml/badge.svg)](https://github.com/sohamxda7/ctxup/actions/workflows/matrix.yml)
[![Security checks](https://github.com/sohamxda7/ctxup/actions/workflows/security.yml/badge.svg)](https://github.com/sohamxda7/ctxup/actions/workflows/security.yml)
[![Latest release](https://img.shields.io/github/v/release/sohamxda7/ctxup)](https://github.com/sohamxda7/ctxup/releases/latest)
[![Licence: MIT](https://img.shields.io/github/license/sohamxda7/ctxup)](LICENSE)

Install, update and remove the **Citrix Workspace app** on Linux with one
bash script.

`ctxup` detects your distribution, shows the releases Citrix currently offers,
downloads the right package from citrix.com, checks it, installs it together
with the libraries it needs, and can remove it again without leaving anything
behind.

- [Quick start](#quick-start)
- [What it does](#what-it-does)
- [Commands](#commands)
- [Supported distributions](#supported-distributions)
- [How an existing installation is handled](#how-an-existing-installation-is-handled)
- [Troubleshooting and FAQ](#troubleshooting-and-faq)
- [Known limits](#known-limits)
- [How it is tested](#how-it-is-tested)
- [Is it safe to run?](#is-it-safe-to-run)
- [Contributing](#contributing)
- [Licence and trademarks](#licence-and-trademarks)

## Quick start

Download the script and its checksum into an empty folder, verify, then run:

```sh
mkdir -p ~/ctxup-download && cd ~/ctxup-download
base=https://github.com/sohamxda7/ctxup/releases/latest/download
curl --proto '=https' --tlsv1.2 -fsSL -o ctxup "$base/ctxup"
curl --proto '=https' --tlsv1.2 -fsSL -o SHA256SUMS "$base/SHA256SUMS"
sha256sum -c SHA256SUMS
chmod +x ctxup
./ctxup
```

The script is saved to a file rather than piped into a shell, so you can read
it before running it (`less ctxup`). It asks for `sudo` when it needs to
change the system.

Running it without arguments opens a menu:

```text
ctxup 0.1.1 - Citrix Workspace app for Linux

System:     Ubuntu 24.04.5 LTS (ubuntu 24.04, amd64)
Installed:  nothing

  1) Install or update to the latest release
  2) Choose a version to install
  3) Check the installation
  4) Uninstall
  5) Uninstall and remove all settings
  6) List available versions
  q) Quit
Choice:
```

Type a number and press Enter. After each action you return to the menu.

For an unattended install:

```sh
sudo ./ctxup install --yes --accept-eula
```

## What it does

- **Picks the right package.** `.deb` on Debian and Ubuntu, `.rpm` on RHEL 8
  and 9, and the Citrix tarball on RHEL 10 and Fedora, where the RPM cannot be
  installed.
- **Lets you choose the version.** Latest by default, or any release
  currently offered on citrix.com, picked from a numbered list.
- **Verifies the download** against the SHA-256 Citrix publishes next to each
  file.
- **Installs missing libraries.** The Citrix packages need libraries they do
  not declare. `ctxup` scans the installed client for unresolved libraries and
  installs the matching distribution packages.
- **Answers the installer's questions** (App Protection, deviceTRUST, EPA) so
  nothing stops halfway. All three are off unless you ask for them.
- **Adds your system's CA certificates** to the client's own keystore, which
  prevents the common "SSL error 61".
- **Handles what is already there**: upgrade, reinstall, downgrade, or a copy
  installed some other way.
- **Checks the result** and tells you which features, if any, are missing a
  library.
- **Removes everything** on request, optionally including settings.

### About LTSR

Citrix publishes Long Term Service Releases only for the Windows client. For
Linux there are only Current Releases, so `ctxup list` labels every Linux
build as a Current Release and there is no LTSR to choose.

## Commands

| Command | What it does |
| --- | --- |
| `ctxup` | Interactive menu |
| `ctxup install` | Install or update to the latest release |
| `ctxup install --version 2604.10` | Install a specific release |
| `ctxup install --choose` | Pick the release from a numbered list |
| `ctxup list` | Show the releases Citrix offers for Linux |
| `ctxup status` | Show the detected system and what is installed |
| `ctxup check` | Verify an installed client |
| `ctxup uninstall` | Remove the client, keep your settings |
| `ctxup uninstall --purge` | Remove the client and all settings |
| `ctxup download` | Download and verify a package without installing it |

Common options (`ctxup --help` lists all of them):

| Option | Meaning |
| --- | --- |
| `--yes` | Answer yes to questions |
| `--accept-eula` | Accept the Citrix licence without being asked. Deliberately separate from `--yes`. |
| `--from-file PATH` | Install a package you already downloaded, for machines without internet access |
| `--clean` | Remove the existing copy first instead of upgrading in place |
| `--with-usb` | Also install the USB redirection package |
| `--app-protection` | Install App Protection. It cannot be switched off afterwards. |
| `--dry-run` | Show what would happen and stop |
| `--force` | Try a distribution release that is not on the tested list |

## Supported distributions

Every release below is taken through the same cycle in a systemd container,
using the real Citrix packages: install the previous release, upgrade to the
latest as an ordinary user through `sudo`, repeat the install, check, clean
reinstall, downgrade, uninstall and purge. The
[distribution matrix](https://github.com/sohamxda7/ctxup/actions/workflows/matrix.yml)
workflow repeats it every week.

| Distribution | Releases | Package used | Notes |
| --- | --- | --- | --- |
| Ubuntu | 22.04, 24.04 | `.deb` | |
| Ubuntu | 26.04, 26.10 | `.deb` | Needs Citrix release 2608 or newer |
| Debian | 12, 13 | `.deb` | |
| Linux Mint | 22.3 | `.deb` | Treated as Ubuntu 24.04 |
| LMDE | 7 | `.deb` | Treated as Debian 13 |
| RHEL, Rocky Linux, AlmaLinux | 8, 9 | `.rpm` | |
| RHEL, Rocky Linux, AlmaLinux | 10 | tarball | Self-service window needs release 2608 or newer; EPEL is enabled |
| Fedora | 44, 45 | tarball | Self-service window needs release 2608 or newer |

The RHEL rows are tested on Rocky Linux and AlmaLinux. Red Hat's own container
images cannot install the graphical libraries without a subscription, so RHEL
itself is not part of the automated run.

Derivatives are mapped to their base release through `/etc/os-release`: Linux
Mint, Pop!_OS, Zorin OS and elementary OS to their Ubuntu base; LMDE, MX Linux
and Raspberry Pi OS to their Debian base. Linux Mint and LMDE go through the
full cycle above; for the others only the detection is tested.

Releases outside the table are refused unless you pass `--force`.

openSUSE and Arch Linux are not supported. Arch users have the
[`icaclient` AUR package](https://aur.archlinux.org/packages/icaclient).

Architectures: x86_64 everywhere. ARM64 on Debian and Ubuntu, where Citrix
provides a package; that path is covered by unit tests only.

## How an existing installation is handled

| Situation | What ctxup does |
| --- | --- |
| Nothing installed | Installs |
| Older version, same package type | Upgrades in place, settings kept |
| Same version | Does nothing in unattended mode, asks in interactive mode; `--clean` reinstalls |
| Newer version installed | Asks, then removes it and installs the older one |
| Installed another way, for example from the tarball | Asks, then removes it first. Citrix does not support mixing install methods. |
| App Protection present | Removes the old copy first, because Citrix does not support upgrading over it, and tells you to reboot |
| A half-finished install from an earlier failure | Treated as installed, so it can be repaired or removed |

Personal settings in `~/.ICAClient` survive all of these. Only
`uninstall --purge` removes them.

## Troubleshooting and FAQ

Start with `ctxup check`. It reports missing libraries, the state of the
logging service and the number of trusted certificates, and saves the output
of Citrix's own `workspacecheck.sh` to a file. Installation output is kept in
`/var/log/ctxup.log`.

### SSL error 61: "You have not chosen to trust ..."

The client only trusts certificates in its own keystore, which ships with a
short list. `ctxup install` adds the system CA store to it. If your company
uses a private CA, add it to the system store first (`update-ca-certificates`
on Debian and Ubuntu, `update-ca-trust` on RHEL and Fedora) and run
`ctxup install --clean` again.

### Fedora or RHEL 10: "nothing provides webkit2gtk3"

That message comes from installing Citrix's RPM by hand. The RPM requires
WebKitGTK 4.0, which these distributions no longer ship. `ctxup` uses the
Citrix tarball there, which is built against WebKitGTK 4.1.

### It installs but the Workspace window does not open

Run `ctxup check`. If it reports missing libraries for the self-service
window, you are most likely on a release older than 2608 on a distribution
that only has WebKitGTK 4.1. Install 2608 or newer. Sessions started from a
browser are not affected.

### The browser downloads a `.ica` file instead of starting the session

Open the file with "Citrix Workspace Engine", or make it the default:

```sh
xdg-mime default wfica.desktop application/x-ica
```

Browsers installed as Snap or Flatpak packages are sandboxed and may not be
able to start the client at all; a natively packaged browser avoids that.

### Wayland

Citrix supports X11 only. Under Wayland the client runs through XWayland,
which works for many people but can show keyboard, clipboard or multi-monitor
problems. Logging in to an "on Xorg" session is the dependable fix.

### Why does the licence link go to cloud.com?

Citrix belongs to Cloud Software Group, which hosts the licence text on
cloud.com. It is the same document the citrix.com download page asks you to
accept.

### Is this the same as Citrix Receiver or `icaclient`?

Yes. Citrix Receiver is the old name of Citrix Workspace app, and `icaclient`
is the name of its Linux package.

### The download step stopped working

`ctxup` reads the download pages on citrix.com. If Citrix changes their
layout, it stops with a message rather than guessing. Download the package in
a browser and use `ctxup install --from-file PATH` until `ctxup` is updated,
and please open an issue.

## Known limits

- **RHEL 10 and Fedora.** `ctxup` installs the Citrix tarball there. On
  RHEL 10 it enables EPEL for WebKitGTK 4.1, after asking. USB redirection and
  App Protection cannot be installed unattended on this route.
- **Older releases on newer distributions.** Releases before 2608 were built
  against libraries that Ubuntu 26.04, RHEL 10 and Fedora no longer ship.
  `ctxup` installs them if asked and reports exactly what is missing.
- **deviceTRUST and EPA** can only be selected on Debian and Ubuntu.
- **App Protection** is supported by Citrix on Ubuntu 22.04/24.04 and RHEL 9
  only. `ctxup` asks before installing it anywhere else, and refuses on RHEL 8,
  whose C library is too old for Citrix's App Protection service to start. It needs a reboot
  after installing and after removing, and it cannot be switched off without
  removing the client. Until that reboot, running programs still carry its
  library and can recreate an empty `~/.ICAClient`; run
  `ctxup uninstall --purge` once more afterwards if that matters to you.
- **Citrix asks for its licence once more.** The first time each user starts
  the client, Citrix shows its own licence window. That is separate from the
  question `ctxup` asks.
- **Not covered by any test:** a real session against a Citrix server, and
  moving a real USB device into a session. Both need a Citrix environment
  and an account, and Citrix offers no public test server.
- **The checksum comes from citrix.com**, the same site as the download. It
  catches a corrupted or swapped file, not a compromise of citrix.com itself.

## How it is tested

Containers cannot boot, enforce SELinux or show a window, so the tests run at
three levels:

| Level | What runs | Where |
| --- | --- | --- |
| Unit tests | Parsing, OS detection, upgrade decisions | Every push |
| Container matrix | Install, upgrade, downgrade, uninstall and purge with the real Citrix packages on 16 releases | Every push and weekly |
| [Virtual machines](tests/vm/README.md) | Everything a container cannot show, see below | By hand before a release |

The virtual machine run uses the vendors' cloud images of Ubuntu 24.04 and
26.04, Debian 13, Rocky Linux 8, 9 and 10 and Fedora 44, each with a GNOME
desktop. On every one of them:

- an ordinary user installs through `sudo`, with SELinux enforcing on Rocky
  and Fedora and AppArmor on Ubuntu and Debian, and the audit log is checked
  for denials caused by the client;
- the machine is rebooted and the Citrix services have to come back;
- the self-service window, the preferences window and the session client are
  started in the logged-in Wayland session and have to stay up without a
  crash.

USB redirection, App Protection, deviceTRUST and EPA are installed where
Citrix offers them (Ubuntu 24.04 and 26.04, Debian 13, Rocky 9; USB only on
Rocky 8), followed by a reboot, an
uninstall and another reboot, to check that the machine still starts and
nothing is left behind.

## Is it safe to run?

Read it first: it is one file. Beyond that, this repository runs the checks
below, and it is worth knowing what each one does and does not prove.

| Check | What it tells you |
| --- | --- |
| ShellCheck, shfmt | No known shell pitfalls, consistent formatting |
| Unit tests | Version parsing, OS detection and upgrade decisions behave as documented |
| Distribution matrix | The real Citrix packages install, upgrade and uninstall on every supported release |
| bash 4.4 run | The script starts on the oldest bash it supports |
| Spelling, Markdown and link checks | The documentation is in order |
| CodeQL, zizmor, actionlint | The GitHub workflows are not exploitable or misconfigured |
| gitleaks, GitHub secret scanning | No credentials were committed |
| OpenSSF Scorecard | An outside score of the repository's security practices |
| Dependabot | Keeps the pinned GitHub Actions current. It does not scan shell code. |
| Build provenance | A release file was built by this repository's workflow from the tagged commit |

None of these can certify that code is free of malice. They catch mistakes
and make tampering visible. Releases cannot be changed after publication, and
you can verify one yourself:

```sh
gh attestation verify ctxup --repo sohamxda7/ctxup
sha256sum -c SHA256SUMS
```

[SECURITY.md](SECURITY.md) describes what the script does on your machine and
how to report a vulnerability.

## Contributing

Bug reports, fixes and test results from real machines are welcome. See
[CONTRIBUTING.md](CONTRIBUTING.md) for how to run the linters, the unit tests
and the container matrix.

## Licence and trademarks

`ctxup` is released under the [MIT licence](LICENSE).

It contains no Citrix software. The client is downloaded from citrix.com on
your machine and is subject to the
[Citrix licence agreement](https://www.cloud.com/content/dam/cloud/documents/legal/end-user-agreement.pdf),
which you are asked to accept before anything is installed.

Citrix and Citrix Workspace are trademarks of Cloud Software Group, Inc.
and/or its subsidiaries. This project is not affiliated with, endorsed by or
sponsored by Citrix or Cloud Software Group.
