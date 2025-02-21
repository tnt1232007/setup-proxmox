configure-ssh-keys() {
    echo "🔧 Configuring ssh-keys..."
    SSH_PATH="$HOME/.ssh"
    if [ ! -d "$SSH_PATH" ]; then
        mkdir -p "$SSH_PATH"
    fi

    SSH_KEY_PATH="$SSH_PATH/id_ed25519"
    if [[ ! -f "$SSH_KEY_PATH" ]]; then
        echo "🔧 Creating new ssh-keys..."
        ssh-keygen -t ed25519 -f "$SSH_KEY_PATH" -N ""
        AUTH="Basic dG50MTIzMjAwNzpnaXRodWJfcGF0XzExQUFUWllKUTBWMDZyT01tYjlIOEJfRjdZZjl3UDc2ZVFOU3E2dFVod1RwczN4aVpyOXVOaGl5REx1ZWJjTUFVRVkyMlg3N0FMZHBENGZCdlA="
        KEY_TITLE=$(hostname)
        KEY_PUBLIC=$(cat "$SSH_KEY_PATH.pub")
        curl -X POST \
            -H "Authorization: $AUTH" \
            -H "Accept: application/vnd.github.v3+json" \
            https://api.github.com/user/keys \
            -d "{\"title\":\"$KEY_TITLE\",\"key\":\"$KEY_PUBLIC\"}"
    fi
}