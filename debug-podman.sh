#!/bin/bash
# Debug script to check Podman installation on Ubuntu/Linux

echo "🔍 Podman Installation Debug"
echo "=========================================="
echo ""

# System info
echo "📊 System Information:"
echo "  OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '\"')"
echo "  User: $(whoami)"
echo "  Shell: $SHELL"
echo "  PATH: $PATH"
echo ""

# Check podman command
echo "📦 Checking 'podman' command:"
if command -v podman &> /dev/null; then
    echo "  ✅ 'command -v podman' found"
    echo "     Location: $(command -v podman)"
else
    echo "  ❌ 'command -v podman' NOT found"
fi
echo ""

# Check which
echo "🔎 Checking 'which podman':"
if which podman &> /dev/null; then
    echo "  ✅ 'which podman' found"
    echo "     Location: $(which podman)"
else
    echo "  ❌ 'which podman' NOT found"
fi
echo ""

# Check whereis
echo "🔎 Checking 'whereis podman':"
WHEREIS_OUTPUT=$(whereis podman)
if [ "$WHEREIS_OUTPUT" != "podman:" ]; then
    echo "  ✅ 'whereis podman' found"
    echo "     $WHEREIS_OUTPUT"
else
    echo "  ❌ 'whereis podman' NOT found"
fi
echo ""

# Check common locations
echo "📂 Checking common Podman locations:"
COMMON_PATHS=(
    "/usr/bin/podman"
    "/usr/local/bin/podman"
    "/opt/podman/bin/podman"
    "$HOME/.local/bin/podman"
)

for path in "${COMMON_PATHS[@]}"; do
    if [ -f "$path" ]; then
        echo "  ✅ Found: $path"
        echo "     Version: $($path --version 2>&1)"
        echo "     Executable: $([ -x "$path" ] && echo 'Yes' || echo 'No')"
    else
        echo "  ❌ Not found: $path"
    fi
done
echo ""

# Check if podman binary exists anywhere
echo "🔍 Searching for podman binary..."
FIND_RESULT=$(find /usr -name podman -type f 2>/dev/null | head -5)
if [ -n "$FIND_RESULT" ]; then
    echo "  Found podman at:"
    echo "$FIND_RESULT" | while read -r line; do
        echo "    - $line"
    done
else
    echo "  ❌ No podman binary found in /usr"
fi
echo ""

# Try running podman
echo "🚀 Trying to run podman:"
if podman --version &> /dev/null; then
    echo "  ✅ 'podman --version' works"
    echo "     $(podman --version)"
elif /usr/bin/podman --version &> /dev/null; then
    echo "  ✅ '/usr/bin/podman --version' works"
    echo "     $(/usr/bin/podman --version)"
elif sudo podman --version &> /dev/null; then
    echo "  ⚠️  'sudo podman --version' works (needs sudo)"
    echo "     $(sudo podman --version)"
    echo ""
    echo "  Note: Podman requires sudo. You may need to:"
    echo "    1. Add user to podman group: sudo usermod -aG podman $(whoami)"
    echo "    2. Or enable rootless mode"
else
    echo "  ❌ Cannot run podman at all"
fi
echo ""

# Check Podman version via package manager
echo "📦 Checking installed packages:"
if command -v dpkg &> /dev/null; then
    echo "  Package info (dpkg):"
    dpkg -l | grep -E "podman|container" | grep -v "^rc" | awk '{print "    " $2 " - " $3}'
elif command -v rpm &> /dev/null; then
    echo "  Package info (rpm):"
    rpm -qa | grep -E "podman|container" | while read pkg; do echo "    $pkg"; done
fi
echo ""

# Check if user is in podman group
echo "👤 User Groups:"
echo "  $(id $(whoami))"
if groups | grep -q podman; then
    echo "  ✅ User is in 'podman' group"
else
    echo "  ❌ User is NOT in 'podman' group"
    echo "     Add user: sudo usermod -aG podman $(whoami)"
    echo "     Then logout/login"
fi
echo ""

# Check Podman socket
echo "🔌 Checking Podman socket:"
SOCKET_PATHS=(
    "/run/podman/podman.sock"
    "$XDG_RUNTIME_DIR/podman/podman.sock"
    "/var/run/podman/podman.sock"
)

for socket in "${SOCKET_PATHS[@]}"; do
    if [ -S "$socket" ]; then
        echo "  ✅ Socket exists: $socket"
    else
        echo "  ❌ Socket not found: $socket"
    fi
done
echo ""

# Check systemd user service
echo "🔧 Checking Podman systemd service:"
if systemctl --user is-active podman.socket &> /dev/null; then
    echo "  ✅ podman.socket is active"
elif systemctl is-active podman.socket &> /dev/null; then
    echo "  ✅ podman.socket is active (system)"
else
    echo "  ❌ podman.socket is not active"
    echo "     Enable: systemctl --user enable --now podman.socket"
fi
echo ""

# Recommendations
echo "💡 Recommendations:"
echo "=========================================="

if ! command -v podman &> /dev/null; then
    if [ -f /usr/bin/podman ]; then
        echo "  ⚠️  Podman is installed but not in PATH"
        echo ""
        echo "  Solution 1: Add to PATH"
        echo "    echo 'export PATH=\$PATH:/usr/bin' >> ~/.bashrc"
        echo "    source ~/.bashrc"
        echo ""
        echo "  Solution 2: Reload shell"
        echo "    exec bash"
        echo ""
        echo "  Solution 3: Use full path"
        echo "    /usr/bin/podman --version"
    else
        echo "  ❌ Podman is NOT installed"
        echo ""
        echo "  Install Podman:"
        echo "    Ubuntu 20.10+:"
        echo "      sudo apt-get update"
        echo "      sudo apt-get install -y podman"
        echo ""
        echo "    Ubuntu 20.04 (requires repo):"
        echo "      source /etc/os-release"
        echo "      echo \"deb https://download.opensuse.org/repositories/devel:/kubic:/libpodman:/stable/xUbuntu_\${VERSION_ID}/ /\" | sudo tee /etc/apt/sources.list.d/devel:kubic:libpodman:stable.list"
        echo "      curl -L https://download.opensuse.org/repositories/devel:/kubic:/libpodman:/stable/xUbuntu_\${VERSION_ID}/Release.key | sudo apt-key add -"
        echo "      sudo apt-get update"
        echo "      sudo apt-get install -y podman"
    fi
else
    echo "  ✅ Podman is accessible!"
    echo ""
    echo "  You can now run:"
    echo "    ./start.sh"
fi

echo ""
echo "=========================================="
echo "Debug complete!"
