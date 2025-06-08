#!/bin/bash

# Definer navnet på tjenesten
SERVICE_NAME="nosana.service"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}"

# Funksjon for å vise menyen
show_menu() {
    clear
    echo "========================================="
    echo "      Nosana Service Manager"
    echo "========================================="
    echo "1. Install Nosana Auto-Start Service"
    echo "2. View Live Log (Status)"
    echo "3. Disable and Stop Service"
    echo "4. Enable and Start Service"
    echo "5. Exit"
    echo "-----------------------------------------"
}

# Funksjon for å installere systemd-tjenesten
install_service() {
    echo "Installing Nosana service..."
    if [ -f "$SERVICE_FILE" ]; then
        echo "Service file already exists. Re-creating it."
    fi

    # Opprett tjenestefilen med sudo
    sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Nosana Node
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/bin/bash -c "wget -qO- https://nosana.com/start.sh | /bin/bash"
User=root
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    # Last inn systemd på nytt, aktiver og start tjenesten
    echo "Reloading systemd and starting the service..."
    sudo systemctl daemon-reload
    sudo systemctl enable --now ${SERVICE_NAME}

    echo ""
    echo "Nosana service has been installed and started."
    echo "It will now automatically start on every reboot."
    echo "Press Enter to continue."
    read
}

# Funksjon for å se live logg
view_log() {
    echo "Showing live log for ${SERVICE_NAME}..."
    echo "Press Ctrl+C to exit the log view."
    echo "-----------------------------------------"
    journalctl -u ${SERVICE_NAME} -f
    echo ""
    echo "Log view exited. Press Enter to return to the menu."
    read
}

# Funksjon for å deaktivere tjenesten
disable_service() {
    echo "Disabling and stopping the Nosana service..."
    sudo systemctl disable --now ${SERVICE_NAME}
    echo ""
    echo "Service has been stopped and disabled. It will not run on startup."
    echo "Press Enter to continue."
    read
}

# Funksjon for å aktivere tjenesten
enable_service() {
    if [ ! -f "$SERVICE_FILE" ]; then
        echo "Service is not installed yet. Please install it first (Option 1)."
        echo "Press Enter to continue."
        read
        return
    fi
    echo "Enabling and starting the Nosana service..."
    sudo systemctl enable --now ${SERVICE_NAME}
    echo ""
    echo "Service has been enabled and started. It will now run on startup."
    echo "Press Enter to continue."
    read
}

# Hovedløkke for menyen
while true; do
    show_menu
    read -p "Choose an option [1-5]: " choice
    case $choice in
        1) install_service ;;
        2) view_log ;;
        3) disable_service ;;
        4) enable_service ;;
        5) echo "Exiting."; exit 0 ;;
        *) echo "Invalid option. Please try again."; sleep 2 ;;
    esac
done
