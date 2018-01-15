#!/bin/bash

# Exit if there is an error
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# If script is executed as an unprivileged user
# Execute it as superuser, preserving environment variables
if [ $EUID != 0 ]; then
    sudo -E "$0" "$@"
    exit $?
fi

# If there is an .env file use it
# to set the variables
if [ -f $SCRIPT_DIR/.env ]; then
    source $SCRIPT_DIR/.env
fi

# Check all required variables are set
: "${DO_APIKEY:?must be set}"
: "${DO_DOMAIN:?must be set}"
: "${DO_EMAIL:?must be set}"

# Add elastic apt repo if it does not already exist
if [[ ! -f /etc/apt/sources.list.d/elastic-6.x.list ]]; then
    echo "deb https://artifacts.elastic.co/packages/6.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-6.x.list
fi

# Install required packages
/usr/bin/add-apt-repository -y ppa:certbot/certbot
/usr/bin/apt update -y
/usr/bin/apt install -y elasticsearch \
                        logstash \
                        kibana \
                        default-jre \
                        python-pip \
                        certbot

# Upgrade Python-Pip
/usr/local/bin/pip install --upgrade pip

# Get letsencrypt certificate
/usr/bin/certbot certonly --manual \
    -m ${DO_EMAIL} \
    --agree-tos \
    -n \
    --manual-public-ip-logging-ok \
    -d elk.lan.zeropingheroes.co.uk \
    --preferred-challenges dns \
    --manual-auth-hook lets-do-dns \
    --manual-cleanup-hook lets-do-dns

# Start the certbot timer (cron)
/bin/systemctl enable certbot.timer
/bin/systemctl start certbot.timer

# Load the new service file
/bin/systemctl daemon-reload

# Set services to start at boot
/bin/systemctl enable elasticsearch
/bin/systemctl enable logstash
/bin/systemctl enable kibana

# Start the services
/bin/systemctl start elasticsearch
/bin/systemctl start logstash
/bin/systemctl start kibana