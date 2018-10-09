import os, hashlib
from geonode.settings import *


##################################
# Basic config
##################################

ROOT_URLCONF = os.getenv('ROOT_URLCONF', 'spcgeonode.urls')

##################################
# Geoserver fix admin password
##################################

admin_username = os.environ['ADMIN_USERNAME'] if 'ADMIN_USERNAME' in os.environ else open('/run/secrets/admin_username','r').read().strip()
admin_password = os.environ['ADMIN_PASSWORD'] if 'ADMIN_PASSWORD' in os.environ else open('/run/secrets/admin_password','r').read().strip()
OGC_SERVER['default']['USER'] = admin_username
OGC_SERVER['default']['PASSWORD'] = admin_password

##################################
# Misc / debug / hack
##################################

# Celery
INSTALLED_APPS += ('django_celery_monitor','django_celery_results',) # TODO : add django-celery-monitor to core geonode
CELERY_TASK_ALWAYS_EAGER = False
CELERY_TASK_IGNORE_RESULT = False
CELERY_BROKER_URL = os.environ.get('BROKER_URL', 'amqp://rabbitmq:5672')
CELERY_RESULT_BACKEND = 'django-db'

# We randomize the secret key (based on admin login)
SECRET_KEY = hashlib.sha512(admin_username + admin_password).hexdigest()

# We define ALLOWED_HOSTS
ALLOWED_HOSTS = ['nginx','127.0.0.1'] # We need this for internal api calls from geoserver and for healthchecks
if os.getenv('HTTPS_HOST'):
    ALLOWED_HOSTS.append( os.getenv('HTTPS_HOST') )
if os.getenv('HTTP_HOST'):
    ALLOWED_HOSTS.append( os.getenv('HTTP_HOST') )

# We define SITE_URL
if os.getenv('HTTPS_HOST'):
    SITEURL = 'https://{url}{port}/'.format(
        url=os.getenv('HTTPS_HOST'),
        port=':'+os.getenv('HTTPS_PORT') if os.getenv('HTTPS_PORT') != '443' else '',
    )
elif os.getenv('HTTP_HOST'):
    SITEURL = 'http://{url}{port}/'.format(
        url=os.getenv('HTTP_HOST'),
        port=':'+os.getenv('HTTP_PORT') if os.getenv('HTTP_PORT') != '80' else '',
    )
else:
    raise Exception("Misconfiguration error. You need to set at least one of HTTPS_HOST or HTTP_HOST")

# Manually replace SITEURL whereever it is used in geonode's settings.py (those settings are a mess...)
GEOSERVER_LOCATION = os.environ.get('GEOSERVER_BASE_URL', 'http://geoserver:8080/geoserver/')
GEOSERVER_PUBLIC_LOCATION = SITEURL + 'geoserver/'
GEOSERVER_URL = GEOSERVER_PUBLIC_LOCATION
OGC_SERVER['default']['LOCATION'] = GEOSERVER_LOCATION
OGC_SERVER['default']['PUBLIC_LOCATION'] = GEOSERVER_PUBLIC_LOCATION
CATALOGUE['default']['URL'] = '%scatalogue/csw' % SITEURL
PYCSW['CONFIGURATION']['metadata:main']['provider_url'] = SITEURL
PUBLIC_GEOSERVER["source"]["url"] = GEOSERVER_PUBLIC_LOCATION + "ows"


# We set our custom geoserver password hashers
# TODO : remove this (we'll leave it for some time so that hashes using GeoserverDigestPasswordHasher are rehashed)
PASSWORD_HASHERS = (
    'django.contrib.auth.hashers.PBKDF2PasswordHasher',
    'django.contrib.auth.hashers.PBKDF2SHA1PasswordHasher',
    'django.contrib.auth.hashers.BCryptSHA256PasswordHasher',
    'django.contrib.auth.hashers.BCryptPasswordHasher',
    'django.contrib.auth.hashers.SHA1PasswordHasher',
    'django.contrib.auth.hashers.MD5PasswordHasher',
    'django.contrib.auth.hashers.CryptPasswordHasher',
    'spcgeonode.hashers.GeoserverDigestPasswordHasher',
    'spcgeonode.hashers.GeoserverPlainPasswordHasher',
)
