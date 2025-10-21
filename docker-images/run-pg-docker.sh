#!sh

# sanity checks and defaults

# Define the DOCKER_HOST environment variable for the Docker Desktop socket
# This is a direct path to the socket on a Linux system running Docker Desktop
DOCKER_HOST_SOCK="unix:///home/arturop/.docker/desktop/docker.sock"

# if running as root, no need to use sudo
if [ "$UID" = "0" ]; then
    SUDO=""
else
    SUDO=$(which sudo 2>/dev/null)
    if [ ! -x "$SUDO" ]; then
        echo "\`sudo\` is required to run the script!"
        exit 1
    fi
fi

# check for docker-compose (v1 with hyphen)
DOCKER_COMPOSE=$(which docker-compose 2>/dev/null)
if [ ! -x "$DOCKER_COMPOSE" ]; then

    # try to run docker compose (v2 without hyphen)
    # Using 'version' to check existence without needing a daemon connection.
    docker compose version > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        DOCKER_COMPOSE="docker compose"
        echo "Using \`docker compose\`"
    else
        echo "\`docker-compose\` not installed, cannot proceed"
        exit 2
    fi
fi

DOCKER_IMAGE_TO_RUN=$1

# if not an image specified, use the default
if [ -z "$DOCKER_IMAGE_TO_RUN" ]; then
    DOCKER_IMAGE_TO_RUN=standalone
    echo "Using default image <$DOCKER_IMAGE_TO_RUN>"
fi

if [ ! -d $DOCKER_IMAGE_TO_RUN ]; then
    echo "Cannot find docker image directory <$DOCKER_IMAGE_TO_RUN>"
    exit 1
fi


cd $DOCKER_IMAGE_TO_RUN

# check there are the files to run the image
if [ ! -f "docker-compose.yml" ]; then
    echo "Cannot find file 'docker-compose.yml'"
    exit 3
fi

if [ ! -f "Dockerfile" ]; then
    echo "Dockerfile is missing"
    exit 4
fi

# --- CORE FIX APPLIED HERE: Using DOCKER_HOST ---
# Build the container
DOCKER_CONTAINER_NAME=${DOCKER_IMAGE_TO_RUN}_learn_postgresql_1
$SUDO DOCKER_HOST="$DOCKER_HOST_SOCK" $DOCKER_COMPOSE build --force-rm --no-cache
$SUDO DOCKER_HOST="$DOCKER_HOST_SOCK" $DOCKER_COMPOSE up -d --remove-orphans


if [ $? -ne 0 ]; then
    echo "Cannot start the container $DOCKER_CONTAINER_NAME"
    exit 10
fi


# Get the DOCKER_ID
DOCKER_ID=$($SUDO DOCKER_HOST="$DOCKER_HOST_SOCK" docker ps -qf "name=$DOCKER_CONTAINER_NAME" | awk '{print $1;}' )


SECS=5
echo "Waiting $SECS secs for the container <$DOCKER_CONTAINER_NAME> -> <$DOCKER_ID> to complete starting up..."
sleep $SECS

if [ "$DOCKER_CONTAINER_NAME" = "chapter9_learn_postgresql_1" ]; then
        echo "chown on tablespaces directories"
        $SUDO DOCKER_HOST="$DOCKER_HOST_SOCK" docker exec $DOCKER_CONTAINER_NAME chown -R postgres:postgres /data
fi

# Launch interactive shell
$SUDO DOCKER_HOST="$DOCKER_HOST_SOCK" docker exec --user postgres --workdir /var/lib/postgresql -it  $DOCKER_ID /bin/bash

if [ $? -ne 0 ]; then
    echo "Getting the logs to understand what went wrong"
    $SUDO DOCKER_HOST="$DOCKER_HOST_SOCK" docker logs $DOCKER_CONTAINER_NAME
fi

echo "Stopping the container $DOCKER_CONTAINER_NAME"
$SUDO DOCKER_HOST="$DOCKER_HOST_SOCK" docker stop $DOCKER_CONTAINER_NAME