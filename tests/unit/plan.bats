#!/usr/bin/env bats

load helper

setup() { load_ctxup; }

@test "version_cmp orders Citrix version numbers" {
  [ "$(version_cmp 26.08.0.225 26.08.0.225)" = eq ]
  [ "$(version_cmp 26.04.10.1 26.08.0.225)" = lt ]
  [ "$(version_cmp 26.08.0.225 26.04.10.1)" = gt ]
  [ "$(version_cmp 24.2.0.65 24.11.0.85)" = lt ]
  [ "$(version_cmp 26.04.0.9 26.04.10.1)" = lt ]
}

@test "plan: nothing installed -> install" {
  [ "$(plan_action none "" deb 26.08.0.225)" = install ]
}

@test "plan: older package -> upgrade in place" {
  [ "$(plan_action deb 26.04.10.1 deb 26.08.0.225)" = upgrade ]
  [ "$(plan_action rpm 26.04.10.1 rpm 26.08.0.225)" = upgrade ]
}

@test "plan: older tarball -> replace, the Citrix installer will not overwrite unattended" {
  [ "$(plan_action tarball 26.04.10.1 tarball 26.08.0.225)" = replace ]
}

@test "plan: same version -> reinstall" {
  [ "$(plan_action rpm 26.08.0.225 rpm 26.08.0.225)" = reinstall ]
}

@test "plan: newer installed -> downgrade" {
  [ "$(plan_action deb 26.08.0.225 deb 26.04.10.1)" = downgrade ]
}

@test "plan: different install method -> replace" {
  [ "$(plan_action tarball 26.08.0.225 deb 26.08.0.225)" = replace ]
  [ "$(plan_action rpm 26.04.10.1 tarball 26.08.0.225)" = replace ]
}

@test "plan: unknown installed version -> replace" {
  [ "$(plan_action deb "" deb 26.08.0.225)" = replace ]
}

@test "install method: deb family, RHEL 8/9 rpm, RHEL 10 and Fedora tarball" {
  detect ubuntu-24.04 && [ "$(install_method_for_os)" = deb ]
  detect rockylinux-8 && [ "$(install_method_for_os)" = rpm ]
  detect almalinux-9 && [ "$(install_method_for_os)" = rpm ]
  detect rockylinux-10 && [ "$(install_method_for_os)" = tarball ]
  detect fedora-45 && [ "$(install_method_for_os)" = tarball ]
}

@test "deb package names are derived from library names" {
  [ "$(deb_candidates libxkbcommon.so.0)" = "libxkbcommon0t64 libxkbcommon0" ]
  [ "$(deb_candidates libwebkit2gtk-4.1.so.0)" = "libwebkit2gtk-4.1-0t64 libwebkit2gtk-4.1-0" ]
  [ "$(deb_candidates libsecret-1.so.0)" = "libsecret-1-0t64 libsecret-1-0" ]
  [ "$(deb_candidates libinput.so.10)" = "libinput10t64 libinput10" ]
  [ "$(deb_candidates libgtk-3.so.0)" = "libgtk-3-0t64 libgtk-3-0" ]
  [ "$(deb_candidates libgdk-3.so.0)" = "libgtk-3-0t64 libgtk-3-0" ]
  [ "$(deb_candidates libgstvideo-1.0.so.0)" = "libgstreamer-plugins-base1.0-0" ]
  [ -z "$(deb_candidates libopencv_core.so.410)" ]
}

@test "session files and self-service files are told apart" {
  is_core_file wfica
  is_core_file AuthManagerDaemon
  ! is_core_file selfservice
  is_selfservice_file selfservice
  is_selfservice_file lib/UIDialogLibWebKit3.so
  ! is_selfservice_file VDSCAN.DLL
  ! is_core_file VDSCAN.DLL
}

