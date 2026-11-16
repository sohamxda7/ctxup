#!/usr/bin/env bats

load helper

setup() { load_ctxup; }

check() { # fixture family base version
  detect "$1"
  [ "$OS_FAMILY" = "$2" ]
  [ "$OS_BASE" = "$3" ]
  [ "$OS_BASE_VER" = "$4" ]
  [ -z "$OS_PROBLEM" ]
}

@test "Ubuntu 22.04" { check ubuntu-22.04 deb ubuntu 22.04; }
@test "Ubuntu 24.04" { check ubuntu-24.04 deb ubuntu 24.04; }
@test "Ubuntu 26.04" { check ubuntu-26.04 deb ubuntu 26.04; }
@test "Ubuntu 26.10" { check ubuntu-26.10 deb ubuntu 26.10; }
@test "Debian 12" { check debian-12 deb debian 12; }
@test "Debian 13" { check debian-13 deb debian 13; }
@test "Rocky 8" { check rockylinux-8 rpm el 8; }
@test "Rocky 9" { check rockylinux-9 rpm el 9; }
@test "Rocky 10" { check rockylinux-10 rpm el 10; }
@test "AlmaLinux 8" { check almalinux-8 rpm el 8; }
@test "AlmaLinux 9" { check almalinux-9 rpm el 9; }
@test "AlmaLinux 10" { check almalinux-10 rpm el 10; }
@test "RHEL 10" { check rhel-10.3 rpm el 10; }

@test "Linux Mint maps to its Ubuntu base" { check linuxmint-22.3 deb ubuntu 24.04; }
@test "Pop!_OS maps to its Ubuntu base" { check pop-24.04 deb ubuntu 24.04; }
@test "LMDE maps to its Debian base" { check lmde-7 deb debian 13; }

@test "Kali is treated as Debian testing, outside the tested range" {
  detect kali-rolling
  [ "$OS_BASE" = debian ]
  [ "$OS_BASE_VER" = 14 ]
  [[ "$OS_PROBLEM" == *"outside the tested range"* ]]
}

@test "Ubuntu 20.04 is outside the tested range" {
  detect ubuntu-20.04
  [ "$OS_FAMILY" = deb ]
  [[ "$OS_PROBLEM" == *"outside the tested range"* ]]
}

@test "Fedora is rejected with a reason" {
  detect fedora-45
  [ -z "$OS_FAMILY" ]
  [[ "$OS_PROBLEM" == *Fedora* ]]
}

@test "openSUSE is rejected" {
  detect opensuse-15.6
  [ -z "$OS_FAMILY" ]
  [[ "$OS_PROBLEM" == *"not supported"* ]]
}

@test "arm64 is accepted on Debian family" {
  detect debian-12 aarch64
  [ "$OS_ARCH" = arm64 ]
  [ -z "$OS_PROBLEM" ]
}

@test "arm64 is rejected on RPM family" {
  detect rockylinux-9 aarch64
  [[ "$OS_PROBLEM" == *ARM64* ]]
}

@test "unknown CPU is rejected" {
  detect debian-12 riscv64
  [[ "$OS_PROBLEM" == *riscv64* ]]
}
