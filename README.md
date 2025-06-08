# Nosana Service Manager

Et enkelt BASH-script for å administrere Nosana Node som en `systemd`-tjeneste på Linux. Dette lar Nosana-scriptet starte automatisk ved oppstart og gjør det enkelt å administrere.

## Forutsetninger

*   En Linux-distribusjon som bruker `systemd` (f.eks. Ubuntu, Debian, Fedora, CentOS).
*   Du må ha `sudo`-rettigheter.
*   `git` må være installert for å klone repository-et.

## Hvordan bruke

1.  **Klon repository-et**
    Åpne terminalen din og klon dette repository-et til maskinen din. Bytt ut `<ditt-brukernavn>/<ditt-repo>` med den faktiske URL-en.

    ```bash
    git clone https://github.com/<ditt-brukernavn>/<ditt-repo>.git
    ```

2.  **Naviger til mappen**

    ```bash
    cd <ditt-repo>
    ```

3.  **Gjør scriptet kjørbart**
    Gi `setup.sh`-scriptet kjøretillatelser.

    ```bash
    chmod +x setup.sh
    ```

4.  **Kjør scriptet**
    Utfør scriptet. Det vil be om `sudo`-passord ved behov.

    ```bash
    ./setup.sh
    ```

## Menyvalg

Etter at du har kjørt scriptet, vil du se en meny med følgende valg:

### 1. Install Nosana Auto Start
Dette valget oppretter en `systemd`-tjenestefil for Nosana-scriptet. Det vil:
*   Plassere en tjenestefil i `/etc/systemd/system/nosana.service`.
*   Laste inn `systemd` på nytt.
*   Aktivere tjenesten til å starte automatisk ved oppstart.
*   Starte tjenesten umiddelbart.

### 2. View current status
Dette valget viser en live logg fra Nosana-tjenesten. Det bruker `journalctl` for å strømme outputen direkte til terminalen din, noe som er nyttig for å overvåke nodens aktivitet i sanntid.
*   Trykk `Ctrl+C` for å avslutte loggvisningen og returnere til menyen.

### 3. Disable service
Dette valget stopper den kjørende Nosana-tjenesten og deaktiverer den fra å starte automatisk ved oppstart.

### 4. Enable service
Dette valget vil aktivere Nosana-tjenesten til å starte ved oppstart og starte den umiddelbart. Nyttig hvis du tidligere har deaktivert den.

### 5. Exit
Avslutter scriptet.
