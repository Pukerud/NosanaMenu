#!/usr/bin/env bash
set -e
set -u

# Definer navnet på tjenesten
SERVICE_NAME="nosana.service"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}"
SCRIPT_VERSION="1.0.2"

# Funksjon for å vise menyen
show_menu() {
    clear
    echo "========================================="
    echo "      Nosana Service Manager v${SCRIPT_VERSION}"
    echo "========================================="
    echo "1. Install Nosana Auto-Start Service"
    echo "2. View Live Status / Attach to Screen"
    echo "3. Check Nosana Service Status"
    echo "4. Disable and Stop Service"
    echo "5. Enable and Start Service"
    echo "6. Exit"
    echo "-----------------------------------------"
}

# Funksjon for å installere systemd-tjenesten (INTERAKTIV VERSJON)
install_service() {
    echo "DEBUG: Starting install_service"
    echo "Installing Nosana service..."

    # Determine the user to run the service
    if [ -n "$SUDO_USER" ]; then
        NOSANA_USER="$SUDO_USER"
    elif [ "$(logname)" != "root" ]; then
        NOSANA_USER="$(logname)"
    else
        NOSANA_USER="nosana" # Default to 'nosana' if running as root and no SUDO_USER
    fi
    echo "Nosana service will run as user: $NOSANA_USER"
    echo "This user must be a member of the 'docker' group."

    # Check if user is in docker group
    if ! getent group docker | grep -qw "$NOSANA_USER"; then
        echo "Error: User '$NOSANA_USER' is not a member of the 'docker' group."
        echo "Please add the user to the 'docker' group first. Example: sudo usermod -aG docker $NOSANA_USER"
        echo "You may need to log out and log back in for the group changes to take effect."
        echo "Aborting service installation."
        return 1
    fi

    echo "Updating package list and installing git..."
    sudo apt-get update && sudo apt-get install -y git

    # Installer screen
    echo "Installing screen..."
    sudo apt-get update && sudo apt-get install -y screen

    # Opprett tjenestefilen med sudo
    sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Nosana Node
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/usr/bin/screen -S nosana -dm bash -ic "wget -qO- https://nosana.com/start.sh | bash; exec bash"
User=$NOSANA_USER
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    echo "Reloading systemd and starting the service..."
    sudo systemctl daemon-reload
    sudo systemctl enable --now ${SERVICE_NAME}

    echo ""
    echo "Nosana service has been installed. It will now run in an interactive shell environment."
}

# Funksjon for å se live logg
view_log() {
    echo "DEBUG: Starting view_log"
    echo "Checking for Nosana screen session..."

    if [ ! -f "$SERVICE_FILE" ]; then
        echo "Error: Service file $SERVICE_FILE not found."
        echo "Please install the service first (Option 1)."
        return
    fi

    NOSANA_USER=$(grep -Po '^User=\K.*' "$SERVICE_FILE")

    if [ -z "$NOSANA_USER" ]; then
        echo "Error: Could not determine the user for the Nosana service from $SERVICE_FILE."
        echo "The User= line might be missing or incorrectly formatted."
        return
    fi

    echo "Service is configured to run as user: $NOSANA_USER"

    echo "Cleaning up dead screen sessions (if any) for user $NOSANA_USER..."
    sudo -u "$NOSANA_USER" screen -wipe >/dev/null 2>&1

    if sudo -u "$NOSANA_USER" screen -ls | grep -q -E "[0-9]+\.nosana\s+\((Attached|Detached)\)"; then
        echo "Found active Nosana screen session. Attaching..."
        echo "Press Ctrl+A then D to detach from the screen session."
        echo "-----------------------------------------"
        sudo -u "$NOSANA_USER" screen -r nosana
        echo "-----------------------------------------"
        echo "Screen session detached."
    else
        echo "Nosana screen session 'nosana' is not running or could not be uniquely identified for user '$NOSANA_USER'."
        echo "You can try starting/enabling the service (Option 5 in the menu)."
        echo "For detailed service logs, you can use: journalctl -u ${SERVICE_NAME}"
        echo "Or check the overall service status (Option 3 in the menu)."
    fi
    echo ""
}

# Funksjon for å sjekke tjenestestatus
check_service_status() {
    echo "DEBUG: Starting check_service_status"
    echo "Checking Nosana service status (${SERVICE_NAME})..."
    echo "-----------------------------------------"
    systemctl status ${SERVICE_NAME} --no-pager
    echo "-----------------------------------------"
    echo "Status check complete."
}

# Funksjon for å deaktivere tjenesten
disable_service() {
    echo "DEBUG: Starting disable_service"
    echo "Disabling and stopping the Nosana service..."
    sudo systemctl disable --now ${SERVICE_NAME}
    echo ""
    echo "Service has been stopped and disabled. It will not run on startup."
}

# Funksjon for å aktivere tjenesten
enable_service() {
    echo "DEBUG: Starting enable_service"
    if [ ! -f "$SERVICE_FILE" ]; then
        echo "Service is not installed yet. Please install it first (Option 1)."
        return
    fi
    echo "Enabling and starting the Nosana service..."
    sudo systemctl enable --now ${SERVICE_NAME}
    echo ""
    echo "Service has been enabled and started. It will now run on startup."
}

# Non-interactive installation mode
if [ "${1:-}" = "install" ]; then
    install_service
    exit 0
fi

# Hovedløkke for menyen
while true; do
    show_menu
    read -p "Choose an option [1-6]: " choice
    case $choice in
        1) eval install_service ;;
        2) eval view_log ;;
        3) eval check_service_status ;;
        4) eval disable_service ;;
        5) eval enable_service ;;
        6) echo "Exiting."; exit 0 ;;
        *) echo "Invalid option. Please try again."; sleep 2 ;;
    esac
done
