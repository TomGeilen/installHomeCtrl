#!/bin/bash
clear
timeout=15
defaultFolder="homectrl"
defaultTopic="home"
defaultNodeRed="yes"

isVersionLowerEqual() {
    [  "$1" = "`echo -e "$1\n$2" | sort -V | head -n1`" ]
}

echo "############################################################"
echo "#          Install Home Control using Docker               #"
echo "#                                                          #"
echo "# A timeout of ${timeout} s is used whenever the user is prompted  #"
echo "# for input.                                               #"
echo "# In case you want to use the default values               #"
echo "#         Directory : '${defaultFolder}'                           #"
echo "#   MQTT base topic : '${defaultTopic}'                               #"
echo "# Node-Red included : '${defaultNodeRed}'                                #"
echo "# Just sit back and wait.                                  #"
echo "#                                                          #"
echo "#  Author: tom.geilen@me.com                               #"
echo "# Version: 0.2.4                                           #"
echo "#    Date: 14.Jun.2025                                     #"
echo "############################################################"
echo -n "Detecting hardware & software..."
if [ -d /dev/serial ]; then
   output="$(ls /dev/serial/by-id -l | grep -o 'ConBee_II_')"
   if [ "${output}" == "ConBee_II_" ]; then
      device="ConBeeII"
      adapter="deconz"
   else
      output="$(ls /dev/serial/by-id -l | grep -o 'ConBee_III_')"
      if [ "${output}" == "ConBee_III_" ]; then
         device="ConBeeIII"
         adapter="deconz"
      fi
   fi
fi
echo ".......................... ✓"

if [ "${device}" == "" ]; then
   echo "No supported hardware detected."
   echo "Do you want to continue with the installation anyway?"
   read -t ${timeout} -p "(default: 'no') -->" key
   if [ "${key}" == "" ]; then
      echo "";
   fi
   if [ "${key}" != "yes" ]; then
      echo "Script terminated."
      echo "OUT"
      exit -1
   fi
else
   port="$(ls /dev/serial/by-id -l | grep -o '\.\.\/\.\.\/.*')"
   port=${port:6}
   echo "Detected hardware: ${device}"
   echo "     Connected to: /dev/${port}"
fi

version="$(docker --version | grep -o '[0-9]*\.[0-9]*\.[0-9]*')"
if [ "${version}" == "" ]; then
   echo -n "Retrieving installation script from 'docker.com'..."
   curl -fsSL https://get.Docker.com -o getDocker.sh
   echo "....... ✓"
   echo "Running the Docker installation script..."
   sudo sh getDocker.sh > /dev/null
   docker --version
   echo -n "Deleting installation script..."
   rm getDocker.sh
   echo "........................... ✓"
else
   echo -n "           Docker: v${version}"
   composeLimit="17.04.0"
   isVersionLowerEqual "${version}" "${composeLimit}"
   if [ $? -eq 0 ]; then
      printf "\nDocker version is lower than ${composeLimit}. It does not support\n"
      echo "'docker compose'. Please remove this Docker version before"
      echo "running this script."
      echo "OUT"
      exit -3
   else
      echo " ✓"
   fi
fi
echo -n "Add user '$USER' to group 'docker'..."
sudo usermod -aG docker $USER
echo "........................ ✓"
echo "Directory name (default: '${defaultFolder}')"
read -t ${timeout} -p "-->" folder
if [ "$folder" == "" ]; then
    folder="${defaultFolder}"
    echo ""
fi
if [ -d $folder ]; then
   echo "Directory '${folder}' already exists."
   echo "Shall it's content be overwritten? (completely)"
   read -p "-->" key
   if [ "${key}" == "yes" ]; then
      echo -n "Deleting existing directory '${folder}'..."
      sudo rm -r "${folder}"
      echo "................. ✓"
   else
      echo "Script terminated"
      echo "OUT"
      exit -2
   fi
fi
echo -n "Creating directory '${folder}'..."
mkdir "$folder"
echo ".......................... ✓"
echo -n "Creating directory 'mosquitto-data'......"
mkdir ${folder}/mosquitto-data
echo "................. ✓"
mosquitto="mosquitto-data/mosquitto.conf"
echo -n "Creating file '$mosquitto'..."
mosquitto="${folder}/${mosquitto}"
printf "allow_anonymous true\n\n" >> ${mosquitto}
printf "listener 1883\n" >> ${mosquitto}
printf "protocol mqtt\n" >> ${mosquitto}
printf "socket_domain ipv4\n\n" >> ${mosquitto}
printf "listener 9001\n" >> ${mosquitto}
printf "protocol websockets\n" >> ${mosquitto}
printf "socket_domain ipv4\n" >> ${mosquitto}
echo ".......... ✓"
echo -n "Creating directory 'zigbee2mqtt-data'..."
mkdir ${folder}/zigbee2mqtt-data
echo ".................. ✓"
zigbee="zigbee2mqtt-data/configuration.yaml"
echo "Base topic (default: '$defaultTopic')"
read -t ${timeout} -p "-->" topic
if [ "$topic" == "" ]; then
    topic="${defaultTopic}"
    echo ""
fi
echo -n "Creating file '$zigbee'..."
zigbee="${folder}/${zigbee}"
printf "homeassistant:\n" >> ${zigbee}
printf "  enabled: false\n" >> ${zigbee}
printf "mqtt:\n" >> ${zigbee}
printf "  base_topic: ${topic}\n" >> ${zigbee}
printf "  server: mqtt://mosquitto:1883\n" >> ${zigbee}
printf "serial:\n" >> ${zigbee}
printf "  adapter: ${adapter}\n" >> ${zigbee}
printf "  port: /dev/ttyUSB0\n" >> ${zigbee}
printf "  disable_led: true\n" >> ${zigbee}
if [ "${device}" == "ConBeeIII" ]; then
   printf "  baud_rate: 115200\n" >> ${zigbee}
