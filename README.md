# Raspberry Pi aufsetzen mit Docker

## Scope

Dieses Dokument beschreibt die Installation einer Home Steuerungs Software auf
einem Raspberry Pi. Die folgenden Komponenten sind enthalten:

* **Mosquitto** - Open Source MQTT Broker. Ist nach der Installation unter
`mqtt://raspberry.local:1883` erreichbar.
* **zigbee2mqtt** - Bindet *Zigbee* Geräte an den Mosquitto *MQTT* broker ein.
Stellt unter `http://raspberry.local:8080` ein Web basiertes Frontend zur
Verfügung.
* **Node-Red** - Low Code Programmier-Umgebung. Ist unter
`http://raspberry.local:1880` mit einem Web Browser erreichbar.

Die Installation erfolgt in vier Schritten.

1. [SD-Karte vorbereiten](#PREPARE)
2. [Verbindung aufbauen](#CONNECT)
3. [Software Installation](#INSTALL)
4. [Docker Container starten](#START)

## SD Karte vorbereiten<a name="PREPARE"></a>

Mit dem Programm *Raspberry Pi Imager* wird im ersten Schritt die SD Karte zum
Booten des Raspberry Pi vorbereitet.

\<Shift> \<Ctrl> X öffnet die *Advanced Options* auf der die folgenden
Einstellungen vorgenommen werden können.

* Hostname
* SSH aktivieren
* Passwort festlegen
* Tastatur Layout
* Zeitzone
* evtl. WLAN Zugangsdaten

Sehr bequem kann man auch seinen public key eintragen, sodass bei der Anmeldung
am Raspberry Pi kein Passwort eingegeben werden muss.

## Verbindung aufbauen<a name="CONNECT"></a>

Die folgende Beschreibung geht davon aus, dass der Raspberry Pi headless, also
ohne angeschlossene Tastatur und Monitor betrieben wird. Hierzu wird eine SSH
(Secure Shell) Verbindung zum Raspberry Pi aufgebaut.

Bei einem auf UNIX basierenden Betriebssystem wie macOS oder Linux kann diese
Verbindung einfach mithilfe des folgenden Kommandos im Terminal aufgebaut
werden. Hierbei kann statt dem Namen des Raspberry Pi natürlich auch seine IP
Adresse verwendet werden. Diese muss man zuvor vom WLAN Router ermitteln.

````bash
>ssh pi@raspi.local
````

Um eine headless Verbindung von einem Windows PC aufzubauen, muss zuvor ein
SSH Client (z.B. putty) installiert werden.

Alternativ kann natürlich eine Tastatur und ein Monitor direkt am Raspberry Pi
verwendet werden. Dann muss man sich mit dem beim Vorbereiten festgelegten
Passwort anmelden.

Nach dem ersten Booten immer zunächst die Systemdateien aktualisieren und
danach erneut re-booten.

````bash
> sudo apt-get update
> sudo apt-get upgrade -y
> sudo reboot now
````

## Installation<a name="INSTALL"></a>

Nach dem Re-Booten wird die benötigte Software installiert. Dies kann entweder
durch ausführen eines Shell Scripts oder auch manuell erfolgen. Beide Methoden
werden im folgenden beschrieben.

### Script

Sowohl die Installation von Docker, als auch das Erstellen der benötigten
Konfigurations-Dateien wird automatisch durch das Shell Script
`installHomeCtrl.sh` erledigt. Das Script muss dabei auf dem Raspberry Pi
ausgeführt werden. (Nicht auf dem Computer mit dem man den Raspberry Pi
bedient).

Das Script muss aus dem Verzeichnis aufgerufen werden, in dem das Verzeichnis
`homectrl` angelegt werden soll. In der Regel im Home Verzeichnis des
Benutzers *pi* (`/home/pi`).

Die folgende Kommando Sequenz kopiert zunächst das Installations Script ins
Home Verzeichnis, verbindet sich dann mit dem Raspberry Pi und führt als
letzten Schritt das scrip aus.

````bash
tom@Mac Home %scp installHomeCtrl.sh pi@raspi12.local:/home/pi
installHomeCtrl.sh                            100%   10KB 733.0KB/s   00:00    
tom@Mac Home %ssh pi@raspi12.local                            
Linux raspi12 6.12.25+rpt-rpi-v8 #1 SMP PREEMPT Debian 1:6.12.25-1+rpt1 (2025-04-30) aarch64

Last login: Sun Jun 15 14:01:40 2025 from 192.168.178.35
pi@raspi12:~ $ ./installHomeCtrl.sh
````

Das Script erledigt dann die folgenden Schritte:

1. Detektiert das angeschlossene Zigbee Interface und den verwendeten USB
Port. Momentan werden lediglich die beiden Typen *Conbee II* und
*ConBee III* von Dresden Elektronik unterstützt.
2. Ermittelt, ob Docker bereits installiert ist. Wenn ja, überprüft es die
Versionsnummer. Bei Versionen kleiner als `17.04.0` wird die Installation
abgebrochen, da `docker compose` nicht unterstützt wird. Ist Docker noch nicht
vorhanden, so wird es von `https://get.docker.com` heruntergeladen und
installiert.
3. Erstellung des Verzeichnisses `homectrl` (Name kann vom Benutzer verändert
werden) und darin der für die verschiedenen Pakete benötigten Verzeichnisse
und Dateien.

Nach Abschluss der Installation stehen die folgenden Verzeichnisse und Dateien
zur Verfügung:

````text
homectrl
  compose.yaml              # Docker Composer, definiert verwendete Container
  mosquitto-data            # Daten Verzeichnis für Mosquitto
    mosquitto.conf          # Mosquitto Konfigurations
  node-red-data             # Daten Verzeichnis für Node-Red
  zigbee2mqtt-data          # Daten Verzeichnis für zigbee2mqtt
    configuration.yaml      # zigbee2mqtt Konfiguration
````

Nun ist die Installation abgeschlossen. Es empfiehlt sich ein Restart und
dann können die Container gestartet und verwendet werden. Das wird
[hier](#START) beschrieben.

### Manuelle Installation

#### Docker installieren

Docker **nicht** mittels `apt-get` installieren, da die in dessen Repository
enthaltene Version hoffnungslos veraltet ist. Stattdessen Docker mit Hilfe
der folgenden Befehle installieren.

````bash
> curl -fsSL https://get.Docker.com -o get-Docker.sh
> sudo sh get-Docker.sh
> sudo usermod -aG docker $USER
> newgrp docker
> docker --version
````

Die einzelnen Befehlszeilen bewirken dabei folgendes:

1. Das Installations Shell Script `get-Docker.sh` von der `Docker.com` Website
laden.
2. Das Script mit Root Rechten ausführen.
3. Den aktuellen User der Gruppe `docker` hinzufügen.
4. Die Rechte der Gruppe `docker` setzen (Alternativ muss sich der User ab-
und wieder anmelden).
5. Die Versionsabfrage von Docker sollte zumindest `v28.1.1` angezeigt werden.

Jetzt ist Docker erfolgreich installiert und kann verwendet werden.

#### Docker installieren

In einem Verzeichnis im home Verzeichnisses werden alle Daten der benötigten
Komponenten bereit gestellt. Im folgenden wird das Verzeichnis `homectrl`
verwendet.  Die für die Home Automatisierung benötigten Komponenten
werden mittels `docker compose` zusammengestellt.

````bash
> mkdir homectrl
> cd homectrl
> mkdir zigbee2mqtt-data
> mkdir mosquitto-data
> mkdir node-red-data
> ls /dev/serial/by-id -l
total 0
lrwxrwxrwx 1 root root 13 May  1 11:17 usb-dresden_elektronik_ConBee_III_DE03315010-if00-port0 -> ../../ttyUSB0
````

#### Container vorbereiten

Die letzte Zeile listet alle angeschlossenen seriellen interfaces. Hier sollte
der verwendete Adapter erscheinen. Wichtig dabei ist die Zuweisung zu einem
device (hier `ttyUSB0`). Dieses device muss dann in der Datei
`docker-compose.yaml` dem Container zugeordnet werden.

Die Datei `docker-compose.yaml` sollte dann den folgenden Inhalt haben.

````yaml
volumes:
  avahi-socket-dir: {}

services:
  mosquitto:
    image: eclipse-mosquitto:2.0
    container_name: mosquitto
    restart: unless-stopped
    volumes:
      - './mosquitto-data:/mosquitto'
    ports:
      - '1883:1883'
      - '9001:9001'
    command: 'mosquitto -c /mosquitto/mosquitto.conf'

  avahi:
    image: flungo/avahi
    container_name: avahi
    network_mode: host
    volumes:
      - "avahi-socket-dir:/var/run/avahi-daemon"
    environment:
      SERVER_USE_IPV6: "no"
      # Separation of responsibilities, this daemon is query-only. The hosts daemon publishes:
      PUBLISH_DISABLE_PUBLISHING: "yes"

  zigbee2mqtt:
    container_name: zigbee2mqtt
    image: ghcr.io/koenkk/zigbee2mqtt
    restart: unless-stopped
    volumes:
      - './zigbee2mqtt-data:/app/data'
      - '/run/udev:/run/udev:ro'
    ports:
      # Frontend port
      - 8080:8080
    environment:
      - TZ=Europe/Berlin
    devices:
      - /dev/ttyUSB0:/dev/ttyUSB0
    depends_on:
      - mosquitto

  node-red:
    image: nodered/node-red:latest
    container_name: node-red
    environment:
      - TZ=Europe/Berlin
    ports:
      - "1880:1880"
    volumes:
      - ./node-red-data:/data
      - "avahi-socket-dir:/var/run/avahi-daemon"
    depends_on:
      - avahi
      - mosquitto
    network_mode: host

````

#### Mosquitto konfigurieren

Zusätzlich muss die *Mosquitto* Konfigurationsdatei
`mosquitto-data/mosquitto.conf` den folgenden Inhalt bekommen.

````txt
allow_anonymous true

listener 1883
protocol mqtt
socket_domain ipv4

listener 9001
protocol websockets
socket_domain ipv4
````

#### zigbee2mqtt Konfigurieren

*zigbee2mqtt* wird in der Datei `zigbee2mqtt-data/configuration.yaml` wie folgt
konfiguriert:

````yaml
homeassistant:
  enabled: false
mqtt:
  base_topic: home
  server: mqtt://mosquitto:1883
serial:
  adapter: deconz
  port: /dev/ttyUSB0
  disable_led: true
  baudrate: 115200
advanced:
  cache_state: false
  log_level: info
frontend:
  enabled: true
  port: 8080
version: 4
````

Dabei muss der Inhalt der Sektion `serial` natürlich dem verwendeten Adapter
angepasst werden.

Auch empfiehlt es sich das Log-Level auf `warn` oder `error` zu stellen,
nachdem die Konfiguration läuft und nicht mehr gedebugt werden muss.

Der `server` Eintrag in der Sektion `mqtt` muss dabei den Namen des *Mosquitto*
Containers enthalten (Hier: `mosquitto`).

Die verbundenen Geräte trägt *zigbee2mqtt* dann, nachdem sie erfolgreich gepaart
wurden in der Sektion `devices` ein. `friendly-name` und auch eine Beschreibung
können im Frontend editiert werden. Das Zigbee2mqtt Frontend ist mit einem
Browser unter dem folgenden URL erreichbar:

````text
http://raspi.local:8080
````

#### Docker Container verwenden<a name="START"></a>

Die folgende Befehls Sequent beschreibt das starten der Container.

````bash
>cd homectrl
>docker compose up -d
````

Beim ersten Start werden die benötigten Container heruntergeladen. Das kann
einige Minuten dauern. Laufen alle benötigte Container, so stehen die Dienste
zur Verfügung. Es empfiehlt sich einen Blick in die Logs der Dienste zu werfen.

````bash
>docker compose logs
````

Die Container werden bei einem Neustart des Raspberry Pi automatisch wieder
gestartet. Sie können mit dem folgenden Kommando manuell gestoppt werden. 

````bash
>docker compose down
````

Sind die Container gestoppt, müssen sie wieder manuell gestartet werden (`docker
compose up -d`). Aus dem gestoppten Zustand werden sie auch beim Neustart des
Raspberry Pi nicht gestartet.

Ein Update aller verwendeten Container ist mit der folgenden Kommando Sequenz
einfach durchzuführen:

````bas
>cd ~/homectrl
>docker compose down
>docker compose pull
>docker compose up -d
````

_____
<small>Ende des Dokuments</small>
