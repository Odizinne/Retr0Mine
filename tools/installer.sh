#!/bin/bash

APP_NAME="Retr0Mine"
INSTALL_DIR="$HOME/.local/bin/$APP_NAME"
DESKTOP_DIR="$HOME/.local/share/applications"
ZIP_URL="https://github.com/Odizinne/Retr0Mine/releases/latest/download/Retr0Mine_Linux.zip"

show_error() { zenity --error --title="Error" --text="$1"; exit 1; }
show_success() { zenity --info --title="Success" --text="$1"; }

download_with_progress() {
    wget "$1" -O "$2" 2>&1 | \
    sed -u 's/.* \([0-9]\+%\)\ \+\([0-9.]\+.\) \(.*\)/\1\n# Downloading: \2/' | \
    zenity --progress --title="Downloading..." --auto-close --auto-kill
    
    [ $? -eq 0 ] || { show_error "Download failed!"; return 1; }
}

create_desktop_entry() {
    cat > "$DESKTOP_DIR/$APP_NAME.desktop" << EOF
[Desktop Entry]
Name=$APP_NAME
Exec=bash -c '$INSTALL_DIR/bin/Retr0Mine'
Icon=$INSTALL_DIR/Retr0Mine.png
Path=$INSTALL_DIR
Type=Application
Categories=Game;
EOF
}

install_app() {
    mkdir -p "$INSTALL_DIR" "$DESKTOP_DIR" || show_error "Failed to create directories"
    
    local temp_zip="/tmp/Retr0Mine_Linux.zip"
    download_with_progress "$ZIP_URL" "$temp_zip" || return 1
    
    unzip -o "$temp_zip" -d "$INSTALL_DIR" || show_error "Failed to extract files"
    rm "$temp_zip"
    
    chmod +x "$INSTALL_DIR/bin/Retr0Mine" || show_error "Failed to make binary executable"
    create_desktop_entry || show_error "Failed to create desktop entry"
    
    show_success "$APP_NAME has been successfully installed!"
}

uninstall_app() {
    rm -rf "$INSTALL_DIR" || show_error "Failed to remove installation directory"
    rm -f "$DESKTOP_DIR/$APP_NAME.desktop" || show_error "Failed to remove desktop entry"
    show_success "$APP_NAME has been successfully uninstalled!"
}

CHOICE=$(zenity --list --radiolist \
    --title="$APP_NAME Installer" \
    --column="Select" --column="Action" \
    TRUE "Install / Update $APP_NAME" \
    FALSE "Uninstall $APP_NAME")

case $CHOICE in
    "Install / Update $APP_NAME") install_app ;;
    "Uninstall $APP_NAME") uninstall_app ;;
esac