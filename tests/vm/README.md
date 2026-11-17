# Virtual machine tests

The container matrix cannot boot a kernel, enforce SELinux, reboot or show a
window. These scripts cover that part with real virtual machines built from
the distributions' own cloud images.

## What you need

- VMware Workstation with `vmrun` on the path, and its NAT network (`vmnet8`)
- podman, used for `qemu-img` and `genisoimage` so nothing else is installed
- About 8 GB of memory and 15 GB of disk per machine

Images, machines, logs and screenshots are kept in `~/ctxup-vms`; set
`CTXUP_VM_DIR` to use another place.

## Running

```sh
tests/vm/vm.sh targets            # list the machines that can be built
tests/vm/run.sh rocky-9           # full run on one target
tests/vm/run.sh --keep debian-13  # keep the machine afterwards to look around
```

Every image is checked against the publisher's checksum list before it is
used. The Citrix packages are downloaded from citrix.com inside the machine,
the way a user's machine would get them.

## What a run checks

1. SELinux or AppArmor is enforcing in the machine.
2. An ordinary user installs through `sudo`; `ctxup check` finds no problem.
3. The audit log has no denial and the journal no crash caused by the client.
4. After installing GNOME and rebooting, the Citrix log service is running.
5. The self-service window, the preferences window and the session client
   start in the Wayland session and are still running after a while. A
   screenshot of each is saved under `logs/shots`.
6. Where Citrix offers them, USB redirection, App Protection, deviceTRUST and
   EPA are installed, the machine is rebooted, the services have to be
   running and the three programs have to start again.
7. After `uninstall --purge`, one more reboot and, where App Protection was
   installed, a second purge, nothing is left: no files,
   no packages, and no App Protection entry in `/etc/ld.so.preload`.

The session client is started with a `.ica` file that points at an address
reserved for documentation, so it gets as far as trying to connect. A real
session needs a Citrix server and an account and is not part of these tests.
