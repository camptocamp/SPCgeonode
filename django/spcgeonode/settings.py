import os
from geonode.settings import *


##################################
# Basic config
##################################

ROOT_URLCONF = os.getenv('ROOT_URLCONF', 'spcgeonode.urls')

##################################
# Customization sample
##################################

# Install
ADDITIONNAL_INSTALLED_APPS = ('app_customization_sample','overextends',)

##################################
# Geonode Offline OSM
##################################

# Install
ADDITIONNAL_INSTALLED_APPS += ('geonode_offlineosm',)

# Config
# OFFLINE_OSM_UPDATE_INTERVAL = 5 # TODO : remove this
OFFLINE_OSM_DATA_DIR = '/spcgeonode-temp/urlretrieve/' # TODO : remove this ?
OFFLINE_OSM_UPDATE_AFTER_MIGRATE = True

# Celery tasks
CELERY_RESULT_BACKEND='djcelery.backends.database:DatabaseBackend'
CELERY_IMPORTS = CELERY_IMPORTS + ('geonode_offlineosm.tasks',)
CELERY_ALWAYS_EAGER = False
import djcelery
djcelery.setup_loader()

##################################
# Geonode Offline OSM
##################################

# Google satellite baselayer
MAP_BASELAYERS.append(
    {
        "source": {
            "ptype":"gxp_googlesource",
            "apiKey": 'AIzaSyCU29B1mM_p5vBnys6v9EuEUIKKMknecHQ'
            },
        "group":"background",
        "name":"SATELLITE",
        "visibility": False,
        "fixed": True,
    }
)

##################################
# Geoserver fix admin password
##################################

OGC_SERVER['default']['USER'] = open('/run/secrets/admin_username','r').read()
OGC_SERVER['default']['PASSWORD'] = open('/run/secrets/admin_password','r').read()


##################################
# Misc / debug / hack
##################################


# Add our additionnal installed apps
INSTALLED_APPS = INSTALLED_APPS + ADDITIONNAL_INSTALLED_APPS

# Can be removed after geonode>=2.7.x as it will be like this in main settings
ALLOWED_HOSTS = os.getenv('ALLOWED_HOSTS').split(',')

# Because of https://github.com/GeoNode/geonode/issues/3520 we need to manually add our templates/static folders so that they can override static files/templatest
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
for app in reversed(ADDITIONNAL_INSTALLED_APPS):
    tpl_dir = os.path.join(BASE_DIR, app,'templates')
    stc_dir = os.path.join(BASE_DIR, app,'static')
    if os.path.exists(tpl_dir):
        TEMPLATES[0]["DIRS"] = [tpl_dir] + TEMPLATES[0]["DIRS"]
    if os.path.exists(stc_dir):
        STATICFILES_DIRS = [stc_dir] + STATICFILES_DIRS