fi
printf "advanced:\n" >> ${zigbee}
printf "  cache_state: false\n" >> ${zigbee}
printf "  log_level: info\n" >> ${zigbee}
printf "frontend:\n" >> ${zigbee}
printf "  enabled: true\n" >> ${zigbee}
printf "  port: 8080\n" >> ${zigbee}
printf "version: 4\n" >> ${zigbee}
echo ".... ✓"
echo "Is node-red required? (default: '$defaultNodeRed')"
read -t ${timeout} -p "-->" node
if [ "${node}" == "" ]; then
   node="${defaultNodeRed}"
   echo ""
fi
if [ "${node}" == "yes" ]; then
    echo -n "Creating 'node-red-data' directory..."
    mkdir ${folder}/node-red-data
    echo "..................... ✓"
fi
compose="compose.yaml"
echo -n "Creating file '$compose'..."
compose="${folder}/${compose}"
if [ "${node}" == "yes" ]; then
    printf "volumes:\n" ] >> ${compose}
    printf "  avahi-socket-dir: {}\n\n" >> ${compose}
fi
printf "services:\n" >> ${compose}
printf "  mosquitto:\n" >> ${compose}
printf "    image: eclipse-mosquitto:2.0\n" >> ${compose}
printf "    container_name: mosquitto\n" >> ${compose}
printf "    restart: unless-stopped\n" >> ${compose}
printf "    volumes:\n" >> ${compose}
printf "      - './mosquitto-data:/mosquitto'\n" >> ${compose}
printf "    ports:\n" >> ${compose}
printf "      - '1883:1883'\n" >> ${compose}
printf "      - '9001:9001'\n" >> ${compose}
printf "    command: 'mosquitto -c /mosquitto/mosquitto.conf'\n\n" >> ${compose}
printf "  zigbee2mqtt:\n" >> ${compose}
printf "    container_name: zigbee2mqtt\n" >> ${compose}
printf "    image: ghcr.io/koenkk/zigbee2mqtt\n" >> ${compose}
printf "    restart: unless-stopped\n" >> ${compose}
printf "    volumes:\n" >> ${compose}
printf "      - './zigbee2mqtt-data:/app/data'\n" >> ${compose}
printf "      - '/run/udev:/run/udev:ro'\n" >> ${compose}
printf "    ports:\n" >> ${compose}
printf "      - 8080:8080\n" >> ${compose}
printf "    environment:\n" >> ${compose}
printf "      - TZ=Europe/Berlin\n" >> ${compose}
printf "    devices:\n" >> ${compose}
printf "      # Make sure this matches your adaper location\n" >> ${compose}
printf "      - /dev/${port}:/dev/ttyUSB0\n" >> ${compose}
printf "    depends_on:\n" >> ${compose}
printf "      - mosquitto\n" >> ${compose}
if [ $node == "yes" ]; then
   printf "\n  avahi:\n" >> ${compose}
   printf "    image: flungo/avahi\n" >> ${compose}
   printf "    container_name: avahi\n" >> ${compose}
   printf "    network_mode: host\n" >> ${compose}
   printf "    volumes:\n" >> ${compose}
   printf "      - 'avahi-socket-dir:/var/run/avahi-daemon'\n" >> ${compose}
   printf "    environment:\n" >> ${compose}
   printf "      SERVER_USE_IPV6: 'no'\n" >> ${compose}
   printf "      PUBLISH_DISABLE_PUBLISHING: 'yes'\n\n" >> ${compose}
   printf "  node-red:\n" >> ${compose}
   printf "    image: nodered/node-red:latest\n" >> ${compose}
   printf "    container_name: node-red\n" >> ${compose}
   printf "    environment:\n" >> ${compose}
   printf "      - TZ=Europe/Berlin\n" >> ${compose}
   printf "    ports:\n" >> ${compose}
   printf "      - '1880:1880'\n" >> ${compose}
   printf "    volumes:\n" >> ${compose}
   printf "      - ./node-red-data:/data\n" >> ${compose}
   printf "      - avahi-socket-dir:/var/run/avahi-daemon\n" >> ${compose}
   printf "    depends_on:\n" >> ${compose}
   printf "      - avahi\n" >> ${compose}
   printf "      - mosquitto\n" >> ${compose}
   printf "    network_mode: host\n" >> ${compose}
fi
echo ".......................... ✓"
echo "############################################################"
echo "# All necessary directories and files have been created.   #"
echo "# Please reboot the Raspberry Pi now using the following   #"
echo "# command:                                                 #"
echo "#    >sudo reboot now                                      #"
echo "#                                                          #"
echo "# After the reboot you can start the container using the   #"
echo "# commands:                                                #"
echo "#    >cd ${folder}                                          #"
echo "#    >docker compose up -d                                 #"
echo "#                                                          #"
echo "# The container will automatically start, whenever the     #"
echo "# Raspberry Pi is rebooted. You can stop it using.         #"
echo "#    >docker compose down                                  #"
echo "# To see the container's logs, please enter                #"
echo "#    >docker compose logs                                  #"
echo "#                                                          #"
echo "# (Always change to the containers directory ('${folder}')  #"
echo "# before using these commands.)                            #"
echo "############################################################"
echo "OUT"
