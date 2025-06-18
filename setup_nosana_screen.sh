#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "FEIL: Dette scriptet må kjøres som root (eller med sudo)." >&2
  exit 1
fi

# ==============================================================================
#  DEFINITIVT Konfigurasjonsscript for Nosana - SCREEN-METODEN (v6)
# ==============================================================================
#  Basert på den utmerkede ideen om å bruke 'screen' for å lage en
#  ekte terminal for Nosana-scriptet.
#
#  Dette scriptet MÅ kjøres som root.
# ==============================================================================

# Definer bruker og filstier
# TARGET_USER="octa" # This will be made dynamic in a later step

# --- Dynamically determine TARGET_USER ---
if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
    TARGET_USER="$SUDO_USER"
    echo "INFO: TARGET_USER determined from SUDO_USER: $TARGET_USER"
elif [ "$(logname)" != "root" ] && [ -n "$(logname)" ]; then # Added -n to ensure logname is not empty
    TARGET_USER="$(logname)"
    echo "INFO: TARGET_USER determined from logname: $TARGET_USER"
else
    echo "ERROR: Could not determine a non-root TARGET_USER." >&2
    echo "  This script should be run via sudo by a non-root user, or directly by a logged-in non-root user." >&2
    exit 1
fi

if [ "$TARGET_USER" = "root" ]; then # This check is somewhat redundant if the above logic is correct but acts as a safeguard.
    echo "ERROR: The TARGET_USER is determined as 'root'. The service should not run as root." >&2
    echo "  Please execute this script as a non-root user or via sudo from a non-root user account." >&2
    exit 1
fi

# Check if the determined user is a member of the "docker" group.
if ! getent group docker | grep -qw "$TARGET_USER"; then
    echo "ERROR: User '$TARGET_USER' is not a member of the 'docker' group." >&2
    echo "  Please add the user to the 'docker' group using: sudo usermod -aG docker $TARGET_USER" >&2
    echo "  You may need to log out and log back in for the group changes to take effect." >&2
    exit 1
fi
echo "INFO: TARGET_USER is '$TARGET_USER' and is a member of the 'docker' group."
# --- End of TARGET_USER determination ---

START_SCRIPT_PATH="/usr/local/bin/start_nosana_${TARGET_USER}.sh"
SUDOERS_FILE="/etc/sudoers.d/90-nosana-${TARGET_USER}-permissions"
SERVICE_FILE_PATH="/etc/systemd/system/nosana-${TARGET_USER}.service"
SCREEN_SESSION_NAME="nosana"

# --- Forberedelser ---
echo "🚀 Starter konfigurasjon for Nosana med screen-metoden..."

# Steg 0: Stopp og deaktiver gammel tjeneste for sikkerhets skyld
if systemctl list-units --full -all | grep -q 'nosana.service'; then
    echo "INFO: Stopper og deaktiverer eksisterende nosana.service..."
    systemctl stop nosana.service >/dev/null 2>&1
    systemctl disable nosana.service >/dev/null 2>&1
else
    echo "INFO: Ingen eksisterende nosana.service funnet, hopper over deaktivering."
fi


# Steg 1: Sjekk om screen er installert
if ! command -v screen &> /dev/null; then
    echo "⚠️  'screen' er ikke installert. Installerer nå..."
    if command -v apt-get &> /dev/null; then
        apt-get update
        apt-get install -y screen
    elif command -v yum &> /dev/null; then
        yum install -y screen
    elif command -v dnf &> /dev/null; then
        dnf install -y screen
    else
        echo "❌ Kritiske feil: Kunne ikke finne en kjent pakkebehandler (apt-get, yum, dnf) for å installere 'screen'."
        exit 1
    fi

    if ! command -v screen &> /dev/null; then
        echo "❌ Kunne ikke installere 'screen'. Avbryter."
        exit 1
    fi
fi
echo "✅ 'screen' er installert."

