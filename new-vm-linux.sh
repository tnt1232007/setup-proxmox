#!/bin/bash
# bash new-vm-linux.sh -i 401 -o debian -c 4 -r 4096 -d 40G -m bc:24:11:01:54:6e
# wget -qLO - https://gist.trinitro.io/tnt1232007/setup-proxmox/raw/HEAD/new-vm-linux.sh | bash -s -- -i 701 -o ubuntu
set -euo pipefail

# Check Host Configurations
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

# Input OS & VM Configurations
OS_NAME=""
VM_ID=""
VM_MAC=""
VM_CORES=4
VM_MEM=4096
VM_DISK_SIZE="40G"

while getopts ":o:i:m:c:r:d:" opt; do
    case $opt in
        o) OS_NAME="$OPTARG"
        ;;
        i) VM_ID="$OPTARG"
        ;;
        m) VM_MAC="$OPTARG"
        ;;
        c) VM_CORES="$OPTARG"
        ;;
        r) VM_MEM="$OPTARG"
        ;;
        d) VM_DISK_SIZE="$OPTARG"
        ;;
        \?) echo "Invalid option -$OPTARG" >&2
        exit 1
        ;;
    esac
done

# Check VM Configurations
if [ -z "$VM_ID" ]; then
    echo -e "\e[31mError: VM_ID(-i) is required\e[0m"
    exit 1
elif qm status $VM_ID &>/dev/null; then
    echo -e "\e[31mError: VM ID $VM_ID already exists\e[0m"
    exit 1
fi

# Check OS Configurations
if [ $OS_NAME == "debian" ]; then
    OS_VERSION="12"
    OS_DISTRO="bookworm"
    OS_IMAGE_LINK="https://cloud.$OS_NAME.org/images/cloud/$OS_DISTRO/latest/$OS_NAME-$OS_VERSION-genericcloud-amd64.qcow2"

elif [ $OS_NAME == "ubuntu" ]; then
    OS_VERSION="24.10"
    OS_DISTRO="oracular"
    OS_IMAGE_LINK="https://cloud-images.$OS_NAME.com/releases/$OS_DISTRO/release/$OS_NAME-$OS_VERSION-server-cloudimg-amd64.img"
elif [ -z "$OS_NAME" ]; then
    echo -e "\e[31mError: OS_NAME(-o) is required\e[0m"
    exit 1
else
    echo -e "\e[31mError: OS_NAME $OS_NAME not supported\e[0m"
    exit 1
fi

# Download image if not exists
cd $HOST_ISO_MOUNT
VM_IMAGE="$OS_NAME-$OS_VERSION.qcow2"
if ! test -f $VM_IMAGE; then
    echo -e "\e[32mDownloading from $OS_IMAGE_LINK...\e[0m"

    wget $OS_IMAGE_LINK -O $VM_IMAGE
    virt-customize -a $VM_IMAGE --install qemu-guest-agent
fi

# Create VM
VM_NAME="$OS_NAME-$OS_VERSION-$OS_DISTRO"
VM_NET="virtio,bridge=vmbr0"
if [ -n "$VM_MAC" ]; then
    VM_NET="$VM_NET,macaddr=${VM_MAC}"
fi
qm create $VM_ID --name $VM_NAME \
    --ostype l26 \
    --vga std --serial0 socket --scsihw virtio-scsi-single --machine q35 --agent 1 \
    --bios ovmf --efidisk0 local-lvm:0,pre-enrolled-keys=0 \
    --cpu host --cores $VM_CORES \
    --memory $VM_MEM \
    --net0 $VM_NET

# Setup disks image
qemu-img resize $VM_IMAGE $VM_DISK_SIZE
qm importdisk $VM_ID $VM_IMAGE $HOST_VM_STORAGE --format qcow2
qm set $VM_ID --scsi0 $HOST_VM_STORAGE:vm-$VM_ID-disk-1,ssd=1,discard=on
qm set $VM_ID --boot order='scsi0'

# Setup cloud-init
USER_SSH_FILE="$HOME/.ssh/id_ed25519"
if [[ -f "$USER_SSH_FILE" ]]; then
    echo "✅ SSH key already exists: $USER_SSH_FILE"
else
    ssh-keygen -t ed25519 -f "$USER_SSH_FILE" -N ""
    GITHUB_USER="tnt1232007"
    GITHUB_TOKEN="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"
    KEY_TITLE=$(hostname)
    KEY_PUBLIC=$(cat "$USER_SSH_FILE.pub")
    curl -u "$GITHUB_USER:$GITHUB_TOKEN" \
        -X POST \
        -H "Accept: application/vnd.github.v3+json" \
        https://api.github.com/user/keys \
        -d "{\"title\":\"$KEY_TITLE\",\"key\":\"$KEY_PUBLIC\"}"
    echo "✅ New SSH key created: $USER_SSH_FILE"
fi
USER_SSH_KEYS=(
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMB6Vttp4cj1oW63h6CvJd86keKJyfEQBGkgGkhXoHAJ tnt12@rog-strix"
    "$(cat $USER_SSH_FILE.pub)"
)
USER_SSH_TMP_FILE=$(mktemp)
printf "%s\n" "${USER_SSH_KEYS[@]}" > "$USER_SSH_TMP_FILE"
qm set $VM_ID --scsi1 local-lvm:cloudinit
qm set $VM_ID --sshkey $USER_SSH_TMP_FILE
qm set $VM_ID --ipconfig0 ip=dhcp
qm set $VM_ID --ciuser root
qm set $VM_ID --cipassword
qm cloudinit update $VM_ID

# Echo VM details
echo -e "\e[32mVM \e[33m$VM_ID \e[32mcreated successfully:\e[0m"
echo -e "\e[32m - Name: \e[33m$VM_NAME\e[0m"
echo -e "\e[32m - MAC Address: \e[33m$VM_MAC\e[0m"
echo -e "\e[32m - Cores: \e[33m$VM_CORES\e[0m"
echo -e "\e[32m - Memory: \e[33m$(($VM_MEM / 1024))G\e[0m"
echo -e "\e[32m - Disk Size: \e[33m$VM_DISK_SIZE\e[0m"
echo -e "\e[32mTo start the VM: \e[33mqm start \$VM_ID"
echo -e "\e[32mTo convert to template: \e[33mqm template \$VM_ID"
echo -e "\e[0m"