#!/bin/bash
set -euo pipefail

export SCRIPT_TYPE="LXC"
export SCRIPT_NAME="lxc-pbs.sh"
if [[ -f "$(dirname "$0")/build.func" ]]; then
    source "$(dirname "$0")/build.func"
else
    source <(wget -qO- https://raw.githubusercontent.com/tnt1232007/setup-proxmox/refs/heads/main/build.func)
fi
print_help "$@"
parse_input "$@"
configure_host_storage
configure_vm_settings
configure_os_settings
configure_network_settings
review_configurations
check_noop

setup_for_psb() {
    echo "🔧 Setting up for psb..."
    pct set $VM_ID --mp0 $HOST_ISO_STORAGE:1024,mp=/mnt/data
}

download_lxc_template
setup_ssh_keys
create_lxc
setup_for_psb
print_success_message