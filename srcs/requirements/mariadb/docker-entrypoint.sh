#!/bin/bash
#
# Entrypoint script for MariaDB Docker container.
# Initializes the database directory, sets up environment variables,
# and configures the initial users and databases.

set -eo pipefail
shopt -s nullglob

# Logs a formatted message with a timestamp and log level.
# Globals:
#   None
# Arguments:
#   $1: Log type/level (e.g., Note, ERROR).
#   $@: The log message.
# Outputs:
#   Writes the formatted log message to stdout.
mysql_log() {
	local type="$1"; shift
	printf '%s [%s] [Entrypoint]: %s\n' "$(date --rfc-3339=seconds)" "$type" "$*"
}

# Logs an informational message.
# Globals:
#   None
# Arguments:
#   $@: The log message.
# Outputs:
#   Writes the log message to stdout.
mysql_note() {
	mysql_log Note "$@"
}

# Logs an error message and terminates the script.
# Globals:
#   None
# Arguments:
#   $@: The error message.
# Outputs:
#   Writes the error message to stderr.
# Returns:
#   Exits the script with status 1.
mysql_error() {
	mysql_log ERROR "$@" >&2
	exit 1
}

# Sets an environment variable, optionally falling back to reading from a file.
# Useful for handling Docker secrets (e.g., VAR_FILE).
# Globals:
#   Modifies the variable named by $1.
#   Unsets the variable named by ${1}_FILE.
# Arguments:
#   $1: The base name of the environment variable.
#   $2: (Optional) The default value if neither var nor var_file is set.
# Outputs:
#   None
# Returns:
#   Exits if both the direct variable and the file variable are set.
file_env() {
	local var="$1"
	local fileVar="${var}_FILE"
	local def="${2:-}"
	if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
		mysql_error "Both $var and $fileVar are set (but are exclusive)"
	fi
	local val="$def"
	if [ "${!var:-}" ]; then
		val="${!var}"
	elif [ "${!fileVar:-}" ]; then
		val="$(< "${!fileVar}")"
	fi
	export "$var"="$val"
	unset "$fileVar"
}

# Sets an environment variable, handling legacy MYSQL_ prefixes
# by mapping them to MARIADB_ prefixes.
# Globals:
#   Modifies the variable named by $1.
# Arguments:
#   $1: The base MYSQL_ environment variable name.
#   $2: (Optional) The default value.
# Outputs:
#   None
_mariadb_file_env() {
	local var="$1"; shift
	local maria="MARIADB_${var#MYSQL_}"
	file_env "$var" "$@"
	file_env "$maria" "${!var}"
	if [ "${!maria:-}" ]; then
		export "$var"="${!maria}"
	fi
}

# Initializes the MariaDB database data directory.
# Globals:
#   DATADIR
# Arguments:
#   None
# Outputs:
#   Writes initialization progress to stdout.
docker_init_database_dir() {
	mysql_note "Initializing database files"
	mariadb-install-db \
		--datadir="$DATADIR" \
		--auth-root-authentication-method=normal \
		--skip-test-db
	mysql_note "Database files initialized"
}

# Sets up global environment variables required for database configuration.
# Globals:
#   DATADIR (sets)
#   MYSQL_DATABASE (sets)
#   MYSQL_USER (sets)
#   MYSQL_PASSWORD (sets)
#   MYSQL_ROOT_PASSWORD (sets)
# Arguments:
#   None
# Outputs:
#   None
docker_setup_env() {
	DATADIR="/var/lib/mysql"

	_mariadb_file_env 'MYSQL_DATABASE'
	_mariadb_file_env 'MYSQL_USER'
	_mariadb_file_env 'MYSQL_PASSWORD'
	_mariadb_file_env 'MYSQL_ROOT_PASSWORD'
}

docker_verify_minimum_env() {
	if [ -z "${MYSQL_ROOT_PASSWORD:-}" ]; then
		mysql_error "MYSQL_ROOT_PASSWORD is required for first-time database initialization"
	fi

	if [ -n "${MYSQL_USER:-}" ] && [ -z "${MYSQL_PASSWORD:-}" ]; then
		mysql_error "MYSQL_PASSWORD must be set when MYSQL_USER is specified"
	fi

	if [ -n "${MYSQL_PASSWORD:-}" ] && [ -z "${MYSQL_USER:-}" ]; then
		mysql_error "MYSQL_USER must be set when MYSQL_PASSWORD is specified"
	fi
}

mysql_escape_string() {
	printf '%s' "$1" | sed "s/'/''/g"
}

mysql_escape_identifier() {
	printf '%s' "$1" | sed 's/`/``/g'
}

