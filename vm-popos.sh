#!/bin/bash
if (set -o 2>/dev/null | grep -q pipefail); then
    set -euo pipefail
else
    set -eu
fi

export SCRIPT_NAME="vm-popos.sh"
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
configure_network_settings "virtio"
review_configurations
check_noop

download_vm_image() {
    echo "🔧 Checking if OS image exists..."
    cd "$MOUNT_STORAGE/template/iso/"
    VM_IMAGE="$(basename "$OS_IMAGE_LINK")"
    if ! test -f "$VM_IMAGE"; then
        echo "⬇️ Downloading from $OS_IMAGE_LINK..."
        wget "$OS_IMAGE_LINK" -O "$VM_IMAGE"
    fi
}

create_vm() {
    echo "🔧 Creating VM..."
    qm create $VM_ID --name "$VM_NAME" \
        --ostype l26 --ide2 "$HOST_ISO_STORAGE:iso/$VM_IMAGE,media=cdrom" \
        --vga virtio --scsihw virtio-scsi-single --machine q35 --agent 1 \
        --bios ovmf --efidisk0 "$HOST_VM_STORAGE:0,pre-enrolled-keys=0" \
        --cpu host --cores "$VM_CORES" \
        --memory "$VM_MEM" \
        --net0 "$VM_NET" \
        --tablet 0
}

setup_disk_image() {
    echo "🔧 Setting up disk image..."
    pvesm alloc "$HOST_VM_STORAGE" $VM_ID "vm-$VM_ID-disk-1" "${VM_DISK}G"
    qm set $VM_ID --scsi0 "$HOST_VM_STORAGE:vm-$VM_ID-disk-1,cache=writeback,discard=on,ssd=1,iothread=1"
    qm set $VM_ID --boot order='scsi0;ide2'
}

download_vm_image
create_vm
setup_disk_image
print_success_message
