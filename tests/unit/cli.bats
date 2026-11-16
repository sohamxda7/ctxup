#!/usr/bin/env bats

load helper

CTXUP="$BATS_TEST_DIRNAME/../../ctxup"

@test "--help lists every command" {
  run "$CTXUP" --help
  [ "$status" -eq 0 ]
  for word in install uninstall list status check download; do
    [[ "$output" == *"$word"* ]]
  done
}

@test "-V prints the version" {
  run "$CTXUP" -V
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^ctxup\ [0-9]+\.[0-9]+\.[0-9]+$ ]]
}

@test "unknown argument is an error" {
  run "$CTXUP" --frobnicate
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unknown argument"* ]]
}

@test "two commands are an error" {
  run "$CTXUP" install uninstall
  [ "$status" -ne 0 ]
}

@test "no command and no terminal prints usage" {
  run "$CTXUP" </dev/null
  [ "$status" -ne 0 ]
  [[ "$output" == *Usage* ]]
}

@test "unsupported distribution stops before anything is fetched" {
  CTXUP_OS_RELEASE="$FIXTURES/os-release/opensuse-15.6" run "$CTXUP" install --yes --accept-eula
  [ "$status" -ne 0 ]
  [[ "$output" == *"not supported"* ]]
}

@test "untested release is refused without --force" {
  CTXUP_OS_RELEASE="$FIXTURES/os-release/ubuntu-20.04" run "$CTXUP" install --dry-run --from-file /nonexistent.deb
  [ "$status" -ne 0 ]
  [[ "$output" == *"--force"* ]]
}

@test "--from-file with the wrong package type is refused" {
  touch "$BATS_TEST_TMPDIR/ICAClient-rhel-1.2.3.4-0.x86_64.rpm"
  CTXUP_OS_RELEASE="$FIXTURES/os-release/debian-12" run "$CTXUP" install --dry-run \
    --from-file "$BATS_TEST_TMPDIR/ICAClient-rhel-1.2.3.4-0.x86_64.rpm"
  [ "$status" -ne 0 ]
  [[ "$output" == *".deb"* ]]
}

@test "dry run reports the plan and changes nothing" {
  touch "$BATS_TEST_TMPDIR/icaclient_26.08.0.225_amd64.deb"
  CTXUP_OS_RELEASE="$FIXTURES/os-release/debian-12" run "$CTXUP" install --dry-run \
    --from-file "$BATS_TEST_TMPDIR/icaclient_26.08.0.225_amd64.deb"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Dry run: would install 26.08.0.225"* ]]
}

@test "the licence must be accepted explicitly when there is no terminal" {
  touch "$BATS_TEST_TMPDIR/icaclient_26.08.0.225_amd64.deb"
  CTXUP_OS_RELEASE="$FIXTURES/os-release/debian-12" run "$CTXUP" install --yes \
    --from-file "$BATS_TEST_TMPDIR/icaclient_26.08.0.225_amd64.deb" </dev/null
  [ "$status" -ne 0 ]
  [[ "$output" == *"--accept-eula"* ]]
}

@test "deviceTRUST is refused where Citrix has no unattended install for it" {
  CTXUP_OS_RELEASE="$FIXTURES/os-release/rockylinux-9" run "$CTXUP" install --dry-run --device-trust
  [ "$status" -ne 0 ]
  [[ "$output" == *"--device-trust"* ]]
}

@test "check without an installation says so and returns 1" {
  if [ -e /opt/Citrix/ICAClient ]; then skip "a client is installed on this machine"; fi
  run "$CTXUP" check
  [ "$status" -eq 1 ]
  [[ "$output" == *"not installed"* ]]
}

@test "piping the script into bash runs it" {
  run bash -c "bash -s -- -V < '$CTXUP'"
  [ "$status" -eq 0 ]
  [[ "$output" == ctxup\ * ]]
}

@test "--choose without a terminal is refused with a hint" {
  if ! command -v curl >/dev/null; then skip "needs curl and network"; fi
  CTXUP_OS_RELEASE="$FIXTURES/os-release/debian-12" CTXUP_INDEX_URL="file://$FIXTURES/pages/index.html" \
    run "$CTXUP" install --dry-run --choose </dev/null
  [ "$status" -ne 0 ]
  [[ "$output" == *"--version"* ]]
}

@test "the version list can be read from a saved page" {
  if ! command -v curl >/dev/null; then skip "needs curl"; fi
  CTXUP_INDEX_URL="file://$FIXTURES/pages/index.html" run "$CTXUP" list
  [ "$status" -eq 0 ]
  [[ "$output" == *"2608      Current Release (latest)"* ]]
  [[ "$output" == *"no LTSR for Linux"* ]]
}

@test "an unreachable index gives a clear error" {
  if ! command -v curl >/dev/null; then skip "needs curl"; fi
  CTXUP_FETCH_TRIES=1 CTXUP_INDEX_URL="file:///nonexistent/index.html" run "$CTXUP" list
  [ "$status" -ne 0 ]
  [[ "$output" == *"Could not reach"* ]]
}

@test "a page without Linux releases gives a clear error" {
  if ! command -v curl >/dev/null; then skip "needs curl"; fi
  echo '<html><a href="/x">Citrix Workspace app 2607 for Windows</a></html>' >"$BATS_TEST_TMPDIR/empty.html"
  CTXUP_INDEX_URL="file://$BATS_TEST_TMPDIR/empty.html" run "$CTXUP" list
  [ "$status" -ne 0 ]
  [[ "$output" == *"layout may have changed"* ]]
}
