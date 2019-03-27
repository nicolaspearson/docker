#!/bin/bash

set -e

echo "Backup started: $(date)"

if [ ! -z "$SA_PASSWORD" ]; then
	echo "Dumping all databases"
	/opt/mssql-tools/bin/sqlcmd -S "${MSSQL_HOST},${MSSQL_PORT}" -U "$MSSQL_USER" -P "$SA_PASSWORD" -i /usr/src/app/db/scripts/backup.sql

	if [[ ! -z "$DELETE_OLDER_THAN" ]] && [[ "$(ls -l /backups | grep -iE '.bak' | wc -l)" -ne "0" ]]; then
		echo "Deleting old backups: $DELETE_OLDER_THAN"
		find /backups/* -mmin "+$DELETE_OLDER_THAN" -exec rm {} \;
	fi
fi

echo "Backup finished: $(date)"
