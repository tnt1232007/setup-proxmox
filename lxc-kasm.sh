#!/bin/bash
set -euo pipefail

export SCRIPT_TYPE="LXC"
export SCRIPT_NAME="lxc-kasm.sh"
if [[ -f "$(dirname "$0")/build.func" ]]; then
    source "$(dirname "$0")/build.func"
else
    source <(wget -qO- https://raw.githubusercontent.com/tnt1232007/setup-proxmox/refs/heads/main/build.func)
fi
print_help "$(basename "$0")" "$@"
parse_input "$@"
configure_host_storage
configure_vm_settings
configure_os_settings
configure_network_settings
review_configurations
check_noop

setup_for_kasm() {
    echo "🔧 Setting up for kasm..."
    pct set $VM_ID --features fuse=1,nesting=1
    VM_CONFIG_FILE="/etc/pve/lxc/$VM_ID.conf"
    echo "lxc.cgroup.devices.allow: c 10:200 rwm" >> $VM_CONFIG_FILE
    echo "lxc.mount.entry: /dev/net dev/net none bind,create=dir" >> $VM_CONFIG_FILE
}

download_lxc_template
setup_ssh_keys
create_lxc
setup_for_kasm