# Makefile for Docker Nginx PHP Composer MySQL

include .env

# MySQL
MYSQL_DUMPS_DIR=data/db/dumps

help:
	@echo ""
	@echo "usage: make COMMAND"
	@echo ""
	@echo "Commands:"
	@echo "  apidoc              Generate documentation of API"
	@echo "  code-sniff          Check the API with PHP Code Sniffer (PSR2)"
	@echo "  clean               Clean directories for reset"
	@echo "  composer-up         Update PHP dependencies with composer"
	@echo "  docker-start        Create and start containers"
	@echo "  docker-stop         Stop and clear all services"
	@echo "  gen-certs           Generate SSL certificates"
	@echo "  logs                Follow log output"
	@echo "  mysql-dump          Create backup of all databases"
	@echo "  mysql-restore       Restore backup of all databases"
	@echo "  phpmd               Analyse the API with PHP Mess Detector"
	@echo "  test                Test application"

init:
	@$(shell cp -n $(shell pwd)/web/composer.json.dist $(shell pwd)/web/composer.json 2> /dev/null)
	@$(shell cp -n $(shell pwd)/web/composer.require.json.dist $(shell pwd)/web/composer.require.json 2> /dev/null)
	@$(shell cp -n $(shell pwd)/web/composer.suggested.json.dist $(shell pwd)/web/composer.suggested.json 2> /dev/null)
	@$(shell cp -n $(shell pwd)/settings/example.settings.local.php $(shell pwd)/settings/settings.local.php 2> /dev/null)
	@$(shell cp -n $(shell pwd)/settings/example.development.services.yml $(shell pwd)/settings/development.services.yml 2> /dev/null)

apidoc:
	@docker-compose exec -T php php -d memory_limit=256M -d xdebug.profiler_enable=0 vendor/bin/apigen generate app/src --destination doc
	@make resetOwner

clean:
	@rm -Rf data/db/mysql/*
	@rm -Rf $(MYSQL_DUMPS_DIR)/*
	@rm -Rf vendor/
	@rm -Rf composer.lock
	@rm -Rf settings/settings.local.php
	@rm -Rf settings/development.services.yml
	@rm -Rf report
	@rm -Rf web/
	@rm -Rf etc/ssl/*
	@rm -Rf bin/

code-sniff:
	@echo "Checking the Drupal standard code..."
	@docker-compose exec -T php bin/phpcs --standard=PSR2 --extensions=php,module,inc,install,test,profile,theme,js,css,info,txt,md web/modules

c-update:
	@docker-compose exec -T php composer update

c-install:
	@docker-compose exec -T php composer install

drupal-si:
	@docker-compose exec -T php composer site-install

drupal-update:
	@docker-compose exec -T php composer site-update

docker-start: init gen-certs
	docker-compose up -d
	@make c-install

docker-stop:
	@docker-compose down -v
	@make clean

gen-certs:
	@docker run --rm -v $(shell pwd)/etc/ssl:/certificates -e "SERVER=$(NGINX_HOST)" jacoelho/generate-certificate

logs:
	@docker-compose logs -f

mysql-dump:
	@mkdir -p $(MYSQL_DUMPS_DIR)
	@docker exec $(shell docker-compose ps -q mysqldb) mysqldump --all-databases -u"$(MYSQL_ROOT_USER)" -p"$(MYSQL_ROOT_PASSWORD)" > $(MYSQL_DUMPS_DIR)/db.sql 2>/dev/null
	@make resetOwner

mysql-restore:
	@docker exec -i $(shell docker-compose ps -q mysqldb) mysql -u"$(MYSQL_ROOT_USER)" -p"$(MYSQL_ROOT_PASSWORD)" < $(MYSQL_DUMPS_DIR)/db.sql 2>/dev/null

phpmd:
	@docker-compose exec -T php \
	./vendor/bin/phpmd \
	./web \
	text cleancode,codesize,controversial,design,naming,unusedcode

test: code-sniff
	@echo "Lets go to test complete drupal suite..."
	@docker-compose exec -T php ./bin/phpunit web/core --colors=always
	@make resetOwner

resetOwner:
	@$(shell chown -Rf $(SUDO_USER):$(shell id -g -n $(SUDO_USER)) $(MYSQL_DUMPS_DIR) "$(shell pwd)/etc/ssl" "$(shell pwd)/web" 2> /dev/null)

.PHONY: clean test code-sniff init