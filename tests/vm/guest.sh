#!/usr/bin/env bash
#
# Runs inside a test machine as root; tests/vm/run.sh copies it there together
# with ctxup. Each sub-command does one thing and reports through its exit
# status, so run.sh can turn it into a pass or a fail.

set -uo pipefail

ICAROOT=/opt/Citrix/ICAClient
uid=$(id -u tester)

as_tester() { sudo -iu tester env NO_COLOR=1 "$@" </dev/null; }

# Run a command inside the logged-in desktop session of the test user.
in_session() {
  sudo -u tester env XDG_RUNTIME_DIR="/run/user/$uid" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" "$@" </dev/null
}

extras_flags() {
  local ID="" VERSION_ID=""
  # shellcheck source=/dev/null
  . /etc/os-release
  case $ID in
    ubuntu | debian) echo "--with-usb --app-protection --device-trust --epa" ;;
    fedora) echo "" ;;
    *)
      # RHEL 10 uses the tarball, which has no unattended extras. App
      # Protection needs a newer C library than RHEL 8 has.
      case ${VERSION_ID%%.*} in
        8) echo "--with-usb" ;;
        9) echo "--with-usb --app-protection" ;;
        *) echo "" ;;
      esac
      ;;
  esac
}

install_desktop() {
  local conf ID=""
  # shellcheck source=/dev/null
  . /etc/os-release
  # needrestart would restart the network service under the ssh connection.
  export DEBIAN_FRONTEND=noninteractive NEEDRESTART_SUSPEND=1
  case $ID in
    debian)
      apt-get update -q && apt-get install -y -q gnome-core open-vm-tools-desktop || return 1
      conf=/etc/gdm3/daemon.conf
      ;;
    ubuntu)
      apt-get update -q && apt-get install -y -q ubuntu-desktop-minimal open-vm-tools-desktop || return 1
      conf=/etc/gdm3/custom.conf
      ;;
    fedora)
      dnf install -y gdm gnome-shell gnome-session-wayland-session gnome-terminal \
        xorg-x11-server-Xwayland open-vm-tools-desktop dejavu-sans-fonts || return 1
      conf=/etc/gdm/custom.conf
      ;;
    *)
      dnf group install -y "Server with GUI" || dnf groupinstall -y "Server with GUI" || return 1
      dnf install -y open-vm-tools-desktop || return 1
      conf=/etc/gdm/custom.conf
      ;;
  esac
  mkdir -p "$(dirname "$conf")"
  touch "$conf"
  if grep -q '^\[daemon\]' "$conf"; then
    sed -i '/^\[daemon\]/a AutomaticLoginEnable=True\nAutomaticLogin=tester' "$conf"
  else
    printf '[daemon]\nAutomaticLoginEnable=True\nAutomaticLogin=tester\n' >>"$conf"
  fi
  mkdir -p /home/tester/.config
  echo yes >/home/tester/.config/gnome-initial-setup-done
  chown -R tester:tester /home/tester/.config
  systemctl set-default graphical.target
}

# Waits for the automatic login, then prepares the session for the launch tests.
session_ready() {
  local i
  for ((i = 0; i < 40; i++)); do
    loginctl list-sessions --no-legend | grep -q 'tester.*seat0' && break
    sleep 5
  done
  loginctl list-sessions --no-legend | grep -q 'tester.*seat0' || return 1
  sleep 15
  in_session gsettings set org.gnome.desktop.session idle-delay 0
  in_session gsettings set org.gnome.desktop.screensaver lock-enabled false
  # Citrix shows its own licence window on a user's first start. Accept it
  # here, as a person would, so the programs below get as far as their window.
  mkdir -p /home/tester/.ICAClient
  touch /home/tester/.ICAClient/.eula_accepted
  cat >/home/tester/test.ica <<ICA
[WFClient]
Version=2
[ApplicationServers]
Test=
[Test]
Address=192.0.2.10:1494
InitialProgram=#Test
TransportDriver=TCP/IP
WinStationDriver=ICA 3.0
DesiredHRES=800
DesiredVRES=600
ICA
  chown -R tester:tester /home/tester/.ICAClient /home/tester/test.ica
  in_session systemctl --user show-environment | grep -E '^XDG_SESSION_TYPE='
}

