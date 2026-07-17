#!/usr/bin/env bash
# Fresh deployment/update for the Raspberry Pi.
# Run with: curl -fsSL https://raw.githubusercontent.com/vitaluska123/EduTracker/main/scripts/rpi-deploy.sh | sudo bash

set -Eeuo pipefail

REPOSITORY_URL="https://github.com/vitaluska123/EduTracker.git"
BRANCH="main"
INSTALL_DIR="/opt/edutracker"
COMPOSE_PROJECT="edutracker"

if [[ ${EUID} -ne 0 ]]; then
  echo "Run this script with sudo."
  exit 1
fi

command -v git >/dev/null || { echo "Git is not installed."; exit 1; }
command -v docker >/dev/null || { echo "Docker is not installed."; exit 1; }
docker compose version >/dev/null || { echo "Docker Compose v2 is not installed."; exit 1; }

if [[ -d "${INSTALL_DIR}/.git" ]]; then
  CURRENT_REMOTE="$(git -C "${INSTALL_DIR}" remote get-url origin)"
  if [[ "${CURRENT_REMOTE}" != "${REPOSITORY_URL}" && "${CURRENT_REMOTE}" != "git@github.com:vitaluska123/EduTracker.git" ]]; then
    echo "Refusing to overwrite ${INSTALL_DIR}: it belongs to ${CURRENT_REMOTE}."
    exit 1
  fi
  docker compose --project-name "${COMPOSE_PROJECT}" -f "${INSTALL_DIR}/docker-compose.yml" down --remove-orphans --volumes || true
  git -C "${INSTALL_DIR}" fetch --prune origin
  git -C "${INSTALL_DIR}" checkout --force "${BRANCH}"
  git -C "${INSTALL_DIR}" reset --hard "origin/${BRANCH}"
  git -C "${INSTALL_DIR}" clean -ffdx
elif [[ -e "${INSTALL_DIR}" ]]; then
  echo "Refusing to overwrite non-Git directory ${INSTALL_DIR}."
  exit 1
else
  git clone --branch "${BRANCH}" --depth 1 "${REPOSITORY_URL}" "${INSTALL_DIR}"
fi

# This removes only stopped containers, unused images, unused networks and unused volumes.
docker system prune --all --force --volumes

cd "${INSTALL_DIR}"
docker compose --project-name "${COMPOSE_PROJECT}" build --no-cache
docker compose --project-name "${COMPOSE_PROJECT}" up --detach --force-recreate

echo "Deployment complete. Running containers:"
docker compose --project-name "${COMPOSE_PROJECT}" ps
