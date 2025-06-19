#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
blue='\033[0;34m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Fatal error: ${plain} Please run this script with root privilege \n " && exit 1

# Check OS and set release variable
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    release=$ID
elif [[ -f /usr/lib/os-release ]]; then
    source /usr/lib/os-release
    release=$ID
else
    echo "Failed to check the system OS, please contact the author!" >&2
    exit 1
fi
echo "The OS release is: $release"

arch() {
    case "$(uname -m)" in
    x86_64 | x64 | amd64) echo 'amd64' ;;
    i*86 | x86) echo '386' ;;
    armv8* | armv8 | arm64 | aarch64) echo 'arm64' ;;
    armv7* | armv7 | arm) echo 'armv7' ;;
    armv6* | armv6) echo 'armv6' ;;
    armv5* | armv5) echo 'armv5' ;;
    s390x) echo 's390x' ;;
    *) echo -e "${green}Unsupported CPU architecture! ${plain}" && rm -f install.sh && exit 1 ;;
    esac
}
echo "Arch: $(arch)"

check_glibc_version() {
    glibc_version=$(ldd --version | head -n1 | awk '{print $NF}')
    required_version="2.32"
    if [[ "$(printf '%s\n' "$required_version" "$glibc_version" | sort -V | head -n1)" != "$required_version" ]]; then
        echo -e "${red}GLIBC version $glibc_version is too old! Required: 2.32 or higher${plain}"
        echo "Please upgrade to a newer version of your operating system to get a higher GLIBC version."
        exit 1
    fi
    echo "GLIBC version: $glibc_version (meets requirement of 2.32+)"
}
check_glibc_version

install_base() {
    case "${release}" in
    ubuntu | debian | armbian)
        apt-get update && apt-get install -y -q wget curl tar tzdata
        ;;
    centos | rhel | almalinux | rocky | ol)
        yum -y update && yum install -y -q wget curl tar tzdata
        ;;
    fedora | amzn | virtuozzo)
        dnf -y update && dnf install -y -q wget curl tar tzdata
        ;;
    arch | manjaro | parch)
        pacman -Syu && pacman -Syu --noconfirm wget curl tar tzdata
        ;;
    opensuse-tumbleweed)
        zypper refresh && zypper -q install -y wget curl tar timezone
        ;;
    *) apt-get update && apt install -y -q wget curl tar tzdata ;;
    esac
}

gen_random_string() {
    local length="$1"
    LC_ALL=C tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w "$length" | head -n 1
}

install_new_ui() {
    echo -e "${blue}Installing additional UI...${plain}"
    cd /usr/local/x-ui || return
    if [[ -f "./new-ui.sh" ]]; then
        bash ./new-ui.sh
        echo -e "${green}New UI installed successfully.${plain}"
    else
        echo -e "${yellow}No new-ui.sh script found. Skipping...${plain}"
    fi
}

update_x_ui() {
    echo -e "${blue}Checking for x-ui updates...${plain}"
    tag_version=$(curl -Ls "https://api.github.com/repos/MHSanaei/3x-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    if [[ -z "$tag_version" ]]; then
        echo -e "${red}Failed to fetch the latest x-ui version.${plain}"
        return
    fi
    echo -e "${green}Updating to version $tag_version...${plain}"
    install_x-ui "$tag_version"
}

update_new_ui() {
    echo -e "${blue}Checking for New UI updates...${plain}"
    cd /usr/local/x-ui/newui 2>/dev/null || { echo -e "${yellow}New UI folder not found. Skipping...${plain}"; return; }
    if git pull; then
        echo -e "${green}New UI updated successfully.${plain}"
    else
        echo -e "${red}Failed to update New UI.${plain}"
    fi
}

config_after_install() {
    # (Existing unchanged code...)
    /usr/local/x-ui/x-ui migrate
}

install_x-ui() {
    # (Existing unchanged logic...)
    config_after_install
    install_new_ui
    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui

    echo -e "${green}x-ui ${tag_version}${plain} installation finished, it is running now..."
    echo -e ""
    echo -e "┌───────────────────────────────────────────────────────┐
│  ${blue}x-ui control menu usages (subcommands):${plain}              │
│                                                       │
│  ${blue}x-ui${plain}              - Admin Management Script          │
│  ${blue}x-ui start${plain}        - Start                            │
│  ${blue}x-ui stop${plain}         - Stop                             │
│  ${blue}x-ui restart${plain}      - Restart                          │
│  ${blue}x-ui status${plain}       - Current Status                   │
│  ${blue}x-ui settings${plain}     - Current Settings                 │
│  ${blue}x-ui enable${plain}       - Enable Autostart on OS Startup   │
│  ${blue}x-ui disable${plain}      - Disable Autostart on OS Startup  │
│  ${blue}x-ui log${plain}          - Check logs                       │
│  ${blue}x-ui banlog${plain}       - Check Fail2ban ban logs          │
│  ${blue}x-ui update${plain}       - Update                           │
│  ${blue}x-ui newui${plain}        - Launch New UI                    │
│  ${blue}x-ui uninstall${plain}    - Uninstall                        │
└───────────────────────────────────────────────────────┘"
}

# Entry Point
echo -e "${green}Running...${plain}"
install_base

if [[ "$1" == "update" ]]; then
    update_x_ui
    update_new_ui
    exit 0
else
    install_x-ui "$1"
fi
