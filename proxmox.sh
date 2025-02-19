echo "🔧 Setting up SSH keys..."
PROXMOX_SSH_FILE="$HOME/.ssh/id_ed25519"
if [[ -f "$PROXMOX_SSH_FILE" ]]; then
    echo "✅ SSH key already exists: $PROXMOX_SSH_FILE"
else
    ssh-keygen -t ed25519 -f "$PROXMOX_SSH_FILE" -N ""
    GITHUB_USER="tnt1232007"
    GITHUB_TOKEN="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"
    KEY_TITLE=$(hostname)
    KEY_PUBLIC=$(cat "$PROXMOX_SSH_FILE.pub")
    curl -u "$GITHUB_USER:$GITHUB_TOKEN" \
        -X POST \
        -H "Accept: application/vnd.github.v3+json" \
        https://api.github.com/user/keys \
        -d "{\"title\":\"$KEY_TITLE\",\"key\":\"$KEY_PUBLIC\"}"
    echo "✅ New SSH key created: $PROXMOX_SSH_FILE"
fi

MOUNT_STORAGE="/mnt/pve/nas-synology-external"
mkdir $MOUNT_STORAGE/.ssh/proxmox-minisforum
cp $PROXMOX_SSH_FILE.pub $MOUNT_STORAGE/.ssh/proxmox-minisforum/id_ed25519.pub