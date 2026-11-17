#!/usr/bin/env bash
#
# Creates and drives the virtual machines used by tests/vm/run.sh.
# Needs VMware Workstation (vmrun) and podman. Images and machines are kept
# in $CTXUP_VM_DIR (default ~/ctxup-vms), outside the repository.
#
# usage: tests/vm/vm.sh images [TARGET ...]   download and verify cloud images
#        tests/vm/vm.sh create TARGET         build the machine and boot it
#        tests/vm/vm.sh ip|wait|reboot|rm TARGET
#        tests/vm/vm.sh ssh TARGET [USER@] COMMAND...
#        tests/vm/vm.sh put TARGET FILE...    copy files to /root in the guest
#        tests/vm/vm.sh shot TARGET LABEL     save a screenshot of the console

set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
store=${CTXUP_VM_DIR:-$HOME/ctxup-vms}
leases=${CTXUP_VM_LEASES:-/etc/vmware/vmnet8/dhcpd/dhcpd.leases}
tools_image=localhost/ctxup-vmtools:latest

# target|image URL|checksum URL|sha256 or sha512
TARGETS='
ubuntu-22.04|https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img|https://cloud-images.ubuntu.com/jammy/current/SHA256SUMS|sha256
ubuntu-24.04|https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img|https://cloud-images.ubuntu.com/noble/current/SHA256SUMS|sha256
ubuntu-26.04|https://cloud-images.ubuntu.com/resolute/current/resolute-server-cloudimg-amd64.img|https://cloud-images.ubuntu.com/resolute/current/SHA256SUMS|sha256
ubuntu-26.10|https://cloud-images.ubuntu.com/stonking/current/stonking-server-cloudimg-amd64.img|https://cloud-images.ubuntu.com/stonking/current/SHA256SUMS|sha256
debian-12|https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2|https://cloud.debian.org/images/cloud/bookworm/latest/SHA512SUMS|sha512
debian-13|https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2|https://cloud.debian.org/images/cloud/trixie/latest/SHA512SUMS|sha512
rocky-8|https://dl.rockylinux.org/pub/rocky/8/images/x86_64/Rocky-8-GenericCloud-Base.latest.x86_64.qcow2|https://dl.rockylinux.org/pub/rocky/8/images/x86_64/Rocky-8-GenericCloud-Base.latest.x86_64.qcow2.CHECKSUM|sha256
rocky-9|https://dl.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2|https://dl.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2.CHECKSUM|sha256
rocky-10|https://dl.rockylinux.org/pub/rocky/10/images/x86_64/Rocky-10-GenericCloud-Base.latest.x86_64.qcow2|https://dl.rockylinux.org/pub/rocky/10/images/x86_64/Rocky-10-GenericCloud-Base.latest.x86_64.qcow2.CHECKSUM|sha256
alma-8|https://repo.almalinux.org/almalinux/8/cloud/x86_64/images/AlmaLinux-8-GenericCloud-latest.x86_64.qcow2|https://repo.almalinux.org/almalinux/8/cloud/x86_64/images/CHECKSUM|sha256
alma-9|https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2|https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/CHECKSUM|sha256
alma-10|https://repo.almalinux.org/almalinux/10/cloud/x86_64/images/AlmaLinux-10-GenericCloud-latest.x86_64.qcow2|https://repo.almalinux.org/almalinux/10/cloud/x86_64/images/CHECKSUM|sha256
fedora-44|https://download.fedoraproject.org/pub/fedora/linux/releases/44/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-44-1.7.x86_64.qcow2|https://download.fedoraproject.org/pub/fedora/linux/releases/44/Cloud/x86_64/images/Fedora-Cloud-44-1.7-x86_64-CHECKSUM|sha256
fedora-45|https://download.fedoraproject.org/pub/fedora/linux/releases/45/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-45-1.4.x86_64.qcow2|https://download.fedoraproject.org/pub/fedora/linux/releases/45/Cloud/x86_64/images/Fedora-Cloud-45-1.4-x86_64-CHECKSUM|sha256
'

die() {
  echo "vm.sh: $*" >&2
  exit 1
}

target_line() {
  local line
  line=$(grep -E "^$1\|" <<<"$TARGETS") || die "unknown target '$1'"
  echo "$line"
}

