#!/bin/sh

# Fail immediately and loudly when an error occurs
set -euo pipefail

WP_PATH="/var/www/html"

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
read_secret "$WP_ADMIN_PASSWORD_FILE" WP_ADMIN_PASSWORD
read_secret "$WP_USER_PASSWORD_FILE" WP_USER_PASSWORD


# Download WordPress core file if needed
if [ ! -f "$WP_PATH/wp-load.php" ]; then
	echo "Downloading WordPress core files..."
	wp core download \
		--path="$WP_PATH" \
		--allow-root
fi

# Create config file if needed
if [ ! -f "$WP_PATH/wp-config.php" ]; then
	echo "Creating wp-config.php..."
	wp config create \
		--path="$WP_PATH" \
		--dbname="$MYSQL_DATABASE" \
		--dbuser="$MYSQL_USER" \
		--dbpass="$MYSQL_PASSWORD" \
		--dbhost="$MYSQL_HOST" \
		--skip-check \
		--allow-root
fi

# Wait for MariaDB database to be ready and configured
echo "Waiting for MariaDB database to be ready..."

timeout=60
elapsed=0

until wp db check \
	--path="$WP_PATH" \
	--allow-root >/dev/null 2>&1
do
	if [ "$elapsed" -ge "$timeout" ]; then
		echo "Timed out waiting for MariaDB database to be ready and configured"
		exit 1
	fi

	sleep 2
	elapsed=$((elapsed + 2))
done

# Install WordPress if needed
if ! wp core is-installed --path="$WP_PATH" --allow-root >/dev/null 2>&1; then
	echo "Installing WordPress..."
	wp core install \
		--path="$WP_PATH" \
		--url="$DOMAIN_NAME" \
		--title="$WP_TITLE" \
		--admin_user="$WP_ADMIN_USER" \
		--admin_password="$WP_ADMIN_PASSWORD" \
		--admin_email="$WP_ADMIN_EMAIL" \
		--allow-root
fi

# Create the new user if it is missing
if ! wp user get "$WP_USER" --path="$WP_PATH" --allow-root >/dev/null 2>&1; then
	echo "Creating new user..."
	wp user create \
		"$WP_USER" \
		"$WP_USER_EMAIL" \
		--user_pass="$WP_USER_PASSWORD" \
		--role=author \
		--path="$WP_PATH" \
		--allow-root
fi

# Replace the current shell process with the PHP-FPM process and run it in the foreground instead of daemonizing
echo "Starting PHP-FPM..."
exec php-fpm84 -F

