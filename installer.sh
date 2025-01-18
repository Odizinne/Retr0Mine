#!/bin/bash

# Constants
APP_NAME="Retr0Mine"
INSTALL_DIR="$HOME/.local/bin/$APP_NAME"
DESKTOP_DIR="$HOME/.local/share/applications"
APPIMAGE_URL="https://github.com/Odizinne/Retr0Mine/releases/latest/download/Retr0Mine-x86_64.AppImage"
ICON_URL="https://raw.githubusercontent.com/Odizinne/Retr0Mine/refs/heads/main/Resources/icons/icon.png"

# Function to handle errors
show_error() {
    zenity --error --title="Error" --text="$1"
    exit 1
}

# Function to show success message
show_success() {
    zenity --info --title="Success" --text="$1"
}

# Function to download file with progress bar
download_with_progress() {
    local url="$1"
    local output="$2"
    wget "$url" -O "$output" 2>&1 | \
    sed -u 's/.* \([0-9]\+%\)\ \+\([0-9.]\+.\) \(.*\)/\1\n# Downloading: \2/' | \
    zenity --progress --title="Downloading..." --auto-close --auto-kill
    
    if [ $? -ne 0 ]; then
        show_error "Download failed!"
        return 1
    fi
    return 0
}

# Function to create desktop entry
create_desktop_entry() {
    cat > "$DESKTOP_DIR/$APP_NAME.desktop" << EOF
[Desktop Entry]
Name=$APP_NAME
Exec=$INSTALL_DIR/$APP_NAME-x86_64.AppImage
Icon=$INSTALL_DIR/icon.png
Type=Application
Categories=Game;
EOF
}

# Function to install
install_app() {
    # Create directories if they don't exist
    mkdir -p "$INSTALL_DIR" "$DESKTOP_DIR" || show_error "Failed to create directories"
    
    # Download AppImage
    download_with_progress "$APPIMAGE_URL" "$INSTALL_DIR/$APP_NAME-x86_64.AppImage" || return 1
    
    # Make AppImage executable
    chmod +x "$INSTALL_DIR/$APP_NAME-x86_64.AppImage" || show_error "Failed to make AppImage executable"
    
    # Download icon
    download_with_progress "$ICON_URL" "$INSTALL_DIR/icon.png" || return 1
    
    # Create desktop entry
    create_desktop_entry || show_error "Failed to create desktop entry"
    
    show_success "$APP_NAME has been successfully installed!"
}

# Function to uninstall
uninstall_app() {
    # Remove the installation directory
    rm -rf "$INSTALL_DIR" || show_error "Failed to remove installation directory"
    
    # Remove desktop file
    rm -f "$DESKTOP_DIR/$APP_NAME.desktop" || show_error "Failed to remove desktop entry"
    
    show_success "$APP_NAME has been successfully uninstalled!"
}

# Main dialog
CHOICE=$(zenity --list --radiolist \
    --title="$APP_NAME Installer" \
    --column="Select" --column="Action" \
    TRUE "Install / Update $APP_NAME" \
    FALSE "Uninstall $APP_NAME")

case $CHOICE in
    "Install / Update $APP_NAME")
        install_app
        ;;
    "Uninstall $APP_NAME")
        uninstall_app
        ;;
    *)
        exit 0
        ;;
esac