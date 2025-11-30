#!/bin/bash

# ==============================================================================
# CashyOS Package Installation Script (Priority: pacman -> AUR (yay) -> flatpak)
# This script is designed to install most optimized packages.
# ==============================================================================

# Exit immediately if a command exits with a non-zero status.
set -e

# Define color codes for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# --- 1. System Setup and Prerequisite Checks ---------------------------------

echo -e "${YELLOW}Starting package installation script on CashyOS...${NC}"

# Check for Pacman, which is essential for CashyOS
if ! command -v pacman &> /dev/null; then
    echo -e "${RED}Error: pacman is not found. This script is designed for CashyOS/Arch-based systems.${NC}"
    exit 1
fi

# Function to check and install yay (AUR Helper)
setup_yay() {
    if ! command -v yay &> /dev/null; then
        echo -e "${YELLOW}yay (AUR helper) not found. Installing via Pacman...${NC}"
        
        # Install yay directly from the repository of pacman.
        # Use --needed to skip if already installed.
        sudo pacman -S --noconfirm --needed yay

        if [ $? -eq 0 ]; then
            echo -e "${GREEN}yay successfully installed.${NC}"
        else
            echo -e "${RED}Error: Failed to install yay via pacman. The script may not be able to handle AUR packages.${NC}"
            # Note: If this fails, the system might require the older, manual compilation method.
        fi
    else
        echo -e "${GREEN}yay is already installed.${NC}"
    fi
}

# Function to check and install Flatpak
setup_flatpak() {
    if ! command -v flatpak &> /dev/null; then
        echo -e "${YELLOW}flatpak not found. Installing via pacman...${NC}"
        sudo pacman -Syu --noconfirm --needed flatpak
        echo -e "${GREEN}flatpak successfully installed.${NC}"
    else
        echo -e "${GREEN}flatpak is already installed.${NC}"
    fi
    # Add Flathub repository if not already added
    echo -e "${YELLOW}Ensuring Flathub is enabled...${NC}"
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
}

# Run setup
setup_yay
setup_flatpak

# --- 2. Core Installation Logic ------------------------------------------------

# Function to determine the best installation method
# Priority: pacman -> yay (AUR) -> flatpak
install_package() {
    local pkg_name=$1
    local flatpak_id=$2
    local force_flatpak=$3

    echo -e "\n${YELLOW}--- Attempting to install: ${pkg_name} ---${NC}"

    if [[ "$force_flatpak" == "true" ]]; then
        # Handle specific use cases where you want flatpak instead pacman
        # eg. Discord, personally I had problem with native discord package in Linux Mint, where it was updating almost regularly.
        # Flatpak solved that issue for me.
        echo -e "  -> ${pkg_name}: ${YELLOW}User preference set to Flatpak only/preferred.${NC}"
        echo -e "  -> ${GREEN}Installing ${pkg_name} via Flatpak...${NC}"
        flatpak install -y flathub "$flatpak_id"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}${pkg_name} installed successfully via Flatpak.${NC}"
        else
            echo -e "${RED}Error: Flatpak installation failed for ${pkg_name}.${NC}"
        fi
        return
    fi

    # 1. Try Pacman (Native Repository)
    if pacman -Si "$pkg_name" &> /dev/null; then
        echo -e "  -> ${GREEN}Found in Pacman. Installing...${NC}"
        sudo pacman -S --noconfirm "$pkg_name"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}${pkg_name} installed successfully via Pacman.${NC}"
            return
        fi
    fi
    
    # 2. Try Yay (AUR)
    # Check if the package exists in AUR (yay -Si uses exit code 0 if found)
    if yay -Si "$pkg_name" &> /dev/null; then
        echo -e "  -> ${YELLOW}Not found in Pacman, but found in AUR. Installing via yay...${NC}"
        yay -S --noconfirm "$pkg_name"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}${pkg_name} installed successfully via AUR.${NC}"
            return
        fi
    fi

    # 3. Fallback to Flatpak
    if [ -n "$flatpak_id" ]; then
        echo -e "  -> ${RED}Not found in Pacman or AUR. Falling back to Flatpak...${NC}"
        echo -e "  -> ${GREEN}Installing ${pkg_name} via Flatpak...${NC}"
        flatpak install -y flathub "$flatpak_id"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}${pkg_name} installed successfully via Flatpak.${NC}"
        else
            echo -e "${RED}Error: Flatpak installation failed for ${pkg_name}.${NC}"
        fi
    else
        echo -e "${RED}Error: ${pkg_name} not found in Pacman, AUR, and no Flatpak ID was provided. Skipping.${NC}"
    fi
}

# --- 3. Package Definitions and Execution --------------------------------------

# Packages: (pkg_name, flatpak_id, force_flatpak_flag)
# Note: flatpak_id should be provided for the fallback mechanism.

PACKAGES=(
    "brave-bin|com.brave.Browser|false"
    "kdenlive|org.kde.kdenlive|false"
    "obs-studio|com.obsproject.Studio|false"
    "onlyoffice-bin|org.onlyoffice.desktopeditors|false"
    "vlc|org.videolan.VLC|false"
    "code|com.vscodium.codium|false"
    "inkscape|org.inkscape.Inkscape|false"
    "discord|com.discordapp.Discord|true" # FLATPAK ONLY (force_flatpak=true)
    "localsend|org.localsend.localsend_app|false"
    "qimgv-git|io.github.opengapps.qimgv|false"
    "normcap|com.github.dynobo.normcap|false" 
    "diodon|net.launchpad.diodon|false"
    "virt-manager|org.virt_manager.virt-manager|false"
    "mailspring-bin|com.getmailspring.Mailspring|false"
    "zoom|us.zoom.Zoom|false"
)

# Main loop to iterate through packages
for entry in "${PACKAGES[@]}"; do
    IFS='|' read -r pkg_name flatpak_id force_flatpak <<< "$entry"
    install_package "$pkg_name" "$flatpak_id" "$force_flatpak"
done

echo -e "\n${GREEN}======================================================${NC}"
echo -e "${GREEN}Package installation process complete!${NC}"
echo -e "${GREEN}======================================================${NC}"
echo -e "Please note: Some AUR installations may require manual confirmation or input if the default --noconfirm flag is insufficient."
echo -e "You may need to reboot your system for full Flatpak integration and service changes (like for for virt-manager) to take effect."
