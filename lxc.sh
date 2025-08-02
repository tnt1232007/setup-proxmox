#!/bin/bash
set -euo pipefail

export SCRIPT_TYPE="LXC"
export SCRIPT_NAME="lxc.sh"
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

download_lxc_template
configure_public_keys
create_lxc
print_success_message

start
configure_private_keys