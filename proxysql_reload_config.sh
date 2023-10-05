#!/usr/bin/env bash

set -e

MYCNF=".my_proxysql.cnf"

MYSQL=(mysql --defaults-file="$MYCNF")

CONFIG_ITEMS=(
  "MYSQL USERS"
  "MYSQL SERVERS"
  "MYSQL QUERY RULES"
  "MYSQL VARIABLES"
  "ADMIN VARIABLES"
)

refresh_config() {
  # Remove in-memory values so when refreshing from config we get idempotent results that can be
  # then moved to runtime (and disk), making config file the single source of truth
  "${MYSQL[@]}" -e "DELETE FROM mysql_users"
  "${MYSQL[@]}" -e "DELETE FROM mysql_servers"
  "${MYSQL[@]}" -e "DELETE FROM mysql_query_rules"
  for item in "${CONFIG_ITEMS[@]}"; do
    "${MYSQL[@]}" -e "LOAD $item FROM CONFIG"
    "${MYSQL[@]}" -e "LOAD $item FROM MEMORY"
    "${MYSQL[@]}" -e "SAVE $item TO DISK"
  done
}

if ! [ -f "$MYCNF" ]; then
  echo "Can't find MySQL credentials file in $MYCNF"
  echo "Aborting with error in 10 seconds"
  sleep 10
  exit 1
fi

refresh_config