gui_start() {
  local cmd
  case $1 in
    selfservice) cmd=("$ICAROOT/selfservice") ;;
    configmgr) cmd=("$ICAROOT/util/configmgr") ;;
    wfica) cmd=("$ICAROOT/wfica" /home/tester/test.ica) ;;
    *) return 2 ;;
  esac
  in_session systemctl --user reset-failed "ctx-$1" 2>/dev/null
  in_session systemd-run --user --quiet --collect --unit="ctx-$1" "${cmd[@]}"
}

gui_alive() { [[ $(in_session systemctl --user is-active "ctx-$1" 2>/dev/null) == active ]]; }

gui_stop() {
  in_session systemctl --user stop "ctx-$1" 2>/dev/null
  pkill -u tester -f "$ICAROOT/" 2>/dev/null
  return 0
}

# Prints denials and crashes since boot that involve the client; fails if any.
denials() {
  local out=""
  if command -v ausearch >/dev/null 2>&1; then
    out=$(ausearch --input-logs -m avc,user_avc,selinux_err -ts boot 2>/dev/null | grep denied)
  else
    out=$(journalctl -b --no-pager 2>/dev/null | grep 'apparmor="DENIED"' |
      grep -iE 'citrix|icaclient|wfica|selfservice|ctxusb|ctxcwalog')
  fi
  out+=$(journalctl -b --no-pager 2>/dev/null |
    grep -iE '(segfault|core dumped).*(wfica|selfservice|ctx|AuthMan|ServiceRecord)')
  [[ -z $out ]] && return 0
  echo "$out" | tail -n 15 | cut -c1-300
  return 1
}

services_up() {
  local name rc=0
  for name in "$@"; do
    if ! systemctl is-active --quiet "$name"; then
      echo "$name is not active"
      rc=1
    fi
  done
  return "$rc"
}

# After a purge and a reboot nothing of the client may be left.
clean() {
  local rc=0 path
  if [[ -e /etc/ld.so.preload ]] && grep -q AppProtection /etc/ld.so.preload; then
    echo "/etc/ld.so.preload still lists App Protection"
    rc=1
  fi
  if /bin/true 2>&1 | grep -q 'cannot be preloaded'; then
    echo "programs print a loader error"
    rc=1
  fi
  for path in /opt/Citrix /etc/icaclient /usr/local/bin/AppProtection /usr/local/lib/AppProtection \
    /usr/local/bin/nsgcepa /home/tester/.ICAClient /var/log/citrix; do
    if [[ -e $path || -L $path ]]; then
      echo "left behind: $path"
      rc=1
    fi
  done
  if { dpkg -l 2>/dev/null | grep -E '^ii +(icaclient|ctxusb)'; } ||
    { rpm -qa 2>/dev/null | grep -E '^(ICAClient|ctxusb|ctxappprotection)'; }; then
    echo "packages still installed"
    rc=1
  fi
  return "$rc"
}

command=${1:-}
[[ $# -gt 0 ]] && shift
case $command in
  ctxup) as_tester bash /home/tester/ctxup "$@" ;;
  extras-flags) extras_flags ;;
  desktop) install_desktop ;;
  session-ready) session_ready ;;
  gui-start) gui_start "$1" ;;
  gui-alive) gui_alive "$1" ;;
  gui-stop) gui_stop "$1" ;;
  denials) denials ;;
  services-up) services_up "$@" ;;
  enforcing) [[ $(getenforce 2>/dev/null) == Enforcing ]] || aa-enabled --quiet 2>/dev/null ;;
  clean) clean ;;
  *)
    echo "guest.sh: unknown command '$command'" >&2
    exit 2
    ;;
esac
