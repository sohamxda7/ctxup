#!/usr/bin/env bats

load helper

setup() { load_ctxup; }

pick() { # page family arch kind -> file name
  OS_FAMILY=$2 OS_ARCH=$3
  parse_packages <"$FIXTURES/pages/$1.html" | pick_package "$4" | cut -d'|' -f1
}

@test "index: Linux releases only, newest first" {
  run parse_index <"$FIXTURES/pages/index.html"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "2608|/downloads/workspace-app/linux/workspace-app-for-linux-latest.html" ]
  [ "${lines[1]%%|*}" = "2604.10" ]
  [ "${lines[2]%%|*}" = "2604" ]
  [ "${#lines[@]}" -eq 19 ]
  [[ "$output" != *indows* ]]
  [[ "$output" != *SDK* ]]
}

@test "index: no duplicate versions" {
  run bash -c "source '$REPO_ROOT/ctxup'; { cat '$FIXTURES/pages/index.html'; cat '$FIXTURES/pages/index.html'; } | parse_index | cut -d'|' -f1 | sort | uniq -d"
  [ -z "$output" ]
}

@test "packages: every link is paired with its checksum" {
  run parse_packages <"$FIXTURES/pages/2608.html"
  [ "${#lines[@]}" -eq 10 ]
  [ "${lines[0]}" = "icaclient_26.08.0.225_amd64.deb|https://downloads.citrix.com/27152/icaclient_26.08.0.225_amd64.deb?__gda__=exp=1700000000~acl=/*~hmac=0000000000000000|c97e264e6896c7772c71f4fef6a3d18d853e0095b65720a8e8aad5b1b30d3f4d" ]
  for line in "${lines[@]}"; do
    [[ "$line" =~ \|[0-9a-f]{64}$ ]]
  done
}

@test "packages: a link without a checksum is kept with an empty sum" {
  run parse_packages <<<'<a rel="//downloads.citrix.com/1/icaclient_1.2.3.4_amd64.deb?__gda__=x">'
  [ "$output" = "icaclient_1.2.3.4_amd64.deb|https://downloads.citrix.com/1/icaclient_1.2.3.4_amd64.deb?__gda__=x|" ]
}

@test "packages: &amp; in a link is decoded" {
  run parse_packages <<<'<a rel="//downloads.citrix.com/1/a_1.2.3_amd64.deb?x=1&amp;y=2">'
  [[ "$output" == *"?x=1&y=2|"* ]]
}

@test "pick: 2608 deb" { [ "$(pick 2608 deb amd64 main)" = icaclient_26.08.0.225_amd64.deb ]; }
@test "pick: 2608 deb arm64" { [ "$(pick 2608 deb arm64 main)" = icaclient_26.08.0.225_arm64.deb ]; }
@test "pick: 2608 usb deb" { [ "$(pick 2608 deb amd64 usb)" = ctxusb_26.08.0.225_amd64.deb ]; }
@test "pick: 2608 rpm skips the SuSE build" { [ "$(pick 2608 rpm amd64 main)" = ICAClient-rhel-gcc-8-26.08.0.225-0.x86_64.rpm ]; }
@test "pick: 2608 usb rpm" { [ "$(pick 2608 rpm amd64 usb)" = ctxusb-gcc-8-26.08.0.225-1.x86_64.rpm ]; }
@test "pick: 2608 app protection rpm" { [ "$(pick 2608 rpm amd64 appprotection)" = ctxappprotection-gcc-8-26.08.0.225-0.x86_64.rpm ]; }
@test "pick: 2608 tarball" { [ "$(pick 2608 rpm amd64 tarball)" = linuxx64-26.08.0.225.tar.gz ]; }
@test "pick: 2604.10 deb with gcc tag" { [ "$(pick 2604.10 deb amd64 main)" = icaclient-gcc-8_26.04.10.1_amd64.deb ]; }
@test "pick: 2604.10 tarball with gcc tag" { [ "$(pick 2604.10 deb amd64 tarball)" = linuxx64-gcc-8-26.04.10.1.tar.gz ]; }
@test "pick: 2402 rpm without gcc tag" { [ "$(pick 2402 rpm amd64 main)" = ICAClient-rhel-24.2.0.65-0.x86_64.rpm ]; }
@test "pick: 2402 deb ignores armhf" { [ "$(pick 2402 deb arm64 main)" = icaclient_24.2.0.65_arm64.deb ]; }

@test "pick: fails when nothing matches" {
  OS_FAMILY=deb OS_ARCH=amd64
  run pick_package main <<<"something-else.zip|https://example.invalid/x|"
  [ "$status" -ne 0 ]
}

@test "full_version from file names" {
  [ "$(full_version icaclient_26.08.0.225_amd64.deb)" = 26.08.0.225 ]
  [ "$(full_version icaclient-gcc-8_26.04.10.1_amd64.deb)" = 26.04.10.1 ]
  [ "$(full_version ICAClient-rhel-gcc-8-26.08.0.225-0.x86_64.rpm)" = 26.08.0.225 ]
  [ "$(full_version ICAClient-rhel-24.2.0.65-0.x86_64.rpm)" = 24.2.0.65 ]
  [ "$(full_version linuxx64-gcc-8-26.04.10.1.tar.gz)" = 26.04.10.1 ]
}
