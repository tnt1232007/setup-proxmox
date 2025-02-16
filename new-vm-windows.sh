#!/bin/bash
# bash new-vm-windows.sh 601 02:a1:21:71:c8:0b 11 sun-valley
# wget -qLO - https://gist.trinitro.io/tnt1232007/proxmox/raw/HEAD/new-vm-windows.sh | bash -s -- 601
set -euo pipefail

# Host Configuration
HOST_VM_STORAGE="local-lvm"
HOST_ISO_STORAGE="nas-synology-external"
HOST_ISO_MOUNT="/mnt/pve/nas-synology-external/template/iso/"
if ! pvesm status | grep -q "^$HOST_VM_STORAGE"; then
    echo -e "\e[31mError: Storage '$HOST_VM_STORAGE' not found\e[0m"
    exit 1
fi
if ! pvesm status | grep -q "^$HOST_ISO_STORAGE"; then
    echo -e "\e[31mError: Storage '$HOST_ISO_STORAGE' not found\e[0m"
    exit 1
fi

# VM Info - INPUT PARAMETERS
VM_ID="${1:-601}"
VM_MAC="${2:-02:a1:21:71:c8:0b}"
if qm status $VM_ID &>/dev/null; then
    echo -e "\e[31mError: VM ID $VM_ID already exists\e[0m"
    exit 1
fi

# OS Configuration - INPUT PARAMETERS
OS_MAJOR="${3:-11}"
OS_MINOR="${4:-24H2}"
OS_BUILD="${5:-26100.1742}"

# VM Configuration
VM_NAME="win$OS_MAJOR-$OS_MINOR-$OS_BUILD"
VM_OS_TYPE="win$OS_MAJOR"
VM_CORES="8"
VM_SOCKET="1"
VM_MEM="16384"
VM_DISK_SIZE="128G"

# Download Windows ISO
cd $HOST_ISO_MOUNT
VM_IMAGE="Win${OS_MAJOR}_${OS_MINOR}_English_x64.iso"
VM_VIRTIO_IMAGE="virtio-win.iso"
if ! test -f $VM_IMAGE; then
    echo -e "\e[32mDownloading Windows $OS_MAJOR $OS_MINOR $OS_BUILD...\e[0m"

    wget https://archive.org/download/Win${OS_MAJOR}v${OS_MINOR}x64/$VM_IMAGE -O $VM_IMAGE

# TODO: https://stackoverflow.com/questions/3074288/get-final-url-after-curl-is-redirected
    wget https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/latest-virtio/$VM_VIRTIO_IMAGE -O $VM_VIRTIO_IMAGE
fi

# Create and add main disk using VirtIO Block
echo -e "\e[32mCreating disks with size $VM_DISK_SIZE...\e[0m"
pvesm alloc $HOST_VM_STORAGE $VM_ID vm-$VM_ID-disk-0 4M # EFI disk
pvesm alloc $HOST_VM_STORAGE $VM_ID vm-$VM_ID-disk-1 $VM_DISK_SIZE
pvesm alloc $HOST_VM_STORAGE $VM_ID vm-$VM_ID-disk-2 4M # TPM disk

# Create VM
echo -e "\e[32mCreating VM with ID $VM_ID...\e[0m"
qm create $VM_ID --name $VM_NAME \
    --ostype $VM_OS_TYPE --ide2 $HOST_ISO_STORAGE:iso/$VM_IMAGE,media=cdrom \
    --vga type=std --scsihw lsi --machine q35 --agent 1 \
    --bios ovmf --efidisk0 $HOST_VM_STORAGE:vm-$VM_ID-disk-0,size=4M,efitype=4m,pre-enrolled-keys=1 \
    --scsi0 $HOST_VM_STORAGE:vm-$VM_ID-disk-1,cache=writeback,discard=on,ssd=1 \
    --cpu cputype=host --sockets $VM_SOCKET --cores $VM_CORES \
    --memory $VM_MEM \
    --net0 virtio,bridge=vmbr0,macaddr=${VM_MAC} \
    --ide0 $HOST_ISO_STORAGE:iso/$VM_VIRTIO_IMAGE,media=cdrom \
    --boot order='scsi0;ide2;ide0' \
    --tpmstate0 $HOST_VM_STORAGE:vm-$VM_ID-disk-2,size=4M,version=v2.0 \
    --tablet 1

# Echo VM details
echo -e "\e[32mVM \e[33m$VM_ID \e[32mcreated successfully:\e[0m"
echo -e "\e[32m - Name: \e[33m$VM_NAME\e[0m"
echo -e "\e[32m - MAC Address: \e[33m$VM_MAC\e[0m"
echo -e "\e[32m - Cores: \e[33m$VM_CORES\e[0m"
echo -e "\e[32m - Sockets: \e[33m$VM_SOCKET\e[0m"
echo -e "\e[32m - Memory: \e[33m$(($VM_MEM / 1024))G\e[0m"
echo -e "\e[32m - Disk Size: \e[33m$VM_DISK_SIZE\e[0m"
echo -e "\e[32mTo start the VM:"
echo -e "\e[32m - \e[33mqm start $VM_ID"
echo -e "\e[0m"
