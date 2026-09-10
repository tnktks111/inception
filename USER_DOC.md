# Inception User Guide

This guide is for the person operating the stack or administering its WordPress site. Run all commands from the repository root unless stated otherwise.

## Services provided

| Service | Purpose | Access |
| --- | --- | --- |
| WordPress | Main website and content management system | `https://ttanaka.42.fr` |
| WordPress administration | Manage posts, users, themes, and plugins | `https://ttanaka.42.fr/wp-admin/` |
| Adminer | Browser-based MariaDB administration | `https://ttanaka.42.fr/adminer` |
| Static portfolio | Bonus static website | `https://ttanaka.42.fr/portfolio` |
| Homer | Bonus service dashboard | `http://<VM_IP>:8888` |
| FTP | File access to WordPress `wp-content` | `ttanaka.42.fr`, port `21`; passive ports `21100-21110` |
| MariaDB | WordPress database; internal only | Service name `mariadb`, port `3306` inside the Docker network |
| Redis | WordPress object cache; internal only | Service name `redis`, port `6379` inside the Docker network |

NGINX is the only public entry point for the mandatory web stack. FTP and Homer expose extra ports because they are bonus services.

## Before the first start

The project must already have been configured by following `DEV_DOC.md`. In particular, verify that:

- `srcs/.env` exists and every required non-secret value is filled in.
- All password files under `secrets/` exist and contain non-empty values.
- `secrets/nginx/server.crt` and `secrets/nginx/server.key` exist after running `make setup`.
- `ttanaka.42.fr` resolves to the virtual machine's IP address from the client machine.
- Docker is running.

## Start and stop the stack

Build and start all services in the Linux VM:

```sh
make up
```

`make` performs the same action. The first launch takes longer because the images are built and MariaDB and WordPress are initialized. Wait until the health checks report healthy before opening the site.

Stop and remove the containers and network while preserving the two named volumes:

```sh
make down
```

Start the same persistent site again with `make up`.

For local macOS testing with Docker Desktop, use `make up-mac` and `make down-mac`. The macOS Compose file uses different volume names and is separate from the evaluated Linux/VM deployment.

## Access the website and administration tools

### HTTPS certificate

The site uses a certificate signed by the project's private certificate authority. A browser will warn that the issuer is unknown until `secrets/my-ca/my-ca.crt` is added to the client operating system or browser trust store. Verify the certificate source before trusting it. Never distribute `secrets/my-ca/my-ca.key` or `secrets/nginx/server.key`.

### WordPress

- Site: `https://ttanaka.42.fr`
- Administration: `https://ttanaka.42.fr/wp-admin/`
- Administrator username: the `WP_ADMIN_USER` value in `srcs/.env`
- Administrator password: the content of `secrets/wp_admin_password.txt`
- General author username: the `WP_USER` value in `srcs/.env`
- General author password: the content of `secrets/wp_user_password.txt`

The administrator username must not contain `admin` or `administrator`, regardless of capitalization.

### Adminer

Open `https://ttanaka.42.fr/adminer` and use:

- System: `MySQL`
- Server: `mariadb`
- Username: the `MYSQL_USER` value in `srcs/.env`
- Password: the content of `secrets/db_password.txt`
- Database: the `MYSQL_DATABASE` value in `srcs/.env`

Use the application database account for routine work instead of the MariaDB root account.

### FTP

Configure an FTP client with:

- Host: `ttanaka.42.fr`
- Port: `21`
- Username: the `FTP_USER` value in `srcs/.env`
- Password: the content of `secrets/ftp_password.txt`
- Transfer mode: passive

The passive port range is `21100-21110`. The FTP user's home is the shared WordPress `wp-content` directory. This service is plain FTP, not SFTP or FTPS; use it only in the isolated project environment.

## Credentials and secrets

Non-secret account names and application settings are stored locally in `srcs/.env`. Passwords and TLS material are stored locally under `secrets/`. Both locations are excluded from Git by `.gitignore`.

| File | Used by |
| --- | --- |
| `secrets/db_password.txt` | MariaDB application user and WordPress |
| `secrets/db_root_password.txt` | MariaDB root account |
| `secrets/wp_admin_password.txt` | WordPress administrator |
| `secrets/wp_user_password.txt` | WordPress author |
| `secrets/ftp_password.txt` | FTP user |
| `secrets/nginx/server.crt` | NGINX TLS certificate |
| `secrets/nginx/server.key` | NGINX TLS private key |
| `secrets/my-ca/my-ca.crt` | Private CA certificate that clients may trust |
| `secrets/my-ca/my-ca.key` | Private CA key; never distribute it |

Restrict secret directory permissions with:

```sh
make secure-secrets
```

Do not print passwords to logs, paste them into issue trackers, or commit them. Back up secrets only to an access-controlled location.

### Changing credentials

The MariaDB and WordPress initialization scripts consume the password files only when their persistent data is created for the first time. Editing a password file later does **not** update an existing database user or WordPress user. Change an existing password through MariaDB or WordPress first, then update the corresponding local secret so both values remain consistent.

Deleting the volumes and starting again applies a completely new set of initial credentials, but it also permanently deletes the WordPress database and website files. Back up required data before any reset.

## Check service health

Show the Compose state and container health:

```sh
make status
```

Healthy operation should show all services running. MariaDB and WordPress should report healthy; NGINX starts only after WordPress becomes healthy.

Test the main HTTPS endpoint with the project CA:

```sh
curl --fail --cacert secrets/my-ca/my-ca.crt https://ttanaka.42.fr/
```

Inspect recent logs when a service is not healthy:

```sh
docker compose -f srcs/docker-compose.yml logs --tail=100 <service>
```

Replace `<service>` with `mariadb`, `wordpress`, `nginx`, `redis`, `ftp`, `adminer`, `static_website`, or `homer`. Follow live logs with `-f` and stop following them with `Ctrl-C`.

Common checks:

- If `make up` reports an unexpected Docker data-root, complete the Linux VM daemon setup in `DEV_DOC.md`.
- If the hostname does not resolve, correct the client machine's hosts-file entry.
- If the browser rejects HTTPS, verify the hostname and trust the generated CA certificate.
- If WordPress cannot start, check MariaDB health and confirm that the `.env` values and secret files were present on the first launch.
- If FTP connects but directory writes fail, inspect the FTP logs and permissions on the shared WordPress volume.

## Safe cleanup

`make down` is the normal stop command and keeps persistent data. `make clean` also removes built images but keeps the named volumes.

Do not use `make fclean`, `make re`, or `make prune` for routine operation:

- `make fclean` removes the containers, images, and both named volumes, destroying the database and WordPress files.
- `make re` performs `fclean` before rebuilding, so it also destroys persistent project data.
- `make prune` removes unused Docker data across the entire Docker daemon, not only this project.
