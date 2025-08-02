#!/bin/bash
set -euo pipefail

setup_for_kasm() {
    echo "🔧 Setting up for kasm..."
    pct set $VM_ID --features fuse=1,nesting=1
    VM_CONFIG_FILE="/etc/pve/lxc/$VM_ID.conf"
    echo "lxc.cgroup.devices.allow: c 10:200 rwm" >> $VM_CONFIG_FILE
    echo "lxc.mount.entry: /dev/net dev/net none bind,create=dir" >> $VM_CONFIG_FILE
}
