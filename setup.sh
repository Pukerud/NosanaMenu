#!/usr/bin/env bash
set -e
set -u

# Set generic global names
SERVICE_NAME="nosana.service" # Fixed generic name
SCREEN_SESSION_NAME="nosana"  # Fixed generic name for screen sessions handled by attach_to_screen
SERVICE_FILE_PATH="/etc/systemd/system/${SERVICE_NAME}" # Derived from generic SERVICE_NAME
SCRIPT_VERSION="1.3.0"

# Funksjon for å vise menyen
show_menu() {
    clear
    echo "========================================="
    echo "      Nosana Service Manager v${SCRIPT_VERSION}"
    echo "========================================="
    # Removed display of Target User, specific Service Name, and specific Screen Session
    echo "1. Install/Reconfigure Nosana Service (via setup_nosana_screen.sh)"
    echo "2. Attach to Nosana Screen" # Generic name
    echo "3. Check Nosana Service Status (${SERVICE_NAME})" # Generic service name
    echo "4. Disable and Stop Service (${SERVICE_NAME})"   # Generic service name
    echo "5. Enable and Start Service (${SERVICE_NAME})"   # Generic service name
    echo "6. Exit"
    echo "-----------------------------------------"
}

# Funksjon for å installere/konfigurere systemd-tjenesten via setup_nosana_screen.sh
install_service() {
    echo "INFO: This option will run setup_nosana_screen.sh with sudo."
    echo "      The setup_nosana_screen.sh script will handle the specific user configuration."
    if [ -f ./setup_nosana_screen.sh ]; then
        sudo bash ./setup_nosana_screen.sh
        echo "INFO: Installation script 'setup_nosana_screen.sh' finished."
    else
        echo "ERROR: setup_nosana_screen.sh not found in the current directory."
    fi
    echo "Press Enter to return to the menu..."
    read -r
}

# Funksjon for å koble til screen-sesjonen
attach_to_screen() {
    local DEFAULT_USER="octa" # Or another sensible default like the current non-sudo user
    if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
        DEFAULT_USER="$SUDO_USER"
    elif [ "$(logname)" != "root" ] && [ -n "$(logname)" ]; then
        DEFAULT_USER="$(logname)"
    fi

    read -p "Enter username for the screen session (default: $DEFAULT_USER): " INPUT_USER
    local TARGET_SCREEN_USER="${INPUT_USER:-$DEFAULT_USER}"

    local screen_path
    screen_path=$(which screen)

    if [ -z "$screen_path" ]; then
        echo "ERROR: 'screen' command not found. Cannot attach."
    else
        echo "INFO: Attempting to attach to screen session '$SCREEN_SESSION_NAME' as user '$TARGET_SCREEN_USER'..."
        # Check if the screen session exists for that user
        if sudo -u "$TARGET_SCREEN_USER" "$screen_path" -ls | grep -q -E "[0-9]+\.${SCREEN_SESSION_NAME}\s+\((Attached|Detached)\)"; then
            echo "INFO: Found active screen session. Attaching..."
            echo "      Press Ctrl+A then D to detach."
            echo "-----------------------------------------"
            sudo -u "$TARGET_SCREEN_USER" "$screen_path" -r "$SCREEN_SESSION_NAME"
            echo "-----------------------------------------"
            echo "INFO: Detached from screen session."
        else
            echo "INFO: Screen session '$SCREEN_SESSION_NAME' for user '$TARGET_SCREEN_USER' not found or not running."
            echo "      The service '$SERVICE_NAME' (if it points to this user's screen) might need to be started."
        fi
    fi
    echo "Press Enter to return to the menu..."
    read -r
}

# Funksjon for å sjekke tjenestestatus
check_service_status() {
    echo "INFO: Checking Nosana service status (${SERVICE_NAME})..." # Uses generic SERVICE_NAME
    echo "-----------------------------------------"
    # Using systemctl status directly. If service doesn't exist, it will show that.
    systemctl status "${SERVICE_NAME}" --no-pager || true # ensure script doesn't exit if service not found
    echo "-----------------------------------------"
    echo "Status check complete. Press Enter to return to the menu..."
    read -r
}

# Funksjon for å deaktivere tjenesten
disable_service() {
    echo "INFO: Disabling and stopping the Nosana service (${SERVICE_NAME})..."
    sudo systemctl disable --now "${SERVICE_NAME}" || true # Or handle error more gracefully
    echo ""
    echo "INFO: Service ${SERVICE_NAME} has been actioned for stop/disable."
    echo "      If it was running, it should be stopped and disabled."
    echo "      If it did not exist, no action was taken by systemd."
    echo "Press Enter to return to the menu..."
    read -r
}

# Funksjon for å aktivere tjenesten
enable_service() {
    echo "INFO: Enabling and starting the Nosana service (${SERVICE_NAME})..."
    # We assume that if we are enabling it, the setup_nosana_screen.sh has created the file.
    # A direct check for SERVICE_FILE_PATH could be misleading if TARGET_USER detected by menu
    # is not the one for whom service was installed. setup_nosana_screen.sh is the source of truth.
    sudo systemctl enable --now "${SERVICE_NAME}" || true # Or handle error
    echo ""
    echo "INFO: Service ${SERVICE_NAME} has been actioned for enable/start."
    echo "      If it was configured correctly by the installation script, it should be running."
    echo "Press Enter to return to the menu..."
    read -r
}

# Non-interactive installation mode - DEPRECATED for this menu script
# The main installation is now handled by setup_nosana_screen.sh
# if [ "${1:-}" = "install" ]; then
#    echo "INFO: Non-interactive install. Running setup_nosana_screen.sh..."
#    if [ -f ./setup_nosana_screen.sh ]; then
#        sudo bash ./setup_nosana_screen.sh
#    else
#        echo "ERROR: setup_nosana_screen.sh not found."
#        exit 1
#    fi
#    exit 0
# fi

# Hovedløkke for menyen
while true; do
    show_menu
    read -p "Choose an option [1-6]: " choice
    case $choice in
        1) eval install_service ;;
        2) eval attach_to_screen ;; # Updated from view_log
        3) eval check_service_status ;;
        4) eval disable_service ;;
        5) eval enable_service ;;
        6) echo "Exiting."; exit 0 ;;
        *) echo "Invalid option. Please try again."; sleep 1 ;; # Reduced sleep
    esac
done
