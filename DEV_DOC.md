# Inception Developer Guide

This guide describes how to prepare, build, operate, inspect, and reset the project. The required deployment target is a Linux virtual machine. Run commands from the repository root unless stated otherwise.

## Architecture and source layout

Docker Compose builds one Debian 12 image for each service and connects containers only to the user-defined bridge networks they require. `frontend` connects NGINX to its web upstreams, the externally isolated `backend` connects WordPress and Adminer to MariaDB and Redis, and `ftp-network` contains FTP. Service names provide internal DNS names, so fixed container IP addresses are unnecessary. NGINX routes HTTPS traffic to WordPress/PHP-FPM, Adminer, the static site, and Homer. FTP shares the WordPress named volume without joining either web network.

Important paths:

```text
Makefile                                  Lifecycle and certificate targets
srcs/.env.example                        Non-secret configuration template
srcs/docker-compose.yml                   Linux/VM Compose model
srcs/docker-compose.mac.yml               macOS convenience model
srcs/requirements/mariadb/                MariaDB image and initializer
srcs/requirements/wordpress/              WordPress/PHP-FPM image and initializer
srcs/requirements/nginx/                  NGINX image and TLS routing
srcs/requirements/bonus/                  Redis, FTP, Adminer, static site, Homer
srcs/requirements/tools/daemon.json.example  Linux Docker daemon example
secrets/                                  Local ignored secret material
```

## Prerequisites

Prepare a Linux VM with:

- Docker Engine with the Compose v2 plugin (`docker compose`)
- GNU Make
- OpenSSL
- permission to configure and restart the Docker daemon
- ports `443`, `21`, and `21100-21110` available for this stack
- network access during image builds to download Debian packages, WordPress, WP-CLI, Adminer, and Homer

Confirm the tools:

```sh
docker --version
docker compose version
make --version
openssl version
```

## Configure the environment from scratch

### 1. Configure Docker's data-root on the Linux VM

The Compose model uses true named volumes. To make Docker store those volumes under the subject-required `/home/ttanaka/data` directory, configure the Docker daemon's data-root as `/home/ttanaka/data/docker`.

`srcs/requirements/tools/daemon.json.example` contains the required setting:

```json
{
  "data-root": "/home/ttanaka/data/docker"
}
```

Merge this key into `/etc/docker/daemon.json`; do not overwrite unrelated existing daemon settings. Restart Docker using the service manager provided by the VM, then verify:

```sh
docker info --format '{{.DockerRootDir}}'
```

The result must be `/home/ttanaka/data/docker`. Changing `data-root` changes where this Docker daemon sees all of its images, containers, and volumes, so configure it before creating project data.

### 2. Configure local name resolution

Add a hosts-file entry on every client that will open the site:

```text
<VM_IP> ttanaka.42.fr
```

Replace `<VM_IP>` with the Linux VM's reachable IP address. The repository's NGINX and bonus dashboard configuration is written for `ttanaka.42.fr`.

### 3. Create the environment file

```sh
cp srcs/.env.example srcs/.env
```

Fill every variable:

| Variable | Meaning |
| --- | --- |
| `MYSQL_DATABASE` | WordPress database name |
| `MYSQL_USER` | Non-root MariaDB application user |
| `DOMAIN_NAME` | WordPress URL host; use `ttanaka.42.fr` |
| `WP_TITLE` | Initial WordPress site title |
| `WP_ADMIN_USER` | Initial administrator username; must not contain `admin` or `administrator` in any letter case |
| `WP_ADMIN_EMAIL` | Initial administrator email |
| `WP_USER` | Initial non-administrator WordPress username |
| `WP_USER_EMAIL` | Initial non-administrator email |
| `FTP_USER` | FTP account name |
| `FTP_PASV_ADDRESS` | VM address or resolvable hostname advertised for passive FTP |

Do not put passwords in this file. `srcs/.env` is ignored by Git.

### 4. Create password secrets

Create the ignored directory and empty files with restrictive permissions:

```sh
install -m 700 -d secrets
install -m 600 /dev/null secrets/db_password.txt
install -m 600 /dev/null secrets/db_root_password.txt
install -m 600 /dev/null secrets/wp_admin_password.txt
install -m 600 /dev/null secrets/wp_user_password.txt
install -m 600 /dev/null secrets/ftp_password.txt
```

Put one strong, non-empty password in each file using a secure editor or password manager workflow that does not expose the value in shell history. Do not add a trailing explanatory label. The Compose model grants each secret only to the services that require it.

### 5. Generate TLS material

```sh
make setup
```

This creates a private CA and a server certificate for `ttanaka.42.fr` under `secrets/my-ca/` and `secrets/nginx/`, then tightens permissions. Keep both private keys secret. Distribute only `secrets/my-ca/my-ca.crt` to clients that need to trust this development certificate.

## Build and launch

Build every image and start the Linux/VM stack:

```sh
make up
```

`make` is an alias for `make up`. Before Compose starts, the Makefile verifies that Docker's data-root is exactly `/home/ttanaka/data/docker` by default. To use a different login when adapting the project, pass consistent Make variables and update all login-specific configuration:

```sh
make up LOGIN=<login> DOMAIN_NAME=<login>.42.fr
```

The `LOGIN` override only changes the Makefile's expected data-root; it does not rewrite NGINX, Homer, or static-site source files.

For local macOS testing only:

```sh
make up-mac
```

