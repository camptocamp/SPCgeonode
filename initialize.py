"""
This script initializes Geonode
"""

#########################################################
# Setting up the  context
#########################################################

import os, requests, json, uuid, django, time
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'spcgeonode.settings')
django.setup()


#########################################################
# Imports
#########################################################

from django.core.management import call_command
from geonode.people.models import Profile
from oauth2_provider.models import Application
from django.conf import settings
from django.db.utils import OperationalError

# Getting the secrets
admin_username = os.environ['ADMIN_USERNAME'] if 'ADMIN_USERNAME' in os.environ else open('/run/secrets/admin_username','r').read().strip()
admin_password = os.environ['ADMIN_USERNAME'] if 'ADMIN_PASSWORD' in os.environ else open('/run/secrets/admin_password','r').read().strip()

# Some configs:
GEOSERVER_INTERNAL_URL = os.environ.get('GEOSERVER_BASE_URL', 'http://geoserver:8080/geoserver/')
HOST = os.environ.get('HTTPS_HOST', os.environ.get('HTTP_HOST'))
PROTOCOL = 'https' if os.getenv('HTTPS_HOST', "") else 'http'
GEOSERVER_PUBLIC_URL = os.environ.get(
    'GEOSERVER_PUBLIC_URL',
    '{}://{}/geoserver/'.format(PROTOCOL, HOST))

#########################################################
# 1. Running the migrations
#########################################################

print("-----------------------------------------------------")
print("1. Running the migrations")
while True:
    try:
        call_command('migrate', '--noinput')
        break
    except OperationalError:
        print("Waiting for database")
        time.sleep(1)
        pass


#########################################################
# 2. Creating superuser if it doesn't exist
#########################################################

print("-----------------------------------------------------")
print("2. Creating/updating superuser")
try:
    superuser = Profile.objects.create_superuser(
        admin_username,
        os.getenv('ADMIN_EMAIL', ''),
        admin_password
    )
    print('superuser successfully created')
except django.db.IntegrityError as e:
    superuser = Profile.objects.get(username=admin_username)
    superuser.set_password(admin_password)
    superuser.is_active = True
    superuser.email = os.getenv('ADMIN_EMAIL')
    superuser.save()
    print('superuser successfully updated')


#########################################################
# 3. Create an OAuth2 provider to use authorisations keys
#########################################################

print("-----------------------------------------------------")
print("3. Create/update an OAuth2 provider to use authorisations keys")
app, created = Application.objects.get_or_create(
    pk=1,
    name='GeoServer',
    client_type='confidential',
    authorization_grant_type='authorization-code'
)
redirect_uris = [
    GEOSERVER_PUBLIC_URL.rstrip('/'),
    GEOSERVER_PUBLIC_URL + 'index.html'
]
app.redirect_uris = "\n".join(redirect_uris)
app.save()
if created:
    print('oauth2 provider successfully created')
else:
    print('oauth2 provider successfully updated')


#########################################################
# 4. Loading fixtures
#########################################################

print("-----------------------------------------------------")
print("4. Loading fixtures")
call_command('loaddata', 'initial_data')


#########################################################
# 5. Running updatemaplayerip
#########################################################

print("-----------------------------------------------------")
print("5. Running updatemaplayerip")
# call_command('updatelayers') # TODO CRITICAL : this overrides the layer thumbnail of existing layers even if unchanged !!!
call_command('updatemaplayerip')


#########################################################
# 6. Collecting static files
#########################################################

print("-----------------------------------------------------")
print("6. Collecting static files")
call_command('collectstatic', '--noinput')


#########################################################
# 7. Securing GeoServer
#########################################################

print("-----------------------------------------------------")
print("7. Securing GeoServer")

# Getting the old password
while True:
    try:
        r1 = requests.get(GEOSERVER_INTERNAL_URL + 'rest/security/masterpw.json', auth=(admin_username, admin_password))
        break
    except requests.exceptions.ConnectionError as e:
        print("Waiting for geoserver...")
        time.sleep(1)
r1.raise_for_status()
old_password = json.loads(r1.text)["oldMasterPassword"]

if old_password=='M(cqp{V1':
    print("Randomizing master password")
    new_password = uuid.uuid4().hex
    data = json.dumps({"oldMasterPassword":old_password,"newMasterPassword":new_password})
    r2 = requests.put(GEOSERVER_INTERNAL_URL + 'rest/security/masterpw.json', data=data, headers={'Content-Type': 'application/json'}, auth=(admin_username, admin_password))
    r2.raise_for_status()
else:
    print("Master password was already changed. No changes made.")