@test "tarball installer patch answers the proceed prompts and nothing else" {
  file="$BATS_TEST_TMPDIR/hinst"
  cat >"$file" <<'HINST'
getyesno(){
ANSWER=""
while test "$ANSWER" = ""
do
	read response
	test "x$response" = "x" && response=$1
done
}
install() {
	echo_no_nl "$instica4"

	getyesno $INSTALLER_NO
	user_prompt "$instusb2"
	getyesno $INSTALLER_NO
}
remove() {
	echo_no_nl "$instica9c"

	getyesno $INSTALLER_NO
}
menu() {
	read keynum
}
HINST
  run patch_hinst "$file"
  [ "$status" -eq 0 ]
  [ "$(grep -c 'ANSWER=\$INSTALLER_YES' "$file")" -eq 2 ]
  [ "$(grep -c 'getyesno \$INSTALLER_NO' "$file")" -eq 1 ]
  grep -q '^	response=$' "$file"
  grep -q 'read keynum' "$file"
}

@test "tarball installer patch reports an unknown installer" {
  file="$BATS_TEST_TMPDIR/hinst"
  echo 'echo something else' >"$file"
  run patch_hinst "$file"
  [ "$status" -ne 0 ]
}

@test "free space is reported in megabytes" {
  mb=$(free_mb /)
  [[ "$mb" =~ ^[0-9]+$ ]]
  [ "$(free_mb /nonexistent/deeper/path)" = "$mb" ]
}

@test "need_space stops when there is not enough room" {
  run need_space / 999999999 "the test"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Not enough disk space"* ]]
  run need_space / 1 "the test"
  [ "$status" -eq 0 ]
}

@test "clean_preload: removes the App Protection entry and the empty file" {
  CTXUP_TMP=$(mktemp -d)
  PRELOAD_FILE=$CTXUP_TMP/ld.so.preload
  echo "/usr/local/lib/AppProtection/libAppProtection.so" >"$PRELOAD_FILE"
  clean_preload all 2>/dev/null
  [ ! -e "$PRELOAD_FILE" ]
  rm -rf "$CTXUP_TMP"
}

@test "clean_preload: keeps entries that belong to other software" {
  CTXUP_TMP=$(mktemp -d)
  PRELOAD_FILE=$CTXUP_TMP/ld.so.preload
  printf '%s\n' /usr/lib/libother.so /usr/local/lib/AppProtection/libAppProtection.so >"$PRELOAD_FILE"
  clean_preload all 2>/dev/null
  [ "$(cat "$PRELOAD_FILE")" = "/usr/lib/libother.so" ]
  rm -rf "$CTXUP_TMP"
}

@test "clean_preload: without 'all' only drops entries whose library is gone" {
  CTXUP_TMP=$(mktemp -d)
  PRELOAD_FILE=$CTXUP_TMP/ld.so.preload
  mkdir -p "$CTXUP_TMP/AppProtection"
  touch "$CTXUP_TMP/AppProtection/live.so"
  printf '%s\n' "$CTXUP_TMP/AppProtection/live.so" "$CTXUP_TMP/AppProtection/gone.so" >"$PRELOAD_FILE"
  clean_preload 2>/dev/null
  [ "$(cat "$PRELOAD_FILE")" = "$CTXUP_TMP/AppProtection/live.so" ]
  rm -rf "$CTXUP_TMP"
}

@test "clean_preload: no file is not an error" {
  PRELOAD_FILE=/nonexistent/ld.so.preload
  clean_preload all
}

@test "app_protection_supported: only the systems Citrix lists" {
  OS_BASE=ubuntu OS_BASE_VER=24.04
  app_protection_supported
  OS_BASE=el OS_BASE_VER=9
  app_protection_supported
  OS_BASE=ubuntu OS_BASE_VER=26.04
  if app_protection_supported; then false; fi
  OS_BASE=debian OS_BASE_VER=13
  if app_protection_supported; then false; fi
  OS_BASE=el OS_BASE_VER=10
  if app_protection_supported; then false; fi
}

@test "glibc_at_least compares against the running C library" {
  getconf() { echo "glibc 2.28"; }
  if glibc_at_least 2.34; then false; fi
  glibc_at_least 2.28
  getconf() { echo "glibc 2.39"; }
  glibc_at_least 2.34
}

@test "glibc_at_least does not block when the version is unknown" {
  getconf() { return 1; }
  glibc_at_least 2.34
}
