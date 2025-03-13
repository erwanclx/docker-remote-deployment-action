#!/bin/bash
set -eu

# Function to execute commands over SSH
execute_ssh() {
  echo "Execute Over SSH: $@"
  ssh -q -t -i "$HOME/.ssh/id_rsa" \
      -o UserKnownHostsFile=/dev/null \
      -o StrictHostKeyChecking=no "$INPUT_REMOTE_DOCKER_HOST" -p "$INPUT_SSH_PORT" "$@"
}

# Validate required inputs
if [ -z "${INPUT_REMOTE_DOCKER_HOST:-}" ]; then
    echo "Input remote_docker_host is required!"
    exit 1
fi

if [ -z "${INPUT_SSH_PUBLIC_KEY:-}" ]; then
    echo "Input ssh_public_key is required!"
    exit 1
fi

if [ -z "${INPUT_SSH_PRIVATE_KEY:-}" ]; then
    echo "Input ssh_private_key is required!"
    exit 1
fi

if [ -z "${INPUT_ARGS:-}" ]; then
    echo "Input input_args is required!"
    exit 1
fi

# Set default values for optional parameters
INPUT_STACK_FILE_NAME=${INPUT_STACK_FILE_NAME:-docker-compose.yml}
INPUT_SSH_PORT=${INPUT_SSH_PORT:-22}

# Configuration variables
STACK_FILE=${INPUT_STACK_FILE_NAME}
DEPLOYMENT_COMMAND_OPTIONS="--host ssh://$INPUT_REMOTE_DOCKER_HOST:$INPUT_SSH_PORT"
DEPLOYMENT_COMMAND="docker-compose -f $STACK_FILE"
SSH_HOST=${INPUT_REMOTE_DOCKER_HOST#*@}

# Setup SSH keys
echo "Registering SSH keys..."
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Store SSH keys
printf '%s\n' "$INPUT_SSH_PRIVATE_KEY" > ~/.ssh/id_rsa
chmod 600 ~/.ssh/id_rsa
printf '%s\n' "$INPUT_SSH_PUBLIC_KEY" > ~/.ssh/id_rsa.pub
chmod 600 ~/.ssh/id_rsa.pub

# Start SSH agent and add key
eval $(ssh-agent)
ssh-add ~/.ssh/id_rsa

# Add host to known hosts
echo "Add known hosts"
ssh-keyscan -p "$INPUT_SSH_PORT" "$SSH_HOST" >> ~/.ssh/known_hosts
ssh-keyscan -p "$INPUT_SSH_PORT" "$SSH_HOST" >> /etc/ssh/ssh_known_hosts

# Set Docker context
echo "Create docker context"
if ! docker context ls | grep -q 'staging'; then
  docker context create staging --docker "host=ssh://$INPUT_REMOTE_DOCKER_HOST:$INPUT_SSH_PORT"
fi
docker context use staging

if [ -n "${INPUT_DOCKER_LOGIN_USER:-}" ] && [ -n "${INPUT_DOCKER_LOGIN_PASSWORD:-}" ]; then 
  if [ -n "${INPUT_DOCKER_LOGIN_REGISTRY:-}" ]; then
    echo "Login to registry: ${INPUT_DOCKER_LOGIN_REGISTRY}"
    docker login -u "$INPUT_DOCKER_LOGIN_USER" -p "$INPUT_DOCKER_LOGIN_PASSWORD" "${INPUT_DOCKER_LOGIN_REGISTRY}"
  else
    echo "Login to default registry"
    docker login -u "$INPUT_DOCKER_LOGIN_USER" -p "$INPUT_DOCKER_LOGIN_PASSWORD"
  fi
fi

# Pull and deploy
echo "Command: ${DEPLOYMENT_COMMAND} pull"
${DEPLOYMENT_COMMAND} ${DEPLOYMENT_COMMAND_OPTIONS} pull

echo "Command: ${DEPLOYMENT_COMMAND} ${INPUT_ARGS}"
${DEPLOYMENT_COMMAND} ${DEPLOYMENT_COMMAND_OPTIONS} ${INPUT_ARGS}

# Cleanup
echo "Remove docker context"
if docker context ls | grep -q 'staging'; then
  docker context rm -f staging
fi