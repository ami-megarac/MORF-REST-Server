#!/bin/sh
# Redis unix socket for communication
REDIS_SOCK="/run/redis/redis.sock"
# Check if the DB is initialized with a mandatory key
DBCHECK=`redis-cli -s $REDIS_SOCK GET Redfish:AccountService:ServiceEnabled`
# If not init db
if [ -z $DBCHECK ] ; then
	# Path to read .rcmd files
	FILES=./db_init/*.rcmd
	for f in $FILES
	do
  		redis-cli -s $REDIS_SOCK < $f
	done

	# Let redfish extension add to the service root
	# SERVICE_EXTENSIONS=/usr/local/redfish/extensions/service-root/*.rcmd
	# for ext in $SERVICE_EXTENSIONS
	# do
	#    redis-cli < $ext
	# done
fi