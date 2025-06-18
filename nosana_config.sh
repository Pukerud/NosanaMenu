#!/usr/bin/env bash
set -e # Exit immediately if a command exits with a non-zero status.
set -u # Treat unset variables as an error when substituting.
set -o pipefail # Causes a pipeline to return the exit status of the last command in the pipe that returned a non-zero return value.

# --- Dynamically determine TARGET_USER ---
if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
    TARGET_USER="$SUDO_USER"
    echo "INFO: TARGET_USER determined from SUDO_USER: $TARGET_USER"
elif [ "$(logname)" != "root" ]; then
    TARGET_USER="$(logname)"
    echo "INFO: TARGET_USER determined from logname: $TARGET_USER"
else
    echo "ERROR: Could not determine a non-root TARGET_USER." >&2
    echo "  If running with sudo, ensure it's from a non-root user account (SUDO_USER will be set)." >&2
    echo "  If running directly, ensure you are logged in as a non-root user." >&2
    exit 1
fi

if [ "$TARGET_USER" = "root" ]; then
    echo "ERROR: The TARGET_USER is determined as 'root'. The service should not run as root." >&2
    echo "  Please execute this script as a non-root user or via sudo from a non-root user account." >&2
    exit 1
fi

if ! getent group docker | grep -qw "$TARGET_USER"; then
    echo "ERROR: User '$TARGET_USER' is not a member of the 'docker' group." >&2
    echo "  Please add the user to the 'docker' group using: sudo usermod -aG docker $TARGET_USER" >&2
    echo "  You may need to log out and log back in for the group changes to take effect." >&2
    exit 1
fi
echo "INFO: TARGET_USER is '$TARGET_USER' and is a member of the 'docker' group."
# --- End of TARGET_USER determination ---

# --- Path Discovery for docker and sudo ---
DOCKER_PATH=$(which docker)
if [ -z "$DOCKER_PATH" ]; then
    echo "ERROR: docker command not found. Please install Docker." >&2
    exit 1
fi
echo "INFO: Found docker at $DOCKER_PATH"

SUDO_PATH=$(which sudo)
if [ -z "$SUDO_PATH" ]; then
    echo "ERROR: sudo command not found. This script expects sudo to be available." >&2
    exit 1
fi
echo "INFO: Found sudo at $SUDO_PATH"
# --- End of Path Discovery ---

# --- Global Variable Definitions ---
START_SCRIPT_PATH="/usr/local/bin/start_nosana_${TARGET_USER}.sh"
SUDOERS_FILE="/etc/sudoers.d/90-nosana-${TARGET_USER}-permissions"
SERVICE_FILE_PATH="/etc/systemd/system/nosana-${TARGET_USER}.service"

echo ""
echo "--- Configuration Summary ---"
echo "  TARGET_USER: $TARGET_USER"
echo "  Docker Path: $DOCKER_PATH"
echo "  Sudo Path: $SUDO_PATH"
echo "  Start Script: $START_SCRIPT_PATH"
echo "  Sudoers File: $SUDOERS_FILE"
echo "  Service File: $SERVICE_FILE_PATH"
echo "---------------------------"
echo ""
# --- End of Global Variable Definitions ---

# --- Script Functions ---

create_start_script() {
    echo "INFO: Creating start script at $START_SCRIPT_PATH..."
    # The content of this script must be exactly as specified.
    # This function must be run with sudo privileges to write to /usr/local/bin
    cat <<EOF | $SUDO_PATH tee "$START_SCRIPT_PATH" > /dev/null
#!/bin/bash
bash <(wget -qO- https://nosana.com/start.sh)
EOF
    $SUDO_PATH chmod +x "$START_SCRIPT_PATH"
    echo "INFO: Start script created and made executable at $START_SCRIPT_PATH."
}

setup_sudoers() {
    echo "INFO: Setting up sudoers file at $SUDOERS_FILE..."
    # This function must be run with sudo privileges.
    # The content allows TARGET_USER to run specific commands as root without a password.
    cat <<EOF | $SUDO_PATH tee "$SUDOERS_FILE" > /dev/null
Defaults:$TARGET_USER !requiretty
$TARGET_USER ALL=(ALL) NOPASSWD: $START_SCRIPT_PATH
$TARGET_USER ALL=(ALL) NOPASSWD: $DOCKER_PATH stop nosana-node
EOF
    $SUDO_PATH chmod 0440 "$SUDOERS_FILE"
    echo "INFO: Sudoers file created at $SUDOERS_FILE with permissions 0440."
    echo "      Validate with: $SUDO_PATH visudo -cf $SUDOERS_FILE"
}

create_service_file() {
    echo "INFO: Creating systemd service file at $SERVICE_FILE_PATH..."
    # This function must be run with sudo privileges.
    cat <<EOF | $SUDO_PATH tee "$SERVICE_FILE_PATH" > /dev/null
[Unit]
Description=Nosana Node Service ($TARGET_USER)
After=network.target docker.service
Requires=docker.service

[Service]
User=$TARGET_USER
WorkingDirectory=/home/$TARGET_USER
ExecStart=$SUDO_PATH $START_SCRIPT_PATH
ExecStop=$SUDO_PATH $DOCKER_PATH stop nosana-node
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    echo "INFO: Service file created at $SERVICE_FILE_PATH."
    echo "      Reload systemd daemon after this: $SUDO_PATH systemctl daemon-reload"
}

# --- Main execution (example flow) ---
echo "--- Nosana Node Configuration Script ---"
echo "This script prepares the system for running the Nosana Node as $TARGET_USER."
echo "It will create a start script, sudoers permissions, and a systemd service file."
echo "You will need to have sudo privileges to run the functions that modify system files."
echo ""
echo "Next steps (typically run by an installer or manually with sudo):"
echo "1. Call 'create_start_script' (requires sudo: $SUDO_PATH bash $0 call_create_start_script)"
echo "2. Call 'setup_sudoers' (requires sudo: $SUDO_PATH bash $0 call_setup_sudoers)"
echo "3. Call 'create_service_file' (requires sudo: $SUDO_PATH bash $0 call_create_service_file)"
echo "4. Reload systemd: $SUDO_PATH systemctl daemon-reload"
echo "5. Enable the service: $SUDO_PATH systemctl enable --now nosana-${TARGET_USER}.service"
echo "   (Service name is: nosana-${TARGET_USER}.service)"

# This allows calling functions directly using arguments, e.g. "sudo bash nosana_config.sh call_create_start_script"
if [ "${1:-}" = "call_create_start_script" ]; then
    create_start_script
    exit 0
fi
if [ "${1:-}" = "call_setup_sudoers" ]; then
    setup_sudoers
    exit 0
fi
if [ "${1:-}" = "call_create_service_file" ]; then
    create_service_file
    exit 0
fi

echo ""
echo "INFO: nosana_config.sh initial setup and variable definition complete for TARGET_USER: $TARGET_USER."
echo "      Use arguments like 'call_create_start_script' with sudo to execute specific setup functions."
# --- End of Main execution ---
