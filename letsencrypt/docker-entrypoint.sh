#!/bin/sh

# Exit script in case of error
set -e

##########################################
# LAN setup
##########################################

printf "\n\nSetting up autoissued certificates for LAN Host ($LAN_HOST)\n"

if [ ! -f "/spcgeonode-certbot/autoissued/$LAN_HOST/key" ] || [ ! -f "/spcgeonode-certbot/autoissued/$LAN_HOST/cert" ]; then

    printf "\nNo existing certificates found... Creating autoissued certificates...\n"

    mkdir -p "/spcgeonode-certbot/autoissued/$LAN_HOST/"
    openssl req -x509 -nodes -days 395 -newkey rsa:2048 -keyout "/spcgeonode-certbot/autoissued/$LAN_HOST/privkey.pem" -out "/spcgeonode-certbot/autoissued/$LAN_HOST/fullchain.pem" -subj "/CN=$LAN_HOST" 

else

    printf "\nExisting certificates found. We leave them in place as they will be updated by cron eventually.\n"

fi


##########################################
# WAN setup
##########################################

printf "\n\nSetting up certificates for WAN Host ($WAN_HOST)\n"


printf "\nGetting the certificates\n"

# We cleanup previously the certificate if it was a placeholder not created by certbot
if [ -f "/spcgeonode-certbot/live/$WAN_HOST/placeholder_flag" ]; then
    printf "\nDeleting previously create placeholder certificate\n"
    rm -rf /spcgeonode-certbot/live/$WAN_HOST/
fi

# We run the command
set +e # do not exist on fail

printf "\nLETSENCRYPT_MODE=$LETSENCRYPT_MODE\n"
if [ "$LETSENCRYPT_MODE" == "disabled" ]; then
    printf "Simulating failure\n"
    /bin/false
elif [ "$LETSENCRYPT_MODE" == "staging" ]; then
    printf "Trying to get staging certificates...\n"
    certbot --config-dir /spcgeonode-certbot/ certonly --webroot -w /spcgeonode-certbot/ -d "$WAN_HOST" -m "$ADMIN_EMAIL" --agree-tos --non-interactive --staging
else
    printf "Trying to get the real certificate...\n"
    certbot --config-dir /spcgeonode-certbot/ certonly --webroot -w /spcgeonode-certbot/ -d "$WAN_HOST" -m "$ADMIN_EMAIL" --agree-tos --non-interactive
fi

if [ ! $? -eq 0 ]; then
    printf "\nFailed to get the certificates !\nSee /var/log/letsencrypt/letsencrypt.log :\n\n\n"
    cat /var/log/letsencrypt/letsencrypt.log 
    
    printf "\n\n\nWe create a placeholder certificate\n"
    
    mkdir -p "/spcgeonode-certbot/live/$WAN_HOST/"
    openssl req -x509 -nodes -days 1 -newkey rsa:2048 -keyout "/spcgeonode-certbot/live/$WAN_HOST/privkey.pem" -out "/spcgeonode-certbot/live/$WAN_HOST/fullchain.pem" -subj "/CN=PLACEHOLDER"
    echo "This certificate was not generated by certbot. It must be deleted before running renewal by certbot, else renewal will fail." > "/spcgeonode-certbot/live/$WAN_HOST/placeholder_flag"

    printf "\nWaiting 30s to avoid hitting Letsencrypt rate limits if restarting in case of failure\n"
    sleep 30

    exit 1
fi
set -e # back to normal

printf "\nTesting autorenew\n"
certbot --config-dir /spcgeonode-certbot/ renew --dry-run


##########################################
# Cron jobs
##########################################

printf "\n\nInstalling cronjobs\n"
# TODO : move this to an external file
# notes : first one is letsencrypt (we run it twice a day), second one is autoissued (we renew every year, as it's duration is 365 days + 30 days)
( echo "0 0,12 * * * date && certbot renew" ; echo "0 0 1 1 * date && openssl req -x509 -nodes -days 395 -newkey rsa:2048 -keyout /spcgeonode-certbot/autoissued/$LAN_HOST/privkey.pem -out /spcgeonode-certbot/autoissued/$LAN_HOST/fullchain.pem -subj \"/CN=$LAN_HOST\"") | /usr/bin/crontab -
# We print the crontab just for debugging purposes
/usr/bin/crontab -l

# Run the CMD 
exec "$@"
