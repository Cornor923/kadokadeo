all: install docker-start
	@echo "Project installed successfully! You can access Kadokadéo at http://kadokadeo.localhost/."

docker-start: docker-stop
	docker compose up -d --no-recreate --remove-orphans

docker-watch:
	docker compose up --no-recreate --remove-orphans

docker-stop:
	docker compose stop

docker-remove: docker-stop
	docker rm kadokadeo_app kadokadeo_database kadokadeo_eternaltwin

bash-app:
	docker exec -u dev -it kadokadeo_app /bin/sh

bash-db:
	docker exec -it kadokadeo_database bash

bash-eternaltwin:
	docker exec -it kadokadeo_eternaltwin bash

reset-dependencies: install-app install-eternaltwin

build:
	docker compose build
	docker compose up --no-start --remove-orphans

install: setup-env-variables build start-kadokadeo-database install-app install-eternaltwin

install-app:
	docker compose run kadokadeo_app composer install
	docker compose run kadokadeo_app php artisan key:generate --ansi
	docker compose run kadokadeo_app php artisan migrate:fresh --force --seed

install-eternaltwin:
	docker compose run --rm kadokadeo_eternaltwin eternaltwin db sync

reset-database:
	docker compose run kadokadeo_app php artisan migrate:fresh --force --seed

reset-eternaltwin-database:
	docker compose run --rm kadokadeo_eternaltwin eternaltwin db reset

start-kadokadeo-database:
	docker start kadokadeo_database

setup-env-variables:
	cp compose.override.yaml.example compose.override.yaml
	cp .env.example .env
	cp eternaltwin/etwin.toml.example eternaltwin/etwin.toml
	cp eternaltwin/eternaltwin.toml.example eternaltwin/eternaltwin.toml
	openssl genrsa -out storage/app/private/privkey.pem
	openssl rsa -in storage/app/private/privkey.pem -pubout -out storage/app/private/pubkey.pem

sync-database:
	docker compose run --rm kadokadeo_app php artisan migrate --force

compile-games-prod:
	docker exec -u dev kadokadeo_app haxe compile.hxml
	docker exec -u node -w /www kadokadeo_front yarn games:bundle

compile-games:
	docker exec -u dev kadokadeo_app haxe compile-dev.hxml
	docker exec -u node -w /www kadokadeo_front yarn games:bundle

update-libraries:
	docker exec -u dev kadokadeo_app haxelib install --always resources/hx/install.hxml