all_targets() { sed -n 's/^\([a-z0-9.-]*\)|.*/\1/p' <<<"$TARGETS"; }

vmx_of() { echo "$store/vms/$1/$1.vmx"; }

ssh_opts=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR
  -o ConnectTimeout=8 -o BatchMode=yes -o ServerAliveInterval=15 -o ServerAliveCountMax=8)

ensure_key() {
  mkdir -p "$store/images" "$store/vms" "$store/logs"
  if [[ ! -f $store/id_vm ]]; then
    ssh-keygen -q -t ed25519 -N '' -C ctxup-vm-test -f "$store/id_vm"
  fi
}

ensure_tools() {
  podman image exists "$tools_image" ||
    podman build -q -t "$tools_image" -f "$here/Containerfile.tools" "$here" >/dev/null
}

# The image is only used when its checksum matches the publisher's list.
fetch_image() {
  local url sums kind file want got
  IFS='|' read -r _ url sums kind <<<"$(target_line "$1")"
  file=$store/images/${url##*/}
  if [[ ! -s $file ]]; then
    echo "downloading ${url##*/}"
    curl -fL --retry 5 --retry-delay 5 -sS -o "$file.part" "$url"
    mv "$file.part" "$file"
  fi
  want=$(curl -fsSL --retry 3 "$sums" | grep -F "${url##*/}" | grep -oE '\b[0-9a-f]{64,128}\b' | head -n1)
  got=$("${kind}sum" "$file" | cut -d' ' -f1)
  [[ -n $want && $want == "$got" ]] || die "checksum mismatch for $file; delete it and retry"
  echo "verified ${url##*/}"
}

cmd_create() {
  local name=$1 url image dir pub
  IFS='|' read -r _ url _ <<<"$(target_line "$name")"
  image=${url##*/}
  dir=$store/vms/$name
  [[ -e $dir ]] && die "$dir exists; run 'vm.sh rm $name' first"
  [[ -s $store/images/$image ]] || die "missing image; run 'vm.sh images $name' first"
  ensure_tools
  mkdir -p "$dir/seed"
  pub=$(<"$store/id_vm.pub")
  printf 'instance-id: %s-%s\nlocal-hostname: %s\n' "$name" "$(date +%s)" "${name//./-}" >"$dir/seed/meta-data"
  cat >"$dir/seed/user-data" <<USER
#cloud-config
ssh_pwauth: false
disable_root: false
users:
  - name: root
    ssh_authorized_keys:
      - $pub
  - name: tester
    gecos: Test User
    shell: /bin/bash
    groups: [sudo, wheel]
    lock_passwd: false
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    ssh_authorized_keys:
      - $pub
chpasswd:
  expire: false
  users:
    - {name: tester, password: ctxup-test, type: text}
runcmd:
  - [sh, -c, 'touch /var/lib/ctxup-vm-ready']
USER
  podman run --rm --security-opt label=disable -v "$store:/w" "$tools_image" sh -ec "
    cp '/w/images/$image' '/w/vms/$name/work.img'
    qemu-img resize -q '/w/vms/$name/work.img' 40G
    qemu-img convert -O vmdk -o adapter_type=lsilogic,subformat=monolithicSparse \
      '/w/vms/$name/work.img' '/w/vms/$name/disk.vmdk'
    rm -f '/w/vms/$name/work.img'
    genisoimage -quiet -output '/w/vms/$name/seed.iso' -volid cidata -joliet -rock \
      '/w/vms/$name/seed/user-data' '/w/vms/$name/seed/meta-data'
  "
  cat >"$dir/$name.vmx" <<VMX
.encoding = "UTF-8"
config.version = "8"
virtualHW.version = "19"
displayName = "ctxup-$name"
guestOS = "other6xlinux-64"
firmware = "efi"
memsize = "${CTXUP_VM_MEM:-6144}"
numvcpus = "4"
cpuid.coresPerSocket = "4"
pciBridge0.present = "TRUE"
pciBridge4.present = "TRUE"
pciBridge4.virtualDev = "pcieRootPort"
pciBridge4.functions = "8"
vmci0.present = "TRUE"
hpet0.present = "TRUE"
sata0.present = "TRUE"
sata0:0.present = "TRUE"
sata0:0.fileName = "disk.vmdk"
sata0:1.present = "TRUE"
sata0:1.deviceType = "cdrom-image"
sata0:1.fileName = "seed.iso"
ethernet0.present = "TRUE"
ethernet0.connectionType = "nat"
ethernet0.virtualDev = "vmxnet3"
ethernet0.addressType = "generated"
usb.present = "TRUE"
usb_xhci.present = "TRUE"
svga.graphicsMemoryKB = "262144"
mks.enable3d = "FALSE"
serial0.present = "TRUE"
serial0.fileType = "file"
serial0.fileName = "serial.log"
msg.autoAnswer = "TRUE"
VMX
  vmrun -T ws start "$dir/$name.vmx" nogui
  cmd_wait "$name"
}

# The NAT address comes from the DHCP leases of the VMware NAT network. The
# file can hold several leases for one machine, in no particular order, so the
# one that started last wins.
cmd_ip() {
  local mac
  mac=$(sed -n 's/^ethernet0.generatedAddress = "\(.*\)"/\1/p' "$(vmx_of "$1")" | tr 'A-F' 'a-f')
  [[ -n $mac ]] || return 1
  awk -v mac="$mac" '
    /^lease /{ip=$2}
    /starts /{start=$3 " " $4}
    /hardware ethernet/{m=$3; sub(";","",m); if (tolower(m)==mac && start>=best) {best=start; found=ip}}
    END{if (found) print found; else exit 1}' "$leases"
}

cmd_ssh() {
  local name=$1 user=root ip
  shift
  if [[ ${1:-} == *@ ]]; then
    user=${1%@}
    shift
  fi
  ip=$(cmd_ip "$name") || die "no address for $name yet"
  ssh -i "$store/id_vm" "${ssh_opts[@]}" "$user@$ip" "$@" </dev/null
}

cmd_put() {
  local name=$1 ip
  shift
  ip=$(cmd_ip "$name") || die "no address for $name yet"
  scp -q -i "$store/id_vm" "${ssh_opts[@]}" "$@" "root@$ip:/root/"
}

cmd_wait() {
  local i
  for ((i = 0; i < 90; i++)); do
    # In a subshell: before the machine has an address, cmd_ssh gives up.
    if (cmd_ssh "$1" 'test -e /var/lib/ctxup-vm-ready') 2>/dev/null; then
      echo "$1 is up at $(cmd_ip "$1")"
      return 0
    fi
    sleep 5
  done
  die "$1 did not come up"
}

cmd_reboot() {
  (cmd_ssh "$1" 'systemctl reboot') 2>/dev/null || true
  sleep 40
  cmd_wait "$1"
}

cmd_shot() {
  mkdir -p "$store/logs/shots"
  vmrun -T ws -gu tester -gp ctxup-test captureScreen "$(vmx_of "$1")" "$store/logs/shots/$1-$2.png" >/dev/null
  echo "$store/logs/shots/$1-$2.png"
}

cmd_rm() {
  local vmx
  vmx=$(vmx_of "$1")
  [[ -f $vmx ]] || return 0
  vmrun -T ws stop "$vmx" hard >/dev/null 2>&1 || true
  vmrun -T ws deleteVM "$vmx" >/dev/null 2>&1 || true
  rm -rf -- "${store:?}/vms/${1:?}"
}

main() {
  local command=${1:-} name
  [[ $# -gt 0 ]] && shift
  ensure_key
  case $command in
    images)
      [[ $# -gt 0 ]] || mapfile -t _all < <(all_targets)
      [[ $# -gt 0 ]] || set -- "${_all[@]}"
      for name in "$@"; do fetch_image "$name"; done
      ;;
    targets) all_targets ;;
    create | ip | wait | reboot | rm)
      [[ $# -eq 1 ]] || die "usage: vm.sh $command TARGET"
      "cmd_$command" "$1"
      ;;
    ssh | put | shot)
      [[ $# -ge 2 ]] || die "usage: vm.sh $command TARGET ..."
      "cmd_$command" "$@"
      ;;
    *) die "unknown command '${command}'; see the header of this file" ;;
  esac
}

main "$@"
