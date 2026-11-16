# Security

## Supported versions

Only the latest release receives fixes. Please check that a problem still
exists there before reporting it.

## Reporting a vulnerability

Report vulnerabilities privately through GitHub's advisory form:
<https://github.com/sohamxda7/ctxup/security/advisories/new>

Do not open a public issue for something that could put users at risk.

You can expect a first reply within 7 days. Once a fix is ready it is
released and the advisory is published with credit to the reporter, unless
you prefer to stay anonymous. If a report turns out not to be a
vulnerability, you will be told why.

Reports about the Citrix software itself belong with Citrix, not here.

## What ctxup does on your machine

ctxup is a single bash script. It is meant to be read before it is run.

- It talks to two hosts: `www.citrix.com` (version list and download pages)
  and `downloads.citrix.com` (the packages). On RHEL 10 it may also enable
  the EPEL repository, after asking.
- Every package is checked against the SHA-256 that Citrix publishes next to
  the download link. A mismatch stops the installation.
- It needs root to install or remove packages and re-runs itself through
  `sudo` for those two commands. Listing versions, `status`, `check` and
  `--dry-run` need no privileges.
- On RHEL 10 and Fedora it runs Citrix's own tarball installer. To run it
  unattended, `ctxup` edits its copy of that installer so the yes/no
  questions take their defaults.
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
