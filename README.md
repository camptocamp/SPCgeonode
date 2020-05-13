# SPCgeonode [![Build Status](https://travis-ci.org/tonio/SPCgeonode.svg?branch=gfdrr)](https://travis-ci.org/tonio/SPCgeonode)

## Prerequisites

Make sure you have a version of Docker (tested with 17.12) and docker-compose.

```
# Checkout the source
git clone -b gfdrr https://github.com/tonio/SPCgeonode.git
```

## Usage

### Development

To start the whole stack
```
docker-compose up --build -d
```

Once everything started, you should be able to open http://127.0.0.1 in your browser.

### Production (using composer)

Using a text editor, edit the follow files :
```
# General configuration
.env

# Admin username and password
_secrets/admin_username
_secrets/admin_password

# Backup (optional)
_secrets/rclone.backup.conf
```

When ready, start the stack using this command :
```
# Run the stack
docker-compose -f docker-compose.yml up -d --build
```

### Upgrade

If at some point you want to update the SPCgeonode setup (this will work only if you didn't do modifications, if you did, you need to merge them) :
```
# Get the update setup
git pull

# Upgrade the stack
docker-compose -f docker-compose.yml up -d --build
```

### Developpement vs Production

Difference of dev setup vs prod setup:

- Django source is mounted on the host and uwsgi does live reload (so that edits to the python code is reloaded live)
- Django static and media folder, Geoserver's data folder and Certificates folder are mounted on the host (just to easily see what's happening)
- Django debug is set to True
- Postgres's port 5432 is exposed (to allow debugging using pgadmin)
- Nginx debug mode is acticated (not really sure what this changes)
- Docker tags are set to dev instead of latest

### Publishing the images

Pushes to github trigger automatic builds on docker hub for tags looking like x.x.x

Sometimes, the automatic builds fail with no apparent reason. If so, you can publish the images manually with :

```
docker login
docker-compose -f docker-compose.yml build
docker-compose -f docker-compose.yml push
```