# --- Finn stier til kommandoer ---
DOCKER_PATH=$(which docker)
SUDO_PATH=$(which sudo)
SCREEN_PATH=$(which screen)

if [ -z "$DOCKER_PATH" ]; then
    echo "❌ Feil: Kunne ikke finne 'docker'. Sjekk at det er installert."
    exit 1
fi
if [ -z "$SUDO_PATH" ]; then
    echo "❌ Feil: Kunne ikke finne 'sudo'. Sjekk at det er installert."
    exit 1
fi
if [ -z "$SCREEN_PATH" ]; then
    echo "❌ Feil: Kunne ikke finne 'screen' (selv etter installasjonsforsøk). Avbryter."
    exit 1
fi
echo "✅ Docker funnet på: $DOCKER_PATH"
echo "✅ Sudo funnet på: $SUDO_PATH"
echo "✅ Screen funnet på: $SCREEN_PATH"


# --- STEG 2: Opprett et ENKELT start-script ---
echo "📝 Oppretter et rent start-script på $START_SCRIPT_PATH..."
cat <<EOF > "$START_SCRIPT_PATH"
#!/bin/bash
# Kjører Nosanas script direkte. 'screen' vil gi den terminalen den trenger.
bash <(wget -qO- https://nosana.com/start.sh)
EOF
chmod +x "$START_SCRIPT_PATH"
echo "✅ Rent start-script opprettet."

# --- STEG 3: Konfigurer Sudo ---
echo "🔐 Konfigurerer passordløs sudo-tilgang..."
cat <<EOF > "$SUDOERS_FILE"
# Gir '$TARGET_USER' lov til å kjøre kommandoer for Nosana uten passord.
$TARGET_USER ALL=(ALL) NOPASSWD: $START_SCRIPT_PATH
$TARGET_USER ALL=(ALL) NOPASSWD: $DOCKER_PATH stop nosana-node
EOF
chmod 0440 "$SUDOERS_FILE"
echo "✅ Sudoers-fil opprettet."

# --- STEG 4: Opprett systemd-tjeneste for å styre SCREEN ---
echo "⚙️ Oppretter systemd-tjeneste for å styre screen-sesjonen..."
cat <<EOF > "$SERVICE_FILE_PATH"
[Unit]
Description=Nosana Node (managed via screen session: $SCREEN_SESSION_NAME)
After=network.target docker.service
Requires=docker.service

[Service]
# 'forking' er riktig type, da screen-kommandoen starter en prosess og avslutter.
Type=forking
User=$TARGET_USER
WorkingDirectory=/home/$TARGET_USER

# Kommando for å starte en navngitt, løsrevet screen-sesjon som kjører start-scriptet
ExecStart=$SCREEN_PATH -S $SCREEN_SESSION_NAME -dm $SUDO_PATH $START_SCRIPT_PATH

# Kommando for å stoppe alt i screen-sesjonen og avslutte den
ExecStop=$SCREEN_PATH -S $SCREEN_SESSION_NAME -X quit

[Install]
WantedBy=multi-user.target
EOF
echo "✅ systemd service-fil for screen opprettet."

# --- STEG 5: Last inn endringer ---
echo "🔄 Laster inn systemd for å gjenkjenne den nye tjenesten..."
systemctl daemon-reload

# --- FERDIGMELDING ---
echo ""
echo "🎉 Konfigurasjon fullført! Din idé med 'screen' er nå implementert."
echo "Systemet er nå fullstendig konfigurert."
echo ""
echo "Bruk som vanlig:"
echo "  systemctl start nosana-${TARGET_USER}.service"
echo "  systemctl stop nosana-${TARGET_USER}.service"
echo "  systemctl status nosana-${TARGET_USER}.service"
echo ""
echo "✨ For å SE hva som skjer inne i terminalen, kjør:"
echo "  sudo -u $TARGET_USER screen -r $SCREEN_SESSION_NAME"
echo "(Trykk Ctrl+A, deretter D for å løsrive deg igjen uten å stoppe den)"
echo ""
