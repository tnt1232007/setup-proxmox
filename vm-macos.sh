#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/common.sh"
print_help "$(basename "$0")" "$@"
parse_input "$@"
configure_host_storage
configure_vm_settings
configure_os_settings
configure_network_settings "vmxnet3"
review_configurations
check_dry_run

download_vm_image() {
    echo "🔧 Checking if OS image exists..."
    cd $MOUNT_STORAGE/template/iso/
    VM_IMAGE="$OS_NAME-$OS_DISTRO-$OS_VERSION.iso"
    if ! test -f $VM_IMAGE; then
        echo "⬇️ Downloading from $OS_IMAGE_LINK..."
        wget $OS_IMAGE_LINK -O $VM_IMAGE
    fi

    echo "🔧 Checking if Support image exists..."
    local VM_SUPPORT_IMAGE_INFO="$(curl --silent -m 10 --connect-timeout 5 "https://api.github.com/repos/thenickdude/KVM-Opencore/releases/latest" | grep OpenCore | grep "\.iso\.gz")"
    VM_SUPPORT_IMAGE=$(echo "$VM_SUPPORT_IMAGE_INFO" | grep "name" | cut -d'"' -f4)
    VM_SUPPORT_IMAGE=${VM_SUPPORT_IMAGE%.gz}
    if ! test -f $VM_SUPPORT_IMAGE; then
        VM_SUPPORT_IMAGE_LINK=$(echo "$VM_SUPPORT_IMAGE_INFO" | grep "browser_download_url" | cut -d'"' -f4)
        echo "⬇️ Downloading from $VM_SUPPORT_IMAGE_LINK..."
        wget $VM_SUPPORT_IMAGE_LINK
        gzip -d $VM_SUPPORT_IMAGE.gz
    fi
}

create_vm() {
    echo "🔧 Creating VM..."
    VM_NAME="$OS_NAME-$OS_VERSION-$OS_DISTRO"
    qm create $VM_ID --name $VM_NAME \
        --ostype other --ide2 "$HOST_ISO_STORAGE:iso/$VM_SUPPORT_IMAGE,media=cdrom" \
        --vga vmware --scsihw virtio-scsi-single --machine q35 --agent 0 \
        --bios ovmf --efidisk0 $HOST_VM_STORAGE:0,pre-enrolled-keys=0 \
        --cpu host --cores $VM_CORES \
        --memory $VM_MEM \
        --net0 $VM_NET \
        --tablet 0
}

setup_disk_image() {
    echo "🔧 Setting up disk image..."
    pvesm alloc $HOST_VM_STORAGE $VM_ID vm-$VM_ID-disk-1 $VM_DISK
    qm set $VM_ID --virtio0 $HOST_VM_STORAGE:vm-$VM_ID-disk-1,cache=unsafe
    qm set $VM_ID --ide0 "$HOST_ISO_STORAGE:iso/$VM_IMAGE,media=cdrom"
    qm set $VM_ID --boot order='virtio0;ide2;ide0'
}

setup_compatibility() {
    echo "🔧 Setting machine compatibility ..."
    if lscpu | grep -q "AuthenticAMD"; then
        echo "args: -device isa-applesmc,osk=\"ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc\" -smbios type=2 -device qemu-xhci -device usb-kbd -device usb-tablet -global nec-usb-xhci.msi=off -global ICH9-LPC.acpi-pci-hotplug-with-bridge-support=off -cpu Haswell-noTSX,vendor=GenuineIntel,+invtsc,+hypervisor,kvm=on,vmware-cpuid-freq=on" \
            >> /etc/pve/qemu-server/$VM_ID.conf
    elif lscpu | grep -q "GenuineIntel"; then
        echo "args: -device isa-applesmc,osk=\"ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc\" -smbios type=2 -device qemu-xhci -device usb-kbd -device usb-tablet -global nec-usb-xhci.msi=off -global ICH9-LPC.acpi-pci-hotplug-with-bridge-support=off -cpu host,vendor=GenuineIntel,+invtsc,+hypervisor,kvm=on,vmware-cpuid-freq=on" \
            >> /etc/pve/qemu-server/$VM_ID.conf
    fi
    sed -i "s|media=cdrom|cache=unsafe|g" /etc/pve/qemu-server/$VM_ID.conf
}

download_vm_image
create_vm
setup_disk_image
setup_compatibility
print_success_message
