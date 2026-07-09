#!/bin/sh

# Fail immediately and loudly when an error occurs
set -euo pipefail

# Read secret. Exit on error.
read_secret() {
	local file_path="$1"
	local var="$2"

	# The secret file env var is not set
	if [ -z "${file_path:-}" ]; then
		echo "Error: The file path variable to secret $var is not set" >&2
		exit 1
	fi

	# The secret file doesn't exist
	if [ ! -f "$file_path" ]; then
		echo "Error: The secret file $file_path doesn't exist" >&2
		exit 1
	fi

	# The secret file exists but not accessible
	if [ ! -r "$file_path" ]; then
		echo "Error: No permission to read the secret file $file_path" >&2
		exit 1
	fi

	# The secret file is empty
	local temp

	temp=$(cat "$file_path")
	if [ -z "$temp" ]; then
		echo "Error: The secret file $file_path is empty" >&2
		exit 1;
	fi

	export "$var"="$temp"
}

read_secret "$MYSQL_PASSWORD_FILE" MYSQL_PASSWORD
read_secret "$MYSQL_ROOT_PASSWORD_FILE" MYSQL_ROOT_PASSWORD

# Create the runtime directory for the Unix socket
mkdir -p /run/mysqld
chown mysql:mysql /run/mysqld

# Check if the database has already been initialized, if not then initialize it
if [ ! -d "/var/lib/mysql/mysql" ]; then

	#initialize the database
	mariadb-install-db --user=mysql --datadir=/var/lib/mysql

	# Start MariaDB server (daemon) temporarily to create users and databases, so no networking needed
	# `&` means running in the background. Otherwise the script would stop here forever, because `mysqld` never exits on its own
	mysqld --user=mysql --skip-networking &

	# Sleep until the server is ready

	timeout=30
	elapsed=0

	until mariadb-admin ping >/dev/null 2>&1
	do
		if [ "$elapsed" -ge "$timeout" ]; then
			echo "Timed out waiting for MariaDB to start"
			exit 1
		fi

		sleep 1
		elapsed=$((elapsed + 1))
	done

	mariadb <<EOF
-- Create the WordPress database
CREATE DATABASE $MYSQL_DATABASE;
-- Create the user: '%' means any host
CREATE USER '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD';
-- Grant all permissions for the database to the user
GRANT ALL PRIVILEGES ON $MYSQL_DATABASE.* TO '$MYSQL_USER'@'%';
-- Set root password to the root database account
ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD';
-- Reload to apply the changes immediately
FLUSH PRIVILEGES;
EOF
	# Stop the temporary server
	mariadb-admin shutdown
fi

# Start the real server. `exec` replaces the shell script process with mysqld, so the main service becomes PID 1
exec mysqld --user=mysql
