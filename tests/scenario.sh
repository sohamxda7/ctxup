#!/usr/bin/env bash
#
# Runs inside a test container. Takes one release of the distribution through
# the whole life cycle of the client and prints one PASS/FAIL line per step.
#
# usage: scenario.sh OLD_PACKAGE NEW_PACKAGE [ok|unsupported]
#
# The third argument says whether the old release is expected to work on this
# distribution. With "unsupported" the test expects ctxup to install it and
# then report the missing libraries with a non-zero exit code.

set -u

OLD=$1
NEW=$2
OLD_EXPECT=${3:-ok}
CTXUP=/ctxup/ctxup
ICAROOT=/opt/Citrix/ICAClient
LOG=/tmp/scenario.log
: >"$LOG"

version_of() { grep -oE '[0-9]+(\.[0-9]+){2,}' <<<"${1##*/}" | head -n1; }
OLD_V=$(version_of "$OLD")
NEW_V=$(version_of "$NEW")

installed() { sed -n 's/^ID_VERSION=//p' "$ICAROOT"/pkginf/Ver.core.linux* 2>/dev/null | head -n1; }

step() {
  local name=$1
  shift
  echo "### $name" >>"$LOG"
  if "$@" >>"$LOG" 2>&1; then
    echo "PASS $name"
  else
    echo "FAIL $name"
  fi
}

# old_release -> installs the old release and checks the outcome
old_release() {
  local rc=0 out
  out=$("$CTXUP" install --yes --accept-eula --from-file "$OLD" 2>&1) || rc=$?
  echo "$out"
  [[ $(installed) == "$OLD_V" ]] || return 1
  if [[ $OLD_EXPECT == unsupported ]]; then
    [[ $rc -ne 0 ]] && grep -q "Libraries the session client needs are missing" <<<"$out"
  else
    [[ $rc -eq 0 ]]
  fi
}
install_old() { old_release; }
# The upgrade is started by an ordinary user, so the switch to sudo is tested.
upgrade_as_user() {
  id tester >/dev/null 2>&1 || useradd -m tester
  echo 'tester ALL=(ALL) NOPASSWD:ALL' >/etc/sudoers.d/tester
  su tester -c "'$CTXUP' install --yes --accept-eula --from-file '$NEW'" || return 1
  [[ $(installed) == "$NEW_V" ]] || return 1
  # Installed files must be usable by everyone, whatever root's umask is.
  su tester -c "test -x '$ICAROOT/wfica' && test -r '$ICAROOT/pkginf/Ver.core.linuxx64'"
}
check_when_absent() {
  local out rc=0
  out=$("$CTXUP" check 2>&1) || rc=$?
  echo "$out"
  [[ $rc -eq 1 ]] && grep -q "not installed" <<<"$out"
}
# Menu: check (nothing installed), back to the menu, list versions is not
# needed here, quit. The menu has to be shown again after the check.
menu_returns() {
  local out
  out=$(printf '3\n\nq\n' | script -qec "$CTXUP" /dev/null 2>&1) || true
  echo "$out"
  [[ $(grep -c "Choice:" <<<"$out") -ge 2 ]] && grep -q "nothing to check" <<<"$out"
}
repeat_is_noop() { "$CTXUP" install --yes --accept-eula --from-file "$NEW" 2>&1 | grep -q "Nothing to do"; }
check() { "$CTXUP" check; }
service_running() { systemctl is-active --quiet ctxcwalogd; }
system_certs() { [[ $(find "$ICAROOT/keystore/cacerts" -name 'ctxup-*.pem' | wc -l) -gt 50 ]]; }
clean_reinstall() { "$CTXUP" install --yes --accept-eula --clean --from-file "$NEW" && [[ $(installed) == "$NEW_V" ]]; }
downgrade() { old_release; }
uninstall_keeps_settings() {
  mkdir -p /root/.ICAClient && touch /root/.ICAClient/marker
  "$CTXUP" uninstall --yes || return 1
  [[ ! -e $ICAROOT && -e /root/.ICAClient/marker ]] || return 1
  "$CTXUP" status | grep -q "Installed:  nothing"
}
purge_leaves_nothing() {
  "$CTXUP" uninstall --yes --purge || return 1
  local left=0 path
  for path in "$ICAROOT" /etc/icaclient /root/.ICAClient /etc/init.d/ctxcwalogd \
    /etc/systemd/system/ctxcwalogd.service /lib/systemd/system/ctxcwalogd.service; do
    if [[ -e $path ]]; then
      echo "left behind: $path"
      left=1
    fi
  done
  if id citrixlog >/dev/null 2>&1; then
    echo "left behind: citrixlog user"
    left=1
  fi
  if command -v dpkg-query >/dev/null 2>&1 && dpkg-query -W icaclient >/dev/null 2>&1; then
    echo "left behind: dpkg record for icaclient"
    left=1
  fi
  if command -v rpm >/dev/null 2>&1 && rpm -q ICAClient >/dev/null 2>&1; then
    echo "left behind: ICAClient rpm"
    left=1
  fi
  return "$left"
}

step check-when-absent check_when_absent
step menu-returns menu_returns
step install-previous install_old
step upgrade-as-user upgrade_as_user
step repeat-is-noop repeat_is_noop
step check check
step service-running service_running
step system-certs system_certs
step clean-reinstall clean_reinstall
step downgrade downgrade
step uninstall-keeps-settings uninstall_keeps_settings
step purge-leaves-nothing purge_leaves_nothing
