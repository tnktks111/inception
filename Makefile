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
DOCKER_DATA_ROOT ?= /home/$(LOGIN)/data/docker

SECRET_NAMES := \
	db_password \
	db_root_password \
	wp_admin_password \
	wp_user_password \
	ftp_password

all: up

up: check-data-root
	docker compose -f $(COMPOSE_FILE) up -d --build

up-mac:
	docker compose -f $(MAC_COMPOSE_FILE) up -d --build

status:
	@echo -e "$(CYAN)Compose services ($(COMPOSE_FILE))$(RESET)"
	docker compose -f $(COMPOSE_FILE) ps
	@echo
	@echo -e "$(CYAN)Container health$(RESET)"
	@docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | grep -E 'srcs-|NAME' | cat

status-mac:
	@echo -e "$(CYAN)Compose services ($(MAC_COMPOSE_FILE))$(RESET)"
	@docker compose -f $(MAC_COMPOSE_FILE) ps
	@echo
	@echo -e "$(CYAN)Container health$(RESET)"
	@docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | grep -E 'srcs-|NAME' | cat

down:
	docker compose -f $(COMPOSE_FILE) down

down-mac:
	docker compose -f $(MAC_COMPOSE_FILE) down

clean:
	docker compose -f $(COMPOSE_FILE) down \
		--rmi all \
		--remove-orphans

clean-mac:
	docker compose -f $(MAC_COMPOSE_FILE) down \
		--rmi all \
		--remove-orphans

fclean: 	
	docker compose -f $(COMPOSE_FILE) down \
		-v \
		--rmi all \
		--remove-orphans

fclean-mac:
	docker compose -f $(MAC_COMPOSE_FILE) down \
		-v \
		--rmi all \
		--remove-orphans

prune:
	docker system prune -a --volumes -f

re: fclean
	@$(MAKE) all

secure-secrets:
	@mkdir -p ./secrets ./secrets/my-ca ./secrets/nginx
	@find ./secrets -type d -exec chmod 700 {} +
	@find ./secrets -type f \( -name '*.key' -o -name '*.txt' \) -exec chmod 600 {} +
	@find ./secrets -type f \( -name '*.crt' -o -name '*.csr' -o -name '*.srl' \) -exec chmod 644 {} +

init-secrets:
	@install -m 700 -d ./secrets
	@for name in $(SECRET_NAMES); do \
		file="./secrets/$${name}.txt"; \
		if [ -s "$$file" ]; then \
			echo "Keeping existing $$file"; \
		else \
			umask 077; \
			openssl rand -hex 24 > "$$file"; \
			echo "Created $$file"; \
		fi; \
	done
	@$(MAKE) secure-secrets

setup: init-secrets
	@echo -e "$(GREEN)Setting up certificate...$(RESET)"
	@echo -e "$(CYAN)[1/2] Generating private certificate authority...$(RESET)"
	@mkdir -p ./secrets/my-ca
	@umask 077; openssl genrsa 4096 > ./secrets/my-ca/my-ca.key
	@openssl req -new -key ./secrets/my-ca/my-ca.key -subj "/CN=MyPrivateCA" > ./secrets/my-ca/my-ca.csr
	@printf '%s\n' \
		'basicConstraints = critical, CA:TRUE, pathlen:0' \
		'keyUsage = critical, keyCertSign, cRLSign' \
		'subjectKeyIdentifier = hash' \
		| openssl x509 -req \
			-in ./secrets/my-ca/my-ca.csr \
			-signkey ./secrets/my-ca/my-ca.key \
			-sha256 \
			-days 3650 \
			-extfile /dev/stdin \
			-out ./secrets/my-ca/my-ca.crt

	@echo -e "$(CYAN)[2/2] Generating private server key and certificate...$(RESET)"
	@mkdir -p ./secrets/nginx
	@umask 077; openssl genrsa 4096 > ./secrets/nginx/server.key
	@openssl req -new -key ./secrets/nginx/server.key -subj "/CN=$(DOMAIN_NAME)" > ./secrets/nginx/server.csr 
	@printf '%s\n' \
		'basicConstraints = critical, CA:FALSE' \
		'keyUsage = critical, digitalSignature, keyEncipherment' \
		'extendedKeyUsage = serverAuth' \
		'subjectKeyIdentifier = hash' \
		'authorityKeyIdentifier = keyid, issuer' \
		'subjectAltName = DNS:$(DOMAIN_NAME)' \
		| openssl x509 -req \
			-in ./secrets/nginx/server.csr \
			-CA ./secrets/my-ca/my-ca.crt \
			-CAkey ./secrets/my-ca/my-ca.key \
			-CAcreateserial \
			-sha256 \
			-days 398 \
			-extfile /dev/stdin \
			-out ./secrets/nginx/server.crt
	@$(MAKE) secure-secrets

	@echo -e "$(GREEN)Done!$(RESET)"

check-data-root:
	@actual="$$(docker info --format '{{.DockerRootDir}}')"; \
	if [ "$$actual" != "$(DOCKER_DATA_ROOT)" ]; then \
		echo "Error: Docker data-root is '$$actual'"; \
		echo "Expected: $(DOCKER_DATA_ROOT)"; \
		echo "Configure /etc/docker/daemon.json first."; \
		exit 1; \
	fi

.PHONY: all up up-mac status status-mac down down-mac clean clean-mac fclean fclean-mac prune re secure-secrets init-secrets setup check-data-root
