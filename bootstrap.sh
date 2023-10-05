#!/usr/bin/env bash

set -e
#set -x

MYSQL=(mysql --defaults-file=.my_primary.cnf)
DC_UID=$(id -u)
DC_GID=$(id -g)

DC_GID=$DC_GID DC_UID=$DC_UID docker-compose down
rm -fr proxysql/*
sleep 1
DC_GID=$DC_GID DC_UID=$DC_UID docker-compose up -d

echo "Waiting for MySQL servers to be ready"
while ! "${MYSQL[@]}" -e 'show master status' 2>/dev/null | grep -q "^mysql-bin"; do
  sleep 3
done
sleep 3
MASTER_STATUS=$("${MYSQL[@]}" -e 'show master status' 2>/dev/null | grep "^mysql-bin")

MASTER_LOG_FILE=$(awk '{print $1}' <<< "$MASTER_STATUS")
MASTER_LOG_POS=$(awk '{print $2}' <<< "$MASTER_STATUS")

for i in .my_replica1.cnf .my_replica2.cnf; do
  mysql --defaults-file="$i" -e "CHANGE MASTER TO MASTER_HOST='mysql-primary', MASTER_USER='root',
    MASTER_PASSWORD='root', MASTER_LOG_FILE='$MASTER_LOG_FILE',
    MASTER_LOG_POS=$MASTER_LOG_POS" 2>/dev/null
  mysql --defaults-file="$i" -e "START SLAVE" 2>/dev/null
  mysql --defaults-file="$i" -e "SHOW SLAVE STATUS\G" 2>/dev/null
done

for user in 1 2 3; do
  "${MYSQL[@]}" -e "CREATE USER IF NOT EXISTS 'demouser${user}'@'%' IDENTIFIED BY 'demopass${user}'"
  "${MYSQL[@]}" -e "GRANT ALL ON *.* TO 'demouser${user}'@'%'"
done

"${MYSQL[@]}" demo < mysqlsampledatabase.sql 2>/dev/null

cat << EOF
All ready!

MySQL:
  - Primary:
      mysql --defaults-file=.my_primary.cnf
  - Replica 1:
      mysql --defaults-file=.my_replica1.cnf
  - Replica 2:
      mysql --defaults-file=.my_replica2.cnf

ProxySQL:
  - Admin:
      mysql --defaults-file=.my_proxysql.cnf
  - Primary through ProxySQL:
      mysql --defaults-file=.my_proxysql_primary_demouser1.cnf
      mysql --defaults-file=.my_proxysql_primary_demouser2.cnf
      mysql --defaults-file=.my_proxysql_primary_demouser3.cnf
  - Replicas through ProxySQL:
      mysql --defaults-file=.my_proxysql_replicas_demouser1.cnf
      mysql --defaults-file=.my_proxysql_replicas_demouser1.cnf
      mysql --defaults-file=.my_proxysql_replicas_demouser1.cnf
  - Metrics:
      curl -s http://127.0.0.1:6070/metrics

SQL Exporter:
  - Metrics:
      curl -s  http://127.0.0.1:9237/metrics
EOF
