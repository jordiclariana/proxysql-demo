# Apply changes on config file

## Change config file:

```
mysql --defaults-file=.my_proxysql.cnf -e "SELECT * FROM runtime_global_variables WHERE variable_name='mysql-max_connections'" # Runtime
mysql --defaults-file=.my_proxysql.cnf -e "SELECT * FROM global_variables WHERE variable_name='mysql-max_connections'" # Memory
```

Edit `proxysql.cnf`: change max_connections to 4000

```
docker exec -ti proxysql /bin/bash
sed 's/max_connections=3000/max_connections=4000/' /etc/proxysql.cnf > /tmp/proxysql.cnf; cp /tmp/proxysql.cnf /etc/proxysql.cnf
```

## Check if value changed (it did not):

```
mysql --defaults-file=.my_proxysql.cnf -e "SELECT * FROM runtime_global_variables WHERE variable_name='mysql-max_connections'" # Runtime
mysql --defaults-file=.my_proxysql.cnf -e "SELECT * FROM global_variables WHERE variable_name='mysql-max_connections'" # Memory
```

## Apply change to:

```
mysql --defaults-file=.my_proxysql.cnf -e "LOAD MYSQL VARIABLES FROM CONFIG"
mysql --defaults-file=.my_proxysql.cnf -e "SELECT * FROM runtime_global_variables WHERE variable_name='mysql-max_connections'" # Runtime
mysql --defaults-file=.my_proxysql.cnf -e "SELECT * FROM global_variables WHERE variable_name='mysql-max_connections'" # Memory
```

Only applied on memory

## Apply change to runtime:

```
mysql --defaults-file=.my_proxysql.cnf -e "LOAD MYSQL VARIABLES FROM MEMORY"
mysql --defaults-file=.my_proxysql.cnf -e "SELECT * FROM runtime_global_variables WHERE variable_name='mysql-max_connections'" # Runtime
mysql --defaults-file=.my_proxysql.cnf -e "SELECT * FROM global_variables WHERE variable_name='mysql-max_connections'" # Memory
```

## Restart proxysql:

```
docker-compose restart proxysql
mysql --defaults-file=.my_proxysql.cnf -e "SELECT * FROM runtime_global_variables WHERE variable_name='mysql-max_connections'" # Runtime
mysql --defaults-file=.my_proxysql.cnf -e "SELECT * FROM global_variables WHERE variable_name='mysql-max_connections'" # Memory
```

Changes are not there

## Persist to disk (so next restart it will be there):

```
mysql --defaults-file=.my_proxysql.cnf -e "LOAD MYSQL VARIABLES FROM CONFIG; SAVE MYSQL VARIABLES TO DISK"
docker-compose restart proxysql
mysql --defaults-file=.my_proxysql.cnf -e "SELECT * FROM runtime_global_variables WHERE variable_name='mysql-max_connections'" # Runtime
mysql --defaults-file=.my_proxysql.cnf -e "SELECT * FROM global_variables WHERE variable_name='mysql-max_connections'" # Memory
```

# Demonstrate replication is working

```
mysql --defaults-file=.my_replica1.cnf demo -e 'SELECT postalCode FROM customers WHERE customerNumber=103'
mysql --defaults-file=.my_primary.cnf demo -e 'UPDATE customers SET postalCode=44001 WHERE customerNumber=103'
mysql --defaults-file=.my_replica1.cnf demo -e 'SELECT postalCode FROM customers WHERE customerNumber=103'
```

# Show monitoring

## Instance down

```
watch -n1 "mysql --defaults-file=.my_proxysql.cnf -e 'SELECT * FROM runtime_mysql_servers WHERE hostname='\''mysql-replica-1'\'''\\\\G"
docker-compose stop mysql-replica-1
docker-compose start mysql-replica-1
```

## Replica stopped

```
watch -n1 "mysql --defaults-file=.my_proxysql.cnf -e 'SELECT * FROM runtime_mysql_servers WHERE hostname='\''mysql-replica-1'\'''\\\\G"
mysql --defaults-file=.my_replica1.cnf -e 'STOP SLAVE'
mysql --defaults-file=.my_replica1.cnf -e 'START SLAVE'
```

## Replica lagging

```
watch -n1 "mysql --defaults-file=.my_proxysql.cnf -e 'SELECT * FROM runtime_mysql_servers WHERE hostname='\''mysql-replica-1'\'''\\\\G"
mysql --defaults-file=.my_replica1.cnf demo
```

On replica session:
```
	LOCK TABLE customers READ;
	SELECT postalCode FROM customers WHERE customerNumber=103;
	-- Run update on primary:
	--   mysql --defaults-file=.my_primary.cnf demo -e 'UPDATE customers SET postalCode=44002 WHERE customerNumber=103'
	SHOW SLAVE STATUS\G
	UNLOCK TABLE;
	SELECT postalCode FROM customers WHERE customerNumber=103;
```

