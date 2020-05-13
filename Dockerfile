# TODO : use python:2.7.13-alpine3.6 to make this lighter ( it is what we use for letsencryipt as well)
# But it seems it's not possible for now because alpine only has geos 3.6 which is not supported by django 1.8
# (probably because of https://code.djangoproject.com/ticket/28441)

FROM python:2.7.14-slim-stretch

# Install system dependencies
RUN apt-get update && \
    apt-get install -y gcc make libc-dev musl-dev libpcre3 libpcre3-dev g++ \
      libgeos-dev libgdal-dev \
      libxml2-dev libxslt-dev git \
      geoip-bin geoip-database \
      curl \
      uwsgi && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf ~/.cache/pip

# Install python dependencies
RUN pip install --upgrade pip
RUN pip install --no-cache-dir pygdal==$(gdal-config --version).* celery==4.1.0
# RUN pip install --no-cache-dir git+https://github.com/tonio/geonode.git@rebase_2.10.x
ADD geonode /geonode
RUN pip install /geonode

# 5. Add the application
WORKDIR /spcgeonode/
ADD requirements.txt /spcgeonode/requirements.txt
RUN pip install -r requirements.txt
ADD . /spcgeonode/

# Export ports
EXPOSE 8000

# Set environnment variables
ENV DJANGO_SETTINGS_MODULE=spcgeonode.settings \
    DATABASE_URL=postgres://postgres:postgres@postgres:5432/postgres \
    BROKER_URL=amqp://guest:guest@rabbitmq:5672/ \
    STATIC_ROOT=/spcgeonode-static/ \
    MEDIA_ROOT=/spcgeonode-media/ \
    STATIC_URL=/static/ \
    MEDIA_URL=/media/ \
    C_FORCE_ROOT=True \
    MONITORING_ENABLED=False

# We provide no command or entrypoint as this image can be used to serve the django project or run celery tasks
