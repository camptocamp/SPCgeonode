# SPCgeonode

## Prerequisites

Make sure you have a version of Docker (tested with 17.12) and docker-compose.

```
# Checkout the source
git clone --recursive -b gfdrr https://github.com/camptocamp/SPCgeonode.git
```

## Usage

### Development

Have a look a file script/restore, customize if needed, and execute parts you need to get a working configuration and database.

To start the whole stack:

```
docker-compose up --build -d
```

Once everything started, you should be able to open http://127.0.0.1:8080 in your browser.

### Debug less files

Add docker-compose.override.yaml file with following content:

```
version: '2'
services:
  django:
    volumes:
      - ./geonode/geonode:/usr/local/lib/python2.7/site-packages/geonode
```

And each time you modify the files, transpile less files to css files:

```
make update-css
```

Refresh the page in your browser, styling should be up to date.

### Publishing the images

Push the images on docker hub:

```
make docker-push
```

## Links

Geonode source <https://github.com/GFDRR/geonode>

Deployment on Rancher <https://github.com/camptocamp/terraform-geonode>
