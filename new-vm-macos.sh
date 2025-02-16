#!/bin/bash
# bash new-vm-macos.sh 501 64:16:7f:7a:ca:bb 15 sequoia
# wget -qLO - https://gist.trinitro.io/tnt1232007/proxmox/raw/HEAD/new-vm-macos.sh | bash -s -- 501
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
VM_ID="${1:-501}"
VM_MAC="${2:-64:16:7f:7a:ca:bb}"
if qm status $VM_ID &>/dev/null; then
    echo -e "\e[31mError: VM ID $VM_ID already exists\e[0m"
    exit 1
fi

# OS Configuration - INPUT PARAMETERS
OS_VERSION="${3:-14}"
OS_DISTRO="${4:-sonoma}"

# VM Configuration
VM_NAME="macos-$OS_VERSION-$OS_DISTRO"
VM_OS_TYPE="other"
VM_CORES="8"
VM_SOCKET="1"
VM_MEM="16384"
VM_DISK_SIZE="128G"

# Download MacOS image
cd $HOST_ISO_MOUNT
VM_IMAGE="macos-$OS_DISTRO-$OS_VERSION.iso"
VM_OPENCORE_IMAGE=""
if ! test -f $VM_IMAGE; then
    VM_IMAGE_LINK="https://archive.org/download/macOS-X-images/${OS_DISTRO^}%20$OS_VERSION.iso"
    echo -e "\e[32mDownloading MacOS from $VM_IMAGE_LINK...\e[0m"
    wget $VM_IMAGE_LINK -O $VM_IMAGE

    VM_OPENCORE_IMAGE_LINK=$(curl --silent -m 10 --connect-timeout 5 "https://api.github.com/repos/thenickdude/KVM-Opencore/releases/latest" | grep /download/ | grep OpenCore | grep iso.gz | cut -d'"' -f4)
    echo -e "\e[32mDownloading OpenCore bootloader from $VM_OPENCORE_IMAGE_LINK...\e[0m"
    VM_OPENCORE_IMAGE=$(wget $VM_OPENCORE_IMAGE_LINK -nv 2>&1 | cut -d\" -f2)
    gzip -d $VM_OPENCORE_IMAGE
    VM_OPENCORE_IMAGE=${VM_OPENCORE_IMAGE%.gz}
fi

# Create and add main disk using VirtIO Block
echo -e "\e[32mCreating disks with size $VM_DISK_SIZE...\e[0m"
pvesm alloc $HOST_VM_STORAGE $VM_ID vm-$VM_ID-disk-0 4M # EFI disk
pvesm alloc $HOST_VM_STORAGE $VM_ID vm-$VM_ID-disk-1 $VM_DISK_SIZE

# Create VM
echo -e "\e[32mCreating VM with ID $VM_ID...\e[0m"
qm create $VM_ID --name $VM_NAME \
    --ostype $VM_OS_TYPE --ide2 "$HOST_ISO_STORAGE:iso/$VM_OPENCORE_IMAGE,media=cdrom" \
    --vga type=vmware --scsihw virtio-scsi --machine q35 --agent 0 \
    --bios ovmf --efidisk0 $HOST_VM_STORAGE:vm-$VM_ID-disk-0,size=4M,efitype=4m \
    --virtio0 $HOST_VM_STORAGE:vm-$VM_ID-disk-1,cache=unsafe \
    --cpu cputype=host --sockets $VM_SOCKET --cores $VM_CORES \
    --memory $VM_MEM \
    --net0 vmxnet3,bridge=vmbr0,macaddr=${VM_MAC} \
    --ide0 "$HOST_ISO_STORAGE:iso/$VM_IMAGE,media=cdrom" \
    --boot order='virtio0;ide2;ide0'

# Modify VM conf
if lscpu | grep -q "AuthenticAMD"; then
    echo "args: -device isa-applesmc,osk=\"ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc\" -smbios type=2 -device qemu-xhci -device usb-kbd -device usb-tablet -global nec-usb-xhci.msi=off -global ICH9-LPC.acpi-pci-hotplug-with-bridge-support=off -cpu Haswell-noTSX,vendor=GenuineIntel,+invtsc,+hypervisor,kvm=on,vmware-cpuid-freq=on" \
        >> /etc/pve/qemu-server/$VM_ID.conf
elif lscpu | grep -q "GenuineIntel"; then
    echo "args: -device isa-applesmc,osk=\"ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc\" -smbios type=2 -device qemu-xhci -device usb-kbd -device usb-tablet -global nec-usb-xhci.msi=off -global ICH9-LPC.acpi-pci-hotplug-with-bridge-support=off -cpu host,vendor=GenuineIntel,+invtsc,+hypervisor,kvm=on,vmware-cpuid-freq=on" \
        >> /etc/pve/qemu-server/$VM_ID.conf
fi
sed -i "s|media=cdrom|cache=unsafe|g" /etc/pve/qemu-server/$VM_ID.conf

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
