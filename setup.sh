#!/usr/bin/env bash
set -e
set -u

# --- Dynamic TARGET_USER determination for menu display and service name construction ---
if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
    TARGET_USER="$SUDO_USER"
elif [ "$(logname)" != "root" ] && [ -n "$(logname)" ]; then
    TARGET_USER="$(logname)"
else
    # Fallback if no suitable user is found for constructing service names.
    # The individual setup_nosana_screen.sh will do more rigorous checks.
    echo "INFO: Could not determine a specific non-root user for service name generation. Defaulting to 'user'."
    echo "      If a service was installed for a specific user, its name might not match menu defaults."
    TARGET_USER="user" # A generic fallback for menu display
fi
echo "INFO: Menu commands will be targeted for user: $TARGET_USER"

# Also find screen path for the attach command
SCREEN_PATH=$(which screen)
if [ -z "$SCREEN_PATH" ]; then
    echo "WARNING: 'screen' command not found. Option 2 (Attach to screen) might not work."
    # Don't exit, as other menu options might still be useful.
fi
# --- End of TARGET_USER determination ---

# Definer navnet på tjenesten og screen-sesjonen (bruker-spesifikk)
SERVICE_NAME="nosana-${TARGET_USER}.service"
SCREEN_SESSION_NAME="nosana_${TARGET_USER}"
# SERVICE_FILE is not strictly needed globally anymore as setup_nosana_screen.sh handles its own path logic
# However, check_service_status and enable_service might use it if they check for file existence.
# For now, let's define it for compatibility with any such checks.
SERVICE_FILE_PATH="/etc/systemd/system/${SERVICE_NAME}" # For functions that might check file existence
SCRIPT_VERSION="1.2.0" # Updated version for new screen integration

# Funksjon for å vise menyen
show_menu() {
    clear
    echo "========================================="
    echo "      Nosana Service Manager v${SCRIPT_VERSION}"
    echo "========================================="
    echo " Target User: $TARGET_USER"
    echo " Service Name: $SERVICE_NAME"
    echo " Screen Session: $SCREEN_SESSION_NAME"
    echo "-----------------------------------------"
    echo "1. Install/Reconfigure Nosana Service (via setup_nosana_screen.sh)"
    echo "2. Attach to Nosana Screen (${SCREEN_SESSION_NAME})"
    echo "3. Check Nosana Service Status (${SERVICE_NAME})"
    echo "4. Disable and Stop Service (${SERVICE_NAME})"
    echo "5. Enable and Start Service (${SERVICE_NAME})"
    echo "6. Exit"
    echo "-----------------------------------------"
}

# Funksjon for å installere/konfigurere systemd-tjenesten via setup_nosana_screen.sh
install_service() {
    echo "INFO: Attempting to install/reconfigure the Nosana service using setup_nosana_screen.sh..."
    echo "      This will run setup_nosana_screen.sh with sudo."
    if [ -f ./setup_nosana_screen.sh ]; then
        sudo bash ./setup_nosana_screen.sh
        echo "INFO: Installation script finished. Check its output for status."
        # Refresh TARGET_USER and related names in case setup_nosana_screen.sh was run for a *different* user
        # than initially detected by this menu script (e.g. if sudo was used with -u option).
        # This is a best-effort for the menu, the actual service will be per setup_nosana_screen.sh's logic.
        if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
            TARGET_USER="$SUDO_USER"
        elif [ "$(logname)" != "root" ] && [ -n "$(logname)" ]; then
            TARGET_USER="$(logname)"
        else
            TARGET_USER="user"
        fi
        SERVICE_NAME="nosana-${TARGET_USER}.service"
        SCREEN_SESSION_NAME="nosana_${TARGET_USER}"
        SERVICE_FILE_PATH="/etc/systemd/system/${SERVICE_NAME}"
        echo "INFO: Menu service/screen names updated to reflect user '$TARGET_USER'."

    else
        echo "ERROR: setup_nosana_screen.sh not found in the current directory."
        echo "       Please ensure it is present and try again."
    fi
    echo "Press Enter to return to the menu..."
    read -r
}

# Funksjon for å koble til screen-sesjonen
attach_to_screen() {
    echo "INFO: Attempting to attach to screen session '$SCREEN_SESSION_NAME' for user '$TARGET_USER'..."
    if [ -z "$SCREEN_PATH" ]; then
        echo "ERROR: 'screen' command not found. Cannot attach."
    else
        # Check if the screen session exists
        # The -q option for grep suppresses output, we just need the exit status.
        if sudo -u "$TARGET_USER" "$SCREEN_PATH" -ls | grep -q -E "[0-9]+\.${SCREEN_SESSION_NAME}\s+\((Attached|Detached)\)"; then
            echo "INFO: Found active screen session. Attaching..."
            echo "      Press Ctrl+A then D to detach."
            echo "-----------------------------------------"
            sudo -u "$TARGET_USER" "$SCREEN_PATH" -r "$SCREEN_SESSION_NAME"
            echo "-----------------------------------------"
            echo "INFO: Detached from screen session."
        else
            echo "INFO: Screen session '$SCREEN_SESSION_NAME' for user '$TARGET_USER' not found or not running."
            echo "      You can try starting/enabling the service (Option 5)."
            echo "      For detailed service logs, use: journalctl -u $SERVICE_NAME"
        fi
    fi
    echo "Press Enter to return to the menu..."
    read -r
}

# Funksjon for å sjekke tjenestestatus
check_service_status() {
    echo "INFO: Checking Nosana service status (${SERVICE_NAME})..."
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
