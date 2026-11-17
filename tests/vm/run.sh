#!/usr/bin/env bash
#
# Tests ctxup in a real virtual machine: the things a container cannot show.
# For each target it installs as an ordinary user, reboots, starts the Citrix
# programs in a GNOME session, installs the optional components, removes
# everything and checks that the machine is clean afterwards.
#
# usage: tests/vm/run.sh [--keep] TARGET [TARGET ...]   (see 'vm.sh targets')
#
# The packages are downloaded from citrix.com inside the machine, exactly as a
# user would. A target takes 30 to 60 minutes, most of it package downloads.

set -uo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo=$(cd "$here/../.." && pwd)
store=${CTXUP_VM_DIR:-$HOME/ctxup-vms}
vm=$here/vm.sh
keep=0
failed=0

step() { # name, command...
  local name=$1
  shift
  if "$@" >>"$log" 2>&1; then
    printf '  %-34s PASS\n' "$name"
  else
    printf '  %-34s FAIL\n' "$name"
    failed=1
    target_failed=1
  fi
}

guest() { "$vm" ssh "$target" "bash /root/guest.sh $*"; }

# shellcheck disable=SC2329  # called through step
launch() { # app seconds label
  guest gui-start "$1" || return 1
  sleep "$2"
  "$vm" shot "$target" "$3-$1" >/dev/null 2>&1 || true
  guest gui-alive "$1" || return 1
  guest gui-stop "$1"
}

launch_all() { # label
  step "self-service window ($1)" launch selfservice 30 "$1"
  step "preferences window ($1)" launch configmgr 12 "$1"
  step "session client ($1)" launch wfica 12 "$1"
}

run_target() {
  local flags services
  target=$1 target_failed=0
  log=$store/logs/run-$target.log
  mkdir -p "$store/logs"
  : >"$log"
  echo "== $target (log: $log)"

  "$vm" rm "$target"
  step "download and verify image" "$vm" images "$target"
  step "create and boot" "$vm" create "$target"
  [[ $target_failed -eq 0 ]] || return 0
  "$vm" put "$target" "$here/guest.sh" "$repo/ctxup" >>"$log" 2>&1
  "$vm" ssh "$target" 'install -o tester -g tester -m 755 /root/ctxup /home/tester/ctxup' >>"$log" 2>&1

  step "mandatory access control on" guest enforcing
  step "install as a user through sudo" guest ctxup install --yes --accept-eula
  step "check finds no problem" guest ctxup check
  step "no denials or crashes" guest denials

  step "install a desktop" guest desktop
  step "reboot" "$vm" reboot "$target"
  step "desktop session starts" guest session-ready
  step "log service back after reboot" guest services-up ctxcwalogd
  launch_all plain
  step "no denials or crashes" guest denials

  flags=$(guest extras-flags 2>>"$log")
  if [[ -n $flags ]]; then
    # shellcheck disable=SC2086  # the flags are separate words
    step "reinstall with optional parts" guest ctxup install --yes --accept-eula --clean $flags
    step "reboot" "$vm" reboot "$target"
    step "desktop session starts" guest session-ready
    services=(ctxcwalogd ctxusbd)
    [[ $flags == *--app-protection* ]] && services+=(AppProtectionService-install)
    step "optional services running" guest services-up "${services[@]}"
    launch_all extras
  fi

  step "uninstall and purge" guest ctxup uninstall --purge --yes
  step "reboot" "$vm" reboot "$target"
  if [[ -n $flags ]]; then
    # Until the reboot, running programs still carry the App Protection
    # library, and it writes ~/.ICAClient again when they exit.
    step "purge again after reboot" guest ctxup uninstall --purge --yes
  fi
  step "nothing left behind" guest clean

  if [[ $keep -eq 0 && $target_failed -eq 0 ]]; then
    "$vm" rm "$target"
  fi
}

if [[ ${1:-} == --keep ]]; then
  keep=1
  shift
fi
[[ $# -gt 0 ]] || {
  sed -n '3,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 2
}
for name in "$@"; do
  run_target "$name"
done
exit "$failed"