The macOS target skips the Linux data-root check and uses the separate `inception_db-vol-mac` and `inception_wp-vol-mac` volumes inside Docker Desktop's VM.

## Makefile commands

| Command | Effect | Persistent volumes |
| --- | --- | --- |
| `make` / `make up` | Build and start the Linux stack | Created or reused |
| `make status` | Show Linux Compose and container state | Unchanged |
| `make down` | Stop and remove Linux containers and network | Preserved |
| `make clean` | Stop the stack and remove its images | Preserved |
| `make fclean` | Stop the stack and remove images and volumes | **Deleted** |
| `make re` | Run `fclean`, then rebuild and start | **Deleted and recreated** |
| `make setup` | Generate the private CA and TLS server material | Unchanged |
| `make secure-secrets` | Apply restrictive permissions under `secrets/` | Unchanged |
| `make prune` | Prune unused images, containers, networks, and volumes daemon-wide | May delete unrelated unused data |

The `-mac` variants perform the corresponding operation against `srcs/docker-compose.mac.yml`.

## Direct Docker Compose management

Use the same Compose file as the Makefile so commands target the correct project:

```sh
docker compose -f srcs/docker-compose.yml ps
docker compose -f srcs/docker-compose.yml logs --tail=100 <service>
docker compose -f srcs/docker-compose.yml logs -f <service>
docker compose -f srcs/docker-compose.yml restart <service>
docker compose -f srcs/docker-compose.yml build <service>
docker compose -f srcs/docker-compose.yml up -d --build <service>
docker compose -f srcs/docker-compose.yml exec <service> <command>
```

Valid service names are `mariadb`, `wordpress`, `nginx`, `redis`, `ftp`, `adminer`, `static_website`, and `homer`.

After changing a Dockerfile or a file copied into an image, rebuild that service. After changing only `srcs/.env`, recreate the affected service; a simple restart does not inject a changed environment. Remember that first-run application initialization is skipped when existing volume data is present.

Useful model and network checks:

```sh
docker compose -f srcs/docker-compose.yml config
docker network inspect srcs_frontend
docker network inspect srcs_backend
docker network inspect srcs_ftp-network
```

The actual Compose network names include the Compose project name, which is normally derived from the `srcs` directory. `backend` is declared with `internal: true`, so MariaDB and Redis do not receive a route to external networks. WordPress and Adminer join both application networks because they must accept requests from the frontend side and connect to MariaDB on the backend side. FTP joins only `ftp-network`; sharing `wp-vol` does not require network connectivity to WordPress.

## Persistent data and volumes

The Linux Compose model creates:

| Volume | Container mount | Content |
| --- | --- | --- |
| `inception-db` | `/var/lib/mysql` in `mariadb` | MariaDB system tables and WordPress database |
| `inception-wp` | `/var/www/html` in `wordpress`, `nginx`, and `ftp` | WordPress core, configuration, plugins, themes, and uploads |

Because Docker's data-root is `/home/ttanaka/data/docker`, their engine-managed data is normally below:

```text
/home/ttanaka/data/docker/volumes/inception-db/_data
/home/ttanaka/data/docker/volumes/inception-wp/_data
```

Treat those paths as Docker-managed implementation details; do not edit their contents directly. Inspect the authoritative mountpoint and volume metadata with:

```sh
docker volume inspect inception-db
docker volume inspect inception-wp
docker volume ls
```

Container removal and `make down` do not delete these volumes, so the site survives ordinary rebuilds and restarts. `make fclean`, `make re`, or `docker compose -f srcs/docker-compose.yml down -v` deletes them. Back up both the database and WordPress files before deleting volumes.

### First-run initialization

MariaDB initialization runs only when `/var/lib/mysql/mysql` is absent. WordPress initialization runs only when `/var/www/html/wp-config.php` is absent. Consequently:

- changing `MYSQL_DATABASE`, `MYSQL_USER`, WordPress initial-user values, or their password files does not migrate existing persistent data;
- credentials must be rotated inside MariaDB or WordPress as well as in the corresponding local secret file;
- a clean first-run test requires deleting the named volumes, which destroys stored site data.

## Verification and debugging

Check overall status:

```sh
make status
```

Check HTTPS using the generated CA:

```sh
curl --fail --cacert secrets/my-ca/my-ca.crt https://ttanaka.42.fr/
openssl s_client -connect ttanaka.42.fr:443 -servername ttanaka.42.fr -tls1_3
```

Check the WordPress Redis integration:

```sh
docker compose -f srcs/docker-compose.yml exec wordpress wp redis status --allow-root
```

Typical startup dependency order is MariaDB healthy, then WordPress healthy, then NGINX. If the stack fails:

1. Run `docker compose -f srcs/docker-compose.yml ps`.
2. Read the failing service's logs.
3. Verify required `.env` values and secret-file existence without printing secret contents.
4. Check `docker volume inspect` before assuming a first-run initializer should execute.
5. Validate name resolution and the certificate's `ttanaka.42.fr` subject alternative name.

## Security notes

- Never commit `srcs/.env`, `secrets/`, credentials, private keys, or API keys.
- Do not pass passwords directly on a command line where they may enter shell history or process listings.
- Do not expose MariaDB or Redis ports on the host; they are intended for the private Compose network.
- FTP is unencrypted and is suitable only for the isolated assignment environment.
- Review `make prune` carefully because it affects the whole Docker daemon.
- Trust the private CA only on intended development clients and remove that trust when the environment is retired.
