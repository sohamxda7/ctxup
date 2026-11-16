# Security

## Reporting a problem

Please report security problems privately through GitHub: open the
**Security** tab of this repository and choose **Report a vulnerability**.
Do not open a public issue for something that could put users at risk.

Reports about the Citrix software itself belong with Citrix, not here.

## What ctxup does on your machine

ctxup is a single bash script. It is meant to be read before it is run.

- It talks to two hosts: `www.citrix.com` (version list and download pages)
  and `downloads.citrix.com` (the packages). On RHEL 10 it may also enable
  the EPEL repository, after asking.
- Every package is checked against the SHA-256 that Citrix publishes next to
  the download link. A mismatch stops the installation.
- It needs root to install packages. It re-runs itself through `sudo` only
  at the point where changes start; listing versions, `status` and
  `--dry-run` need no privileges.
- It sends nothing anywhere. There is no telemetry.
- It ships no Citrix code. The Citrix licence does not allow redistribution,
  so the packages are always fetched from Citrix by the machine that
  installs them.

## Verifying a release

Each release is built by the `release.yml` workflow in this repository and
carries a signed build provenance attestation.

```sh
gh attestation verify ctxup --repo sohamxda7/ctxup
sha256sum -c SHA256SUMS
```

The first command proves the file was produced by this repository's release
workflow from the tagged commit. The second checks the download against the
published checksum.
