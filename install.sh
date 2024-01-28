#!/bin/bash

############################################################################
# Enshrouded Dedicated Server for Ubuntu Server 22.04 LTS                  #
# Written by PR3SIDENT, TripodGG, and WarderKeeju                          #
# This is a Bash script covered by the GNU General Public License (GPL)    #
# Version 3.0, or any later version.                                       #
# To view a copy of the GPL, see <https://www.gnu.org/licenses/gpl.html>   #
# There are no guarantees attached to this script. Functionality has been  #
# tested as thoroughly as possible, but we cannot guarantee it will work   #
############################################################################

###################
# sudo user check #
###################

# Make sure only root can run the script
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run using sudo. Please run the script again with sudo privileges." 1>&2
   exit 1
fi

########################
# Install dependencies #
########################

# Switch to non-interactive mode (system will not ask for any confirmations)
export DEBIAN_FRONTEND "noninteractive"

# Enable 'debug mode'. this will print every command as output
set +x

# Add the multiverse repo (where steam cmd package is located)
add-apt-repository -y multiverse

# Update package list from repo
apt update -y

# Install basics packages without confirmation
apt install -y vim wget software-properties-common

# Install standard dependencies
dpkg --add-architecture i386; sudo apt update; sudo apt install curl wget file tar bzip2 gzip unzip bsdmainutils python3 util-linux ca-certificates binutils bc jq tmux netcat lib32gcc1 lib32stdc++6 libsdl2-2.0-0:i386 steamcmd telnet expect libxml2-utils -y 

# Automatic answer to the questions during steam install
echo steam steam/question select "I AGREE" | debconf-set-selections && echo steam steam/license note '' | debconf-set-selections

# Install without prompting the libraries for steamcmd & steamcmd itself
apt install -y lib32z1 lib32gcc-s1

#####################
# Server user check #
#####################

# Prompt for the username of the user that will run the server and check that the user exists before continuing
check_user_name () {
        grep -c $1: /etc/passwd
}

read -p "What user will run the server? (this should NOT be root) " ENSHROUDED_USER_NAME

if ! check_user_name $ENSHROUDED_USER_NAME -eq 0
then
        echo "User does not exist. Please create a user and run the script again.  Exiting..."
        exit
else
        echo "User exists. Setting $ENSHROUDED_USER_NAME as the server user."
fi

# Change owner of steamcmd sh folder to the user
chown -R $ENSHROUDED_USER_NAME /usr/games

################
# Wine install #
################

# Change architecture instructions to 64bits
dpkg --add-architecture amd64

# Create the local folder who will contain the repos keys
mkdir -pm755 /etc/apt/keyrings

# Add the repo key
wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key

# Add the repo
wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/jammy/winehq-jammy.sources

# Again update packages list
apt update -y

# Install wine
apt install -y --install-recommends winehq-staging

# Install the needed packages to make wine work
apt install -y --allow-unauthenticated cabextract winbind screen xvfb

# Get winetricks
wget -O /usr/local/bin/winetricks https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks

# Make .sh executable
chmod +x /usr/local/bin/winetricks

# Create the init script of whinetricks
touch /home/$ENSHROUDED_USER_NAME/winetricks.sh

# Write the contents of the script file
cat << EOF >> /home/$ENSHROUDED_USER_NAME/winetricks.sh
#!/bin/bash
export DISPLAY=:1.0
Xvfb :1 -screen 0 1024x768x16 &
env WINEDLLOVERRIDES="mscoree=d" wineboot --init /nogui
winetricks corefonts
winetricks sound=disabled
winetricks -q --force vcrun2022
wine winecfg -v win10
rm -rf /home/$ENSHROUDED_USER_NAME/.cache
EOF

# Make it executable
chmod +x /home/$ENSHROUDED_USER_NAME/winetricks.sh

# Create Wineprefix directory
mkdir /home/$ENSHROUDED_USER_NAME/.enshrouded_prefix

