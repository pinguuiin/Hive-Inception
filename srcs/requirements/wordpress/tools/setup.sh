#!/bin/sh

# Fail immediately and loudly when an error occurs
set -euo pipefail

WP_PATH="/var/www/html"

# Initialize WordPress on the first run
if [ ! -f "$WP_PATH/wp-config.php" ]; then

	echo -n "Downloading WordPress core files...   "
	wp core download \
		--path="$WP_PATH" \
		--allow-root
	echo "Done"

	echo -n "Creating wp-config.php...   "
	wp config create \
		--path="$WP_PATH" \
		--dbname="$MYSQL_DATABASE" \
		--dbuser="$MYSQL_USER" \
		--dbpass="$MYSQL_PASSWORD" \
		--dbhost="$MYSQL_HOST" \
		--allow-root
	echo "Done"

	echo -n "Waiting for MariaDB...   "
	until wp db check \
		--path="$WP_PATH" \
		--allow-root >/dev/null 2>&1
	do
		sleep 2
	done
	echo "Done"

	echo -n "Installing WordPress...   "
	wp core install \
		--path="$WP_PATH" \
		--url="$DOMAIN_NAME" \
		--title="$WP_TITLE" \
		--admin_user="$WP_ADMIN_USER" \
		--admin_password="$WP_ADMIN_PASSWORD" \
		--admin_email="$WP_ADMIN_EMAIL" \
		--allow-root
	echo "Done"

	echo -n "Creating new user...   "
	wp user create \
		"$WP_USER" \
		"$WP_USER_EMAIL" \
		--user_pass="$WP_USER_PASSWORD" \
		--role=author \
		--path="$WP_PATH" \
		--allow-root
	echo "Done"

fi

# Replace the current shell process with the PHP-FPM process and run it in the foreground instead of daemonizing
echo "Starting PHP-FPM..."
exec php-fpm83 -F

