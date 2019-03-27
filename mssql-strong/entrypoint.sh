#!/bin/bash

set -e

CURRENT_USER="$(whoami)"
echo "User: $CURRENT_USER"
if [[ "$CURRENT_USER" == "root" ]]; then
	update-rc.d cron defaults
	service cron start
fi

CRON_SCHEDULE=${CRON_SCHEDULE:-0 0 * * *}
MSSQL_USER=${MSSQL_USER:-sa}
MSSQL_HOST=${MSSQL_HOST:-localhost}
MSSQL_PORT=${MSSQL_PORT:-1433}
SA_PASSWORD=${SA_PASSWORD:-Masterkey1433}
RESTORE_NOTIFY_PORT=${RESTORE_NOTIFY_PORT:-1439}
BACKUP=${BACKUP:-true}
RESTORE=${RESTORE:-true}

function startDatabase() {
  /opt/mssql/bin/sqlservr &
  # Wait for SQL Server to start
  echo "Connecting to SQL Server"
  until $(nc -z $MSSQL_HOST $MSSQL_PORT); do
    printf '.'
    sleep 2
  done
    sleep 5
  echo "Connected to SQL Server"
}

function stopDatabase() {
	kill $(ps aux | grep 'sqlservr' | awk '{print $2}')
	echo "Waiting 10 seconds for shutdown..."
	sleep 10
}

# Start the database
startDatabase

if ([[ "$(ls -l /backups | grep -iE '.bak' | wc -l)" -ne "0" ]] || [[ "$(ls -l /initial | grep -iE '.bak' | wc -l)" -ne "0" ]] || [[ ! -f /tmp/app-initialized ]]) && [[ "$RESTORE" == true ]]; then
  # Restore backups
  (. /usr/src/app/scripts/restore.sh)
else 
  # Notify other containers
  nc -dlkt $RESTORE_NOTIFY_PORT &
  echo "Init complete: Notifying on port $RESTORE_NOTIFY_PORT"
fi

# Schedule backups
if [[ "$BACKUP" == true ]]; then
  LOGFIFO='/backup-logs/cron.fifo'
  if [[ ! -e "$LOGFIFO" ]]; then
      mkfifo "$LOGFIFO"
  fi
  
  CRON_ENV="MSSQL_USER='$MSSQL_USER'\nMSSQL_HOST='$MSSQL_HOST'\nMSSQL_PORT='$MSSQL_PORT'\nSA_PASSWORD='$SA_PASSWORD'"
  
  if [ ! -z "$DELETE_OLDER_THAN" ]; then
      CRON_ENV="$CRON_ENV\nDELETE_OLDER_THAN='$DELETE_OLDER_THAN'"
  fi
  
  echo -e "$CRON_ENV\n$CRON_SCHEDULE /usr/src/app/scripts/backup.sh > $LOGFIFO 2>&1" | crontab -
  crontab -l
  tail -f "$LOGFIFO" &
else
  echo "Skipping backup..."
fi

# Backup and shutdown the database
cleanup() {
    echo "Container stopped, performing cleanup..."
	echo "" | crontab -
	if [[ "$BACKUP" == true ]]; then
		echo "Creating database backup..."
		(. /usr/src/app/scripts/backup.sh)
	fi
	echo "Shutting down sql server..."
	stopDatabase
}

# Trap SIGTERM
trap 'cleanup' SIGTERM

exec tail -f /var/opt/mssql/log/errorlog &

# Wait
wait $!