# Executes SQL commands using the MariaDB client as the root user.
# Globals:
#   MYSQL_ROOT_PASSWORD
# Arguments:
#   $@: Arguments and options passed to the mariadb client.
# Outputs:
#   Writes query results or client output to stdout/stderr.
docker_process_sql() {
	mariadb --protocol=socket --socket=/run/mysqld/mysqld.sock --user=root "$@"
}

# Configures initial users, privileges, and databases via SQL.
# Globals:
#   MYSQL_ROOT_PASSWORD
#   MYSQL_DATABASE
#   MYSQL_USER
#   MYSQL_PASSWORD
# Arguments:
#   None
# Outputs:
#   Writes execution notes to stdout.
docker_setup_db() {
	local root_password_escaped
	local database_escaped
	local user_escaped
	local password_escaped

	root_password_escaped="$(mysql_escape_string "${MYSQL_ROOT_PASSWORD}")"
	database_escaped="$(mysql_escape_identifier "${MYSQL_DATABASE:-}")"
	user_escaped="$(mysql_escape_string "${MYSQL_USER:-}")"
	password_escaped="$(mysql_escape_string "${MYSQL_PASSWORD:-}")"

	mysql_note "Securing system users (equivalent to running mysql_secure_installation)"
	docker_process_sql --database=mysql <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${root_password_escaped}';
DROP USER IF EXISTS root@'127.0.0.1', root@'::1';
FLUSH PRIVILEGES;
EOF

	if [ -n "${MYSQL_DATABASE:-}" ]; then
		docker_process_sql --database=mysql <<EOF
CREATE DATABASE IF NOT EXISTS \`${database_escaped}\`;
EOF
	fi

	if [ -n "${MYSQL_USER:-}" ]; then
		docker_process_sql --database=mysql <<EOF
CREATE USER IF NOT EXISTS '${user_escaped}'@'%' IDENTIFIED BY '${password_escaped}';
EOF
	fi

	if [ -n "${MYSQL_DATABASE:-}" ] && [ -n "${MYSQL_USER:-}" ]; then
		docker_process_sql --database=mysql <<EOF
GRANT ALL PRIVILEGES ON \`${database_escaped}\`.* TO '${user_escaped}'@'%';
FLUSH PRIVILEGES;
EOF
	fi
}

# Starts a temporary MariaDB server without networking for initialization.
# Waits until the server responds to pings.
# Globals:
#   DATADIR
#   MARIADB_PID (sets)
# Arguments:
#   None
# Outputs:
#   None
# Returns:
#   Exits the script if the server fails to start within the timeout.
docker_temp_server_start() {
	mysqld --datadir="$DATADIR" --skip-networking &
	MARIADB_PID=$!

	local started=0
	local i
	for i in {30..0}; do
		if mariadb-admin ping --silent; then
			started=1
			break
		fi
		sleep 1
	done

	if [ "$started" = 0 ]; then
		mysql_error "Unable to start temporary server."
	fi
}

# Stops the temporary MariaDB server and waits for the process to exit.
# Globals:
#   MARIADB_PID
# Arguments:
#   None
# Outputs:
#   None
docker_temp_server_stop() {
	kill "$MARIADB_PID"
	wait "$MARIADB_PID"
}

# Orchestrates the entire initialization process for a fresh MariaDB volume.
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   Writes progress and status messages to stdout.
docker_mariadb_init() {
	docker_verify_minimum_env

	docker_init_database_dir

	mysql_note "Starting temporary server"
	docker_temp_server_start
	mysql_note "Temporary server started."

	docker_setup_db

	mysql_note "Stopping temporary server"
	docker_temp_server_stop
	mysql_note "Temporary server stopped."

	echo 
	mysql_note "MariaDB init process done. Ready for start up."
	echo 
}

# Main entrypoint function.
# Globals:
#   DATADIR
# Arguments:
#   $@: The command and arguments to execute after initialization.
# Outputs:
#   Writes entrypoint start message to stdout.
_main() {
	if [ -z "$1" ]; then
		set -- mysqld "$@"
	fi

	if [ "${1:0:1}" = '-' ]; then
		set -- mysqld "$@"
	fi

	mysql_note "Entrypoint script for MariaDB Server started."
	docker_setup_env

	if [ "$(id -u)" = "0" ]; then
		mysql_note "Switching to dedicated user 'mysql'"
		exec gosu mysql "${BASH_SOURCE[0]}" "$@"
	fi

	if [ ! -d "$DATADIR/mysql" ]; then
		docker_mariadb_init
	fi

	exec "$@"
}

_main "$@"
