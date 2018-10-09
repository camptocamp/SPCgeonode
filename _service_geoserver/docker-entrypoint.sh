#!/bin/sh

# Exit script in case of error
set -e

echo $"\n\n\n"
echo "-----------------------------------------------------"
echo "STARTING GEOSERVER ENTRYPOINT -----------------------"
date


############################
# 0. Defining BASEURL
############################

echo "-----------------------------------------------------"
echo "0. Defining BASEURL"

if [ ! -z "$HTTPS_HOST" ]; then
    BASEURL="https://$HTTPS_HOST"
    if [ "$HTTPS_PORT" != "443" ]; then
        BASEURL="$BASEURL:$HTTPS_PORT"
    fi
else
    BASEURL="http://$HTTP_HOST"
    if [ "$HTTP_PORT" != "80" ]; then
        BASEURL="$BASEURL:$HTTP_PORT"
    fi
fi

echo "BASEURL is $BASEURL"

GEONODE_INTERNAL_URL=${GEONODE_INTERNAL_URL:-http://nginx}
echo "GEONODE_INTERNAL_URL is $GEONODE_INTERNAL_URL"

############################
# 1. Initializing Geodatadir
############################

echo "-----------------------------------------------------"
echo "1. Initializing Geodatadir"

if [ "$(ls -A ${GEOSERVER_DATA_DIR})" ]; then
    echo 'Geodatadir not empty, skipping initialization...'
else
    echo 'Geodatadir empty, we run initialization...'
    cp -rf /data/* ${GEOSERVER_DATA_DIR}/
fi


############################
# 2. ADMIN ACCOUNT
############################

echo "-----------------------------------------------------"
echo "2. (Re)setting admin account"

ADMIN_USERNAME=${ADMIN_USERNAME:-$(cat /run/secrets/admin_username |  tr -d '[:space:]')}
ADMIN_PASSWORD=${ADMIN_PASSWORD:-$(cat /run/secrets/admin_password |  tr -d '[:space:]')}
ADMIN_ENCRYPTED_PASSWORD=$(/usr/lib/jvm/java-1.8-openjdk/jre/bin/java -classpath $GEOSERVER_HOME/webapps/geoserver/WEB-INF/lib/jasypt-1.9.2.jar org.jasypt.intf.cli.JasyptStringDigestCLI digest.sh algorithm=SHA-256 saltSizeBytes=16 iterations=100000 input="$ADMIN_PASSWORD" verbose=0 | tr -d '\n')
sed -i -r "s|<user enabled=\".*\" name=\".*\" password=\".*\"/>|<user enabled=\"true\" name=\"$ADMIN_USERNAME\" password=\"digest1:$ADMIN_ENCRYPTED_PASSWORD\"/>|" "${GEOSERVER_DATA_DIR}/security/usergroup/default/users.xml"
# TODO : more selective regexp for this one as there may be several users...
sed -i -r "s|<userRoles username=\".*\">|<userRoles username=\"$ADMIN_USERNAME\">|" "${GEOSERVER_DATA_DIR}/security/role/default/roles.xml"
ADMIN_USERNAME=""
ADMIN_PASSWORD=""
ADMIN_ENCRYPTED_PASSWORD=""


############################
# 3. OAUTH2 CONFIGURATION
############################

echo "-----------------------------------------------------"
echo "3. (Re)setting OAuth2 Configuration"

# Wait for database
until psql -h ${GEOSERVER_DB_HOST} -U ${GEOSERVER_DB_USER} -c "select 1" > /dev/null 2>&1 ; do
    echo "Waiting for database..."
    sleep 1
  done

# Edit ${GEOSERVER_DATA_DIR}/security/filter/geonode-oauth2/config.xml

# Getting oauth keys and secrets from the database
while true; do
  CLIENT_ID=$(psql -h ${GEOSERVER_DB_HOST} -U ${GEOSERVER_DB_USER} -c "SELECT client_id FROM oauth2_provider_application WHERE name='GeoServer'" -t | tr -d '[:space:]')
  CLIENT_SECRET=$(psql -h ${GEOSERVER_DB_HOST} -U ${GEOSERVER_DB_USER} -c "SELECT client_secret FROM oauth2_provider_application WHERE name='GeoServer'" -t | tr -d '[:space:]')
  if [ -z "$CLIENT_ID" ] || [ -z "$CLIENT_SECRET" ]; then
      echo "Waiting for database to be populated by django service..."
      sleep 1
    else
      break
  fi
done

if [ -f "${GEOSERVER_DATA_DIR}/security/filter/geonode-oauth2/config.xml" ]
then
    sed -i -r "s|<cliendId>.*</cliendId>|<cliendId>$CLIENT_ID</cliendId>|" "${GEOSERVER_DATA_DIR}/security/filter/geonode-oauth2/config.xml"
    sed -i -r "s|<clientSecret>.*</clientSecret>|<clientSecret>$CLIENT_SECRET</clientSecret>|" "${GEOSERVER_DATA_DIR}/security/filter/geonode-oauth2/config.xml"
    # OAuth endpoints (client)
    sed -i -r "s|<userAuthorizationUri>.*</userAuthorizationUri>|<userAuthorizationUri>$BASEURL/o/authorize/</userAuthorizationUri>|" "${GEOSERVER_DATA_DIR}/security/filter/geonode-oauth2/config.xml"
    sed -i -r "s|<redirectUri>.*</redirectUri>|<redirectUri>$BASEURL/geoserver/index.html</redirectUri>|" "${GEOSERVER_DATA_DIR}/security/filter/geonode-oauth2/config.xml"
    sed -i -r "s|<logoutUri>.*</logoutUri>|<logoutUri>$BASEURL/account/logout/</logoutUri>|" "${GEOSERVER_DATA_DIR}/security/filter/geonode-oauth2/config.xml"
    # OAuth endpoints (server)
    sed -i -r "s|<accessTokenUri>.*</accessTokenUri>|<accessTokenUri>${GEONODE_INTERNAL_URL}/o/token/</accessTokenUri>|" "${GEOSERVER_DATA_DIR}/security/filter/geonode-oauth2/config.xml"
    sed -i -r "s|<checkTokenEndpointUrl>.*</checkTokenEndpointUrl>|<checkTokenEndpointUrl>${GEONODE_INTERNAL_URL}/api/o/v4/tokeninfo/</checkTokenEndpointUrl>|" "${GEOSERVER_DATA_DIR}/security/filter/geonode-oauth2/config.xml"
fi

# Edit /security/role/geonode REST role service/config.xml
if [ -f "${GEOSERVER_DATA_DIR}/security/role/geonode REST role service/config.xml" ]
then
    sed -i -r "s|<baseUrl>.*</baseUrl>|<baseUrl>${GEONODE_INTERNAL_URL}</baseUrl>|" "${GEOSERVER_DATA_DIR}/security/role/geonode REST role service/config.xml"
fi

CLIENT_ID=""
CLIENT_SECRET=""


############################
# 3. RE(SETTING) BASE URL
############################

echo "-----------------------------------------------------"
echo "4. (Re)setting Baseurl"

sed -i -r "s|<proxyBaseUrl>.*</proxyBaseUrl>|<proxyBaseUrl>$BASEURL</proxyBaseUrl>|" "${GEOSERVER_DATA_DIR}/global.xml"



echo "-----------------------------------------------------"
echo "FINISHED GEOSERVER ENTRYPOINT -----------------------"
echo "-----------------------------------------------------"

# Run the CMD
exec "$@"
