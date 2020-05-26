#!/usr/bin/env bash

NORMAL=$(printf '\033[0m')
BOLD=$(printf '\033[1m')
faint=$(printf '\033[2m')
UNDERLINE=$(printf '\033[4m')
NEGATIVE=$(printf '\033[7m')
RED=$(printf '\033[31m')
GREEN=$(printf '\033[32m')
ORANGE=$(printf '\033[33m')
BLUE=$(printf '\033[34m')
YELLOW=$(printf '\033[93m')
WHITE=$(printf '\033[39m')

function success()
{
  local msg=${1}
  echo "[${BOLD}${GREEN} OK ${NORMAL}] ${msg}"
}

function info()
{
  local msg=${1}
  echo "[${BOLD}${BLUE}INFO${NORMAL}] ${msg}"
}

function warn()
{
  local msg=${1}
  echo "[${BOLD}${ORANGE}WARN${NORMAL}] ${msg}" 2>&1
}

function error()
{
  local msg=${1}
  echo "[${BOLD}${RED}FAIL${NORMAL}] ${msg}"  2>&1
}