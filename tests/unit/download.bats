#!/usr/bin/env bats

load helper

setup() {
  load_ctxup
  SRC="$BATS_TEST_TMPDIR/src"
  DEST="$BATS_TEST_TMPDIR/dest"
  mkdir -p "$SRC" "$DEST"
  printf 'package body\n' >"$SRC/icaclient_1.2.3.4_amd64.deb"
  GOOD=$(sha256sum "$SRC/icaclient_1.2.3.4_amd64.deb" | cut -d' ' -f1)
  URL="file://$SRC/icaclient_1.2.3.4_amd64.deb"
}

@test "download: matching checksum keeps the file" {
  run download_package "icaclient_1.2.3.4_amd64.deb|$URL|$GOOD" "$DEST"
  [ "$status" -eq 0 ]
  [ -f "$DEST/icaclient_1.2.3.4_amd64.deb" ]
}

@test "download: wrong checksum aborts and removes the file" {
  bad=$(printf '%064d' 0)
  run download_package "icaclient_1.2.3.4_amd64.deb|$URL|$bad" "$DEST"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Checksum mismatch"* ]]
  [ ! -e "$DEST/icaclient_1.2.3.4_amd64.deb" ]
}

@test "download: missing checksum is refused by default" {
  run download_package "icaclient_1.2.3.4_amd64.deb|$URL|" "$DEST"
  [ "$status" -ne 0 ]
  [ ! -e "$DEST/icaclient_1.2.3.4_amd64.deb" ]
}

@test "download: missing checksum is accepted with --no-verify" {
  OPT_NO_VERIFY=1
  run download_package "icaclient_1.2.3.4_amd64.deb|$URL|" "$DEST"
  [ "$status" -eq 0 ]
  [ -f "$DEST/icaclient_1.2.3.4_amd64.deb" ]
}

@test "download: unreachable file fails" {
  run download_package "x.deb|file://$SRC/missing.deb|$GOOD" "$DEST"
  [ "$status" -ne 0 ]
}
