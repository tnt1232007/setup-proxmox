#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/common.sh"
print_help "$(basename "$0")" "$@"
parse_input "$@"
configure_host_storage
configure_vm_settings
configure_os_settings
configure_network_settings
review_configurations
check_dry_run

download_vm_image() {
    echo "🔧 Checking if OS image exists..."
    cd $MOUNT_STORAGE/template/iso/
    VM_IMAGE="$OS_NAME-$OS_DISTRO-$OS_VERSION.qcow2"
    if ! test -f $VM_IMAGE; then
        echo "⬇️ Downloading from $OS_IMAGE_LINK..."
        wget $OS_IMAGE_LINK -O $VM_IMAGE
        virt-customize -a $VM_IMAGE --install qemu-guest-agent
    fi
}

create_vm() {
    echo "🔧 Creating VM..."
    VM_NAME="$OS_NAME-$OS_VERSION-$OS_DISTRO"
    qm create $VM_ID --name $VM_NAME \
        --ostype l26 \
        --vga std --serial0 socket --scsihw virtio-scsi-single --machine q35 --agent 1 \
        --bios ovmf --efidisk0 $HOST_VM_STORAGE:0,pre-enrolled-keys=0 \
        --cpu host --cores $VM_CORES \
        --memory $VM_MEM \
        --net0 $VM_NET \
        --tablet 0
}

setup_disk_image() {
    echo "🔧 Setting up disk image..."
    qemu-img resize $VM_IMAGE $VM_DISK
    qm importdisk $VM_ID $VM_IMAGE $HOST_VM_STORAGE --format qcow2
    qm set $VM_ID --scsi0 $HOST_VM_STORAGE:vm-$VM_ID-disk-1,ssd=1,discard=on
    qm set $VM_ID --boot order='scsi0'
}

setup_ssh_keys() {
    echo "🔧 Setting up SSH keys..."
    PROXMOX_MINISFORUM_SSH_FILE="$MOUNT_STORAGE/.ssh/proxmox-minisforum/id_ed25519.pub"
    ROG_STRIX_SSH_FILE="$MOUNT_STORAGE/.ssh/rog-strix/id_ed25519.pub"
    USER_SSH_KEYS=(
        "$(cat $PROXMOX_MINISFORUM_SSH_FILE)"
        "$(cat $ROG_STRIX_SSH_FILE)"
    )
    USER_SSH_TMP_FILE=$(mktemp)
    printf "%s\n" "${USER_SSH_KEYS[@]}" > "$USER_SSH_TMP_FILE"
}

setup_cloud_init() {
    echo "🔧 Setting up cloud-init..."
    qm set $VM_ID --scsi1 local-lvm:cloudinit
    qm set $VM_ID --sshkey $USER_SSH_TMP_FILE
    qm set $VM_ID --ipconfig0 ip=dhcp
    qm set $VM_ID --ciuser root
    qm cloudinit update $VM_ID
    rm $USER_SSH_TMP_FILE
}

download_vm_image
create_vm
setup_disk_image
setup_ssh_keys
setup_cloud_init
print_success_message