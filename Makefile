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
DATA_DIR = /home/ttanaka42/data

all: up

up:
	@mkdir -p $(DATA_DIR)/mariadb
	@mkdir -p $(DATA_DIR)/wordpress
	docker compose -f $(COMPOSE_FILE) up -d --build

down:
	docker compose -f $(COMPOSE_FILE) down

clean:
	docker compose -f $(COMPOSE_FILE) down -v --rmi all --remove-orphans

fclean: clean
	@sudo rm -rf $(DATA_DIR)/mariadb/*
	@sudo rm -rf $(DATA_DIR)/wordpress/*
	@sudo rm -rf $(DATA_DIR)
	docker system prune -a --volumes -f

re: fclean all

setup:
	@echo -e "$(GREEN)Setting up certificate...$(RESET)"
	@echo -e "$(CYAN)[1/2] Generating private certificate authority...$(RESET)"
	@mkdir -p ./secrets/my-ca
	@openssl genrsa 4096 > ./secrets/my-ca/my-ca.key
	@openssl req -new -key ./secrets/my-ca/my-ca.key -subj "/CN=MyPrivateCA" > ./secrets/my-ca/my-ca.csr
	@cat ./secrets/my-ca/my-ca.csr | openssl x509 -req -signkey ./secrets/my-ca/my-ca.key -days=3650 > ./secrets/my-ca/my-ca.crt

	@echo -e "$(CYAN)[2/2] Generating private server key and certificate...$(RESET)"
	@mkdir -p ./secrets/nginx
	@openssl genrsa 4096 > ./secrets/nginx/server.key
	@openssl req -new -key ./secrets/nginx/server.key -subj "/CN=ttanaka.42.fr" > ./secrets/nginx/server.csr 
	@echo "subjectAltName = DNS:ttanaka.42.fr" > san.txt
	@openssl x509 -req -in ./secrets/nginx/server.csr \
		-CA ./secrets/my-ca/my-ca.crt \
		-CAkey ./secrets/my-ca/my-ca.key \
		-CAcreateserial \
		-days 398 \
		-extfile san.txt \
		-out ./secrets/nginx/server.crt
	@rm san.txt

	@echo -e "$(GREEN)Done!$(RESET)"

.PHONY: all up down clean fclean re setup