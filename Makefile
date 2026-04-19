COMPOSE			= srcs/docker-compose.yaml
# LOGIN				= kaahmed
LOGIN				= foyez
MARIADB_SVC	= mariadb
WP_SVC			= wordpress

all: create_dirs up

create_dirs:
	@mkdir -p /home/$(LOGIN)/data/db
	@mkdir -p /home/$(LOGIN)/data/wordpress
	@echo "Volume directories created."

up: create_dirs
	docker compose -f $(COMPOSE) up --build -d

down:
	docker compose -f $(COMPOSE) down

down-v:
	docker compose -f $(COMPOSE) down -v

fclean:
	docker compose -f $(COMPOSE) down --rmi all -v
	sudo rm -rf /home/$(LOGIN)/data/db/*
	sudo rm -rf /home/$(LOGIN)/data/wordpress/*

re: fclean all

status:
	docker compose -f $(COMPOSE) ps

logs:
	docker compose -f $(COMPOSE) logs -f

shell_db:
	docker exec -it $(MARIADB_SVC) /bin/sh

shell_wp:
	docker exec -it $(WP_SVC) /bin/bash

.PHONY: all create_dirs up down fclean re status logs shell_db shell_wp