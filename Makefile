ifndef STAGING_ENV
	STAGING_ENV=dev
endif

app_dir=$(shell pwd)
project=$(shell basename ${app_dir})_${STAGING_ENV}
composer_args=--prefer-dist --no-progress --no-interaction --no-suggest

dc=COMPOSE_PROJECT_NAME=${project} APP_DIR=${app_dir} STAGING_ENV=${STAGING_ENV} \
	docker-compose \
	-f devops/environment/base/docker-compose.yaml \
	-f devops/environment/${STAGING_ENV}/docker-compose.yaml \
	--project-directory devops/environment/${STAGING_ENV}
exec=${dc} exec -u $(shell id -u):$(shell id -g)
app=${exec} app
app_console=${app} bin/console
composer=${app} composer

# application
install:
	${composer} install ${composer_args}
update:
	${composer} update ${composer_args}
update-recipes:
	${composer} symfony:sync-recipes --force
shell:
	${exec} $${SERVICE:-app} sh -c "if [ -f /run/secrets/env_bucket ]; then set -a && . /run/secrets/env_bucket; fi; sh"
mysql:
	${exec} $${SERVICE:-db} sh -c "mysql -u \$${MYSQL_USER} -p\$${MYSQL_PASSWORD} \$${MYSQL_DATABASE}"

# containers
start:
	${dc} up --no-build -d
restart:
	${dc} restart
refresh: build start install
stop:
	${dc} stop
quit:
	${dc} down --remove-orphans

# images
setup:
	devops/bin/setup.sh "${STAGING_ENV}" "${app_dir}" "${project}"
build: setup quit
	${dc} build --parallel --force-rm --build-arg staging_env=${STAGING_ENV}

# devops
devops-init:
	git remote add devops git@github.com:ro0NL/symfony-docker.git
devops-merge:
	git fetch devops master
	git merge --no-commit --no-ff --allow-unrelated-histories devops/master

# misc
exec:
	echo "${exec}"
run:
	echo "${dc} run --rm"
requirement-check:
	${composer} require symfony/requirements-checker ${composer_args} --no-scripts -q
	${app} vendor/bin/requirements-checker
	${composer} remove symfony/requirements-checker -q

# debug
composed-config:
	${dc} config
composed-images:
	${dc} images
log:
	${dc} logs -f
