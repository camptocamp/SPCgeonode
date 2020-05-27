DOCKER_BASE=camptocamp/geonode
DOCKER_TAG=rebase_2.10.x

build:
	docker-compose build

bash:
	docker-compose run --rm --entrypoint "" django bash

docker-push:
	docker push ${DOCKER_BASE}_django:${DOCKER_TAG}
	docker push ${DOCKER_BASE}_geoserver:${DOCKER_TAG}
