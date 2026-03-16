SHELL       := /bin/bash

RESET		= \033[0m
RED			= \033[31m
GREEN		= \033[32m
YELLOW		= \033[33m
BLUE		= \033[34m
MAGENTA		= \033[35m
CYAN		= \033[36m
WHITE		= \033[37m

COMPOSE_FILE = srcs/docker-compose.yml
MAC_COMPOSE_FILE = srcs/docker-compose.mac.yml
LOGIN ?= ttanaka
DOMAIN_NAME ?= $(LOGIN).42.fr
DATA_DIR ?= /home/$(LOGIN)/data
export DATA_DIR

all: up

up:
	@mkdir -p $(DATA_DIR)/mariadb
	@mkdir -p $(DATA_DIR)/wordpress
	DATA_DIR="$(DATA_DIR)" docker compose -f $(COMPOSE_FILE) up -d --build

up-mac:
	docker compose -f $(MAC_COMPOSE_FILE) up -d --build

down:
	DATA_DIR="$(DATA_DIR)" docker compose -f $(COMPOSE_FILE) down

down-mac:
	docker compose -f $(MAC_COMPOSE_FILE) down

clean:
	DATA_DIR="$(DATA_DIR)" docker compose -f $(COMPOSE_FILE) down -v --rmi all --remove-orphans

clean-mac:
	docker compose -f $(MAC_COMPOSE_FILE) down -v --rmi all --remove-orphans

fclean: clean

prune:
	docker system prune -a --volumes -f

re: fclean all

secure-secrets:
	@mkdir -p ./secrets ./secrets/my-ca ./secrets/nginx
	@find ./secrets -type d -exec chmod 700 {} +
	@find ./secrets -type f \( -name '*.key' -o -name '*.txt' \) -exec chmod 600 {} +
	@find ./secrets -type f \( -name '*.crt' -o -name '*.csr' -o -name '*.srl' \) -exec chmod 644 {} +

setup:
	@echo -e "$(GREEN)Setting up certificate...$(RESET)"
	@echo -e "$(CYAN)[1/2] Generating private certificate authority...$(RESET)"
	@mkdir -p ./secrets/my-ca
	@umask 077; openssl genrsa 4096 > ./secrets/my-ca/my-ca.key
	@openssl req -new -key ./secrets/my-ca/my-ca.key -subj "/CN=MyPrivateCA" > ./secrets/my-ca/my-ca.csr
	@cat ./secrets/my-ca/my-ca.csr | openssl x509 -req -signkey ./secrets/my-ca/my-ca.key -days=3650 > ./secrets/my-ca/my-ca.crt

	@echo -e "$(CYAN)[2/2] Generating private server key and certificate...$(RESET)"
	@mkdir -p ./secrets/nginx
	@umask 077; openssl genrsa 4096 > ./secrets/nginx/server.key
	@openssl req -new -key ./secrets/nginx/server.key -subj "/CN=$(DOMAIN_NAME)" > ./secrets/nginx/server.csr 
	@echo "subjectAltName = DNS:$(DOMAIN_NAME)" > san.txt
	@openssl x509 -req -in ./secrets/nginx/server.csr \
		-CA ./secrets/my-ca/my-ca.crt \
		-CAkey ./secrets/my-ca/my-ca.key \
		-CAcreateserial \
		-days 398 \
		-extfile san.txt \
		-out ./secrets/nginx/server.crt
	@rm san.txt
	@$(MAKE) secure-secrets

	@echo -e "$(GREEN)Done!$(RESET)"

.PHONY: all up up-mac down down-mac clean clean-mac fclean prune re secure-secrets setup