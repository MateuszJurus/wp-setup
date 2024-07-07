#!/bin/sh

# Color output setup
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Function to run a command inside a Docker container
run_in_container() {
    local command="$1"
    local container="$2"
    
    docker exec "$container" sh -c "$command"
    return $?
}

# Load environment variables from .env file
set -a
. ./.env
set +a

# Function to handle errors
handle_error() {
    local lineno=$1
    local message=$2
    echo -e "${RED}Error on line $lineno: $message${NC}"
    exit 1
}

# Trap errors and call the handle_error function
trap 'handle_error $LINENO "$BASH_COMMAND"' ERR

# Start Docker containers defined in wordpress.yml
docker-compose -f wordpress.yml up -d || handle_error $LINENO "Failed to start Docker containers"

# Download WP-CLI.phar
echo "Installing WP Cli"
run_in_container 'curl -o /usr/local/bin/wp-cli.phar https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar' "$DOCKER_WP_CONTAINER" || handle_error $LINENO "Failed to download WP CLI"

# Set executable permissions
echo "Setting permissions"
run_in_container 'chmod +x /usr/local/bin/wp-cli.phar' "$DOCKER_WP_CONTAINER" || handle_error $LINENO "Failed to set executable permissions"

# Move to /usr/local/bin/wp for global access
echo "Moving files for global access"
run_in_container 'mv /usr/local/bin/wp-cli.phar /usr/local/bin/wp' "$DOCKER_WP_CONTAINER" || handle_error $LINENO "Failed to move WP CLI to /usr/local/bin"

# Wait for the database to be ready
echo "Waiting for the database to be ready"
until run_in_container "mysqladmin ping -h db --silent" "$DOCKER_DB_CONTAINER"; do
    echo "Waiting for the database connection..."
    sleep 1
done

# Install WP instance
echo "Installing WordPress"
run_in_container "wp core install --url=$WP_URL --title=$WP_TITLE --admin_user=$WP_ADMIN_USER --admin_password=$WP_ADMIN_PASSWORD --admin_email=$WP_ADMIN_EMAIL --allow-root" "$DOCKER_WP_CONTAINER" || handle_error $LINENO "Failed to install WordPress"

# Remove default plugins
echo "Uninstalling default plugins"
run_in_container 'wp plugin uninstall --all --allow-root' "$DOCKER_WP_CONTAINER" || handle_error $LINENO "Failed to uninstall default plugins"

# Install GIT
echo "Installing GIT and pulling repo into container"
run_in_container 'apt-get update' "$DOCKER_WP_CONTAINER" || handle_error $LINENO "Failed to update apt-get"
run_in_container 'apt-get install git -y' "$DOCKER_WP_CONTAINER" || handle_error $LINENO "Failed to install GIT"
run_in_container 'git clone https://github.com/MateuszJurus/studies.git ./wp-content/themes/studies' "$DOCKER_WP_CONTAINER" || handle_error $LINENO "Failed to clone repo"
run_in_container 'wp theme activate studies --allow-root' "$DOCKER_WP_CONTAINER" || handle_error $LINENO "Failed to activate theme"

# Ready message
echo -e "Your local environment is ready and can be accessed in your browser at ${GREEN}http://$WP_URL${NC}"

