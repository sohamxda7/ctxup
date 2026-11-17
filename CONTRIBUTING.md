# Contributing

Bug reports, fixes and test results from real machines are all welcome.

## Reporting a problem

Open an issue with the bug form. The three things that make a report
actionable are:

- the output of `ctxup status`
- the command you ran and what it printed
- the end of `/var/log/ctxup.log` if the failure happened during an install

If Citrix changed its download pages and `ctxup list` or `ctxup install` can
no longer find packages, say so in the title; that is the most time-critical
kind of breakage.

Security problems go through private reporting, not issues. See
[SECURITY.md](SECURITY.md).

## Making a change

1. Keep it one file. `ctxup` has to stay a single script that needs only
   bash, curl and the standard tools.
2. Format and lint before you commit:

   ```sh
   shfmt -w -i 2 -ci ctxup tests/*.sh
   shellcheck ctxup tests/*.sh
   ```

3. Run the unit tests, and add one for the behaviour you changed:

   ```sh
   bats tests/unit
   ```

4. If you touched installing, upgrading or removing, run the affected
   distributions through the container matrix:

   ```sh
   tests/fetch-packages.sh
   tests/matrix.sh ubuntu-24.04 rocky-9
   ```

5. Changes around services, App Protection, SELinux or anything that only
   shows after a reboot can be tried in a virtual machine; see
   [tests/vm](tests/vm/README.md).

The script must keep working on bash 4.4, which is what RHEL 8 ships, so
avoid newer features such as `${var@Q}` or `wait -p`.

## Adding a distribution

A new release needs three things: an entry in the supported list at the top
of `ctxup`, an `os-release` sample in `tests/fixtures/os-release` with a test
in `tests/unit/os_detect.bats`, and a line in `tests/matrix.sh` with a passing
run.

## What cannot be accepted

- Citrix packages, or anything extracted from them. The Citrix licence does
  not allow redistribution.
- Workarounds that link one library version in place of another (for example
  WebKitGTK 4.1 as 4.0). They appear to work and then crash.
