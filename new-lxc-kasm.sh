#!/bin/bash
# bash new-lxc-kasm.sh 101 64:16:7f:2c:af:71 1.16.1
# wget -qLO - https://gist.trinitro.io/tnt1232007/proxmox/raw/HEAD/new-lxc-kasm.sh | bash -s -- 101
set -euo pipefail

# Host Configuration
HOST_LXC_STORAGE="local-lvm"
HOST_ISO_STORAGE="nas-synology-external"
if ! pvesm status | grep -q "^$HOST_LXC_STORAGE"; then
    echo -e "\e[31mError: Storage '$HOST_LXC_STORAGE' not found\e[0m"
    exit 1
fi
if ! pvesm status | grep -q "^$HOST_ISO_STORAGE"; then
    echo -e "\e[31mError: Storage '$HOST_ISO_STORAGE' not found\e[0m"
    exit 1
fi

# LXC Info - INPUT PARAMETERS
LXC_ID="${1:-101}"
LXC_MAC="${2:-64:16:7f:2c:af:71}"
if qm status $LXC_ID &>/dev/null; then
    echo -e "\e[31mError: LXC ID $LXC_ID already exists\e[0m"
    exit 1
fi

# OS Configuration - INPUT PARAMETERS
OS_VERSION="${3:-1.16.1}"

# LXC Configuration
LXC_NAME="kasm-$OS_VERSION"
LXC_CORES="4"
LXC_MEM="4096"
LXC_DISK_SIZE="64"

# User Configuration
USER_ROOT="trinitro"
USER_SSH_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMB6Vttp4cj1oW63h6CvJd86keKJyfEQBGkgGkhXoHAJ tnt12@rog-strix"
USER_SSH_KEY_FILE=$(mktemp)
echo "$USER_SSH_KEY" > $USER_SSH_KEY_FILE

# Download debian CT template
pveam update
LXC_IMAGE=$(pveam available | grep debian-12-standard | sort -V | tail -n 1 | awk '{print $2}')
pveam download $HOST_ISO_STORAGE $LXC_IMAGE

# Create LXC
echo -e "\e[32mCreating LXC with ID $LXC_ID...\e[0m"
pct create $LXC_ID $HOST_ISO_STORAGE:vztmpl/$LXC_IMAGE \
    --hostname lxc-kasm \
    --unprivileged 0 \
    --cores $LXC_CORES \
    --memory $LXC_MEM \
    --storage $HOST_LXC_STORAGE \
    --rootfs $HOST_LXC_STORAGE:$LXC_DISK_SIZE \
    --net0 name=eth0,bridge=vmbr0,ip=dhcp,hwaddr=$LXC_MAC \
    --ssh-public-keys $USER_SSH_KEY_FILE \
    --features fuse=1,nesting=1

# Enable tun/tap
echo "lxc.cgroup.devices.allow: c 10:200 rwm" >> /etc/pve/lxc/$LXC_ID.conf
echo "lxc.mount.entry: /dev/net dev/net none bind,create=dir" >> /etc/pve/lxc/$LXC_ID.conf

# Echo LXC details
echo -e "\e[32mLXC \e[33m$LXC_ID \e[32mcreated successfully:\e[0m"
echo -e "\e[32m - Name: \e[33m$LXC_NAME\e[0m"
echo -e "\e[32m - MAC Address: \e[33m$LXC_MAC\e[0m"
echo -e "\e[32m - Cores: \e[33m$LXC_CORES\e[0m"
echo -e "\e[32m - Memory: \e[33m$(($LXC_MEM / 1024))G\e[0m"
echo -e "\e[32m - Disk Size: \e[33m$LXC_DISK_SIZE\e[0m"
echo -e "\e[32mTo start/enter the LXC:"
echo -e "\e[32m - \e[33mpct start $LXC_ID"
echo -e "\e[32m - \e[33mpct enter $LXC_ID"
echo -e "\e[0m"