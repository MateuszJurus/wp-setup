#!/bin/sh

run_in_container() {
    docker exec wordpress sh -c "$1"
}

# Start Docker containers defined in wordpress.yml
docker-compose -f wordpress.yml up -d

# Download WP-CLI.phar
run_in_container 'curl -o /usr/local/bin/wp-cli.phar https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar'

# Set executable permissions
run_in_container 'chmod +x /usr/local/bin/wp-cli.phar'

# Move to /usr/local/bin/wp for global access
run_in_container 'mv /usr/local/bin/wp-cli.phar /usr/local/bin/wp'

# Install WP instance
run_in_container 'wp core install --url=localhost:8080 --title=Example --admin_user=supervisor --admin_password=strongpassword --admin_email=info@example.com --allow-root'


# Stop and remove containers when done (optional)
# docker-compose -f wordpress.yml down