# Change owner of winetricks.sh and .enshrouded_prefix folder to the specified user
chown -R $ENSHROUDED_USER_NAME /home/$ENSHROUDED_USER_NAME/winetricks.sh
chown -R $ENSHROUDED_USER_NAME /home/$ENSHROUDED_USER_NAME/.enshrouded_prefix

########################
# Game Server  section #
########################

# Create enshrouded directories
mkdir -p /home/$ENSHROUDED_USER_NAME/serverfiles
mkdir -p /home/$ENSHROUDED_USER_NAME/serverfiles/savegame
mkdir -p /home/$ENSHROUDED_USER_NAME/serverfiles/logs

# Create symlink to steamcmd in enserver home directory
ln -s /usr/games/steamcmd /home/$ENSHROUDED_USER_NAME/serverfiles/steamcmd

# Execute steam update
su enserver -c "/home/$ENSHROUDED_USER_NAME/serverfiles/steamcmd +quit"

# Ask for values of the server name, password, number of players
read -p "What is the name of Enshrouded server ?" ENSHROUDED_SERVER_NAME
read -p "What is the password of Enshrouded server ?" ENSHROUDED_SERVER_PASSWORD
read -p "What is the player limit of Enshrouded server (max is 16) ?" ENSHROUDED_SERVER_MAXPLAYERS

# Create config file
touch /home/$ENSHROUDED_USER_NAME/serverfiles/enshrouded_server.json

# Write the configuration
cat << EOF >> /home/$ENSHROUDED_USER_NAME/serverfiles/enshrouded_server.json
{

    "name": "$(echo $ENSHROUDED_SERVER_NAME)",

    "password": "$(echo $ENSHROUDED_SERVER_PASSWORD)",

    "saveDirectory": "./savegame",

    "logDirectory": "./logs",

    "ip": "0.0.0.0",

    "gamePort": 15636,

    "queryPort": 15637,

    "slotCount": $(echo $ENSHROUDED_SERVER_MAXPLAYERS)

}
EOF

# Install server
/home/$ENSHROUDED_USER_NAME/serverfiles/steamcmd -c "+force_install_dir /home/$ENSHROUDED_USER_NAME/serverfiles +login anonymous +app_update 2278520 +quit"

##########################
# Create service section #
##########################

# Create service script
touch /home/$ENSHROUDED_USER_NAME/serverfiles/StartEnshroudedServer.sh

# Write the startupscript
cat << EOF >> /home/$ENSHROUDED_USER_NAME/serverfiles/StartEnshroudedServer.sh
#!/bin/sh
export WINEARCH=win64
#export WINEPREFIX=/home/$ENSHROUDED_USER_NAME/.enshrouded_prefix
#export WINEDEBUG=-all
wine64 /home/$ENSHROUDED_USER_NAME/serverfiles/enshrouded_server.exe
EOF

# Make it exectutable
chmod +x /home/$ENSHROUDED_USER_NAME/serverfiles/StartEnshroudedServer.sh

# Change owner of serverfiles folder to the specified user
chown -R $ENSHROUDED_USER_NAME /home/$ENSHROUDED_USER_NAME/serverfiles

# Create the service file
touch /etc/systemd/system/enshrouded.service

# Write the contents of the file
cat << EOF >> /etc/systemd/system/enshrouded.service
[Unit]
Description=Enshrouded Server
After=syslog.target network-online.target

[Service]
ExecStart=/home/$ENSHROUDED_USER_NAME/serverfiles/StartEnshroudedServer.sh
KillSignal=SIGINT
User=enserver
Type=forking
Restart=on-failure
RestartSec=50s

[Install]
WantedBy=multi-user.target
EOF

# Restart Services
systemctl daemon-reload

# Enable Enshrouded Service
systemctl enable enshrouded.service

# Start Enshrouded service
systemctl start enshrouded.service
