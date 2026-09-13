SRC_DIR	= srcs
COMPOSE			= docker-compose.yaml
include $(SRC_DIR)/.env
MARIADB_SVC	= mariadb
WP_SVC			= wordpress

all: create_dirs up

create_dirs:
	@mkdir -p $(HOME)/data/db
	@mkdir -p $(HOME)/data/wordpress
	@echo "Volume directories created."

up: create_dirs
	cd $(SRC_DIR) && docker compose -f $(COMPOSE) up --build -d

down:
	cd $(SRC_DIR) && docker compose -f $(COMPOSE) down

down-v:
	cd $(SRC_DIR) && docker compose -f $(COMPOSE) down -v

fclean:
	cd $(SRC_DIR) && docker compose -f $(COMPOSE) down --rmi all -v
	sudo rm -rf $(HOME)/data/db/*
	sudo rm -rf $(HOME)/data/wordpress/*

re: fclean all

status:
	cd $(SRC_DIR) && docker compose -f $(COMPOSE) ps

logs:
	cd $(SRC_DIR) && docker compose -f $(COMPOSE) logs -f

shell_db:
	docker exec -it $(MARIADB_SVC) /bin/sh

shell_wp:
	docker exec -it $(WP_SVC) /bin/bash

.PHONY: all create_dirs up down fclean re status logs shell_db shell_wp