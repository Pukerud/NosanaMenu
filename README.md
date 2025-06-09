# Nosana Service Manager

A simple Bash script for managing the Nosana Node as a `systemd` service on Linux. This allows the Nosana Node to start automatically at boot and simplifies its management.

## Prerequisites

*   A Linux distribution that uses `systemd` (e.g., Ubuntu, Debian, Fedora, CentOS).
*   You must have `sudo` privileges.
*   `git` must be installed to clone the repository.

## How to Use

Open your terminal and run the following command to clone the repository, navigate into the directory, make the setup script executable, and run it. This single command automates the initial setup process. It will prompt for your `sudo` password if required for the script execution.

```bash
if [ -d "NosanaMenu" ]; then cd NosanaMenu && git pull && chmod +x setup.sh && ./setup.sh; else git clone https://github.com/Pukerud/NosanaMenu.git && cd NosanaMenu && chmod +x setup.sh && ./setup.sh; fi
```

## Menu Options

After running the script, you will see a menu with the following options:

### 1. Install Nosana Auto Start
This option creates a `systemd` service file for the Nosana Node. It will:
*   Prompt for a username to run the service (must be in the `docker` group).
*   Install `screen` if it's not already present.
*   Place a service file in `/etc/systemd/system/nosana.service`. The service is configured to run the Nosana start script within a detached `screen` session named `nosana` (e.g., `ExecStart=/usr/bin/screen -S nosana -dm bash -c "wget -qO- https://nosana.com/start.sh | bash"`).
*   Reload `systemd`.
*   Enable the service to start automatically on boot.
*   Start the service immediately.

### 2. View Live Status / Attach to Screen
This option allows you to connect to the `screen` session where the Nosana Node is running.
*   It first reads the `/etc/systemd/system/nosana.service` file to determine the `User` the service (and thus the screen session) runs as.
*   It then checks if a `screen` session named `nosana` exists for that user (e.g., using `sudo -u <USER> screen -ls | grep '\.nosana'`).
*   If the session is found, it will attempt to attach to it using `sudo -u <USER> screen -r nosana`.
*   If the session is not found, an informative message will be displayed, guiding you to check the service status or logs.
*   To detach from the screen session (leaving the Nosana Node running in the background), press `Ctrl+A` then `D`.
*   After detaching or if the session was not found, you'll be prompted to press Enter to return to the menu.

### 3. Check Nosana Service Status
This option displays the current status of the `nosana.service` using `systemd`.
*   It runs the command `systemctl status nosana.service --no-pager` for a concise output.
*   This is useful for quickly verifying if the service is active, failed, or to see recent log entries from `journald` related to the service.

### 4. Disable Service
This option stops the running Nosana service and disables it from starting automatically on boot.

### 5. Enable Service
This option will enable the Nosana service to start on boot and start it immediately. Useful if you have previously disabled it.

### 6. Update Environment Variables
This option allows you to update the environment variables for the Nosana Node. It will:
*   Prompt you to enter the new environment variables.
*   Update the `nosana.service` file with the new environment variables.
*   Reload `systemd`.
*   Restart the Nosana service to apply the changes.

### 7. Update Node
This option allows you to update the Nosana Node to the latest version. It will:
*   Stop the Nosana service.
*   Download the latest version of the Nosana Node.
*   Replace the existing Nosana Node executable with the new version.
*   Start the Nosana service.

### 8. Exit
Exits the script.
