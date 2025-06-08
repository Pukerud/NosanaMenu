# Nosana Service Manager

A simple Bash script for managing the Nosana Node as a `systemd` service on Linux. This allows the Nosana Node to start automatically at boot and simplifies its management.

## Prerequisites

*   A Linux distribution that uses `systemd` (e.g., Ubuntu, Debian, Fedora, CentOS).
*   You must have `sudo` privileges.
*   `git` must be installed to clone the repository.

## How to Use

1.  **Clone the repository**
    Open your terminal and clone this repository to your machine.

    ```bash

    git clone https://github.com/Pukerud/NosanaMenu.git

    ```

2.  **Navigate to the directory**

    ```bash
    cd NosanaMenu
    ```

3.  **Make the script executable**
    Give the `setup.sh` script execution permissions.

    ```bash
    chmod +x setup.sh
    ```

4.  **Run the script**
    Execute the script. It will prompt for your `sudo` password if required.

    ```bash
    ./setup.sh
    ```

## Menu Options

After running the script, you will see a menu with the following options:

### 1. Install Nosana Auto Start
This option creates a `systemd` service file for the Nosana Node. It will:
*   Place a service file in `/etc/systemd/system/nosana.service`.
*   Reload `systemd`.
*   Enable the service to start automatically on boot.
*   Start the service immediately.

### 2. View current status
This option displays a live log from the Nosana service. It uses `journalctl` to stream the output directly to your terminal, which is useful for monitoring the node's activity in real-time.
*   Press `Ctrl+C` to exit the log view and return to the menu.

### 3. Disable service
This option stops the running Nosana service and disables it from starting automatically on boot.

### 4. Enable service
This option will enable the Nosana service to start on boot and start it immediately. Useful if you have previously disabled it.

### 5. Update Environment Variables
This option allows you to update the environment variables for the Nosana Node. It will:
*   Prompt you to enter the new environment variables.
*   Update the `nosana.service` file with the new environment variables.
*   Reload `systemd`.
*   Restart the Nosana service to apply the changes.

### 6. Update Node
This option allows you to update the Nosana Node to the latest version. It will:
*   Stop the Nosana service.
*   Download the latest version of the Nosana Node.
*   Replace the existing Nosana Node executable with the new version.
*   Start the Nosana service.

### 7. Exit
Exits the script.
