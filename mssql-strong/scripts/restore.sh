#!/bin/bash

set -e

SEED=${SEED:-true}

echo "Restore started: $(date)"

function restoreDatabase() {
	shopt -s nocaseglob

	# NB! The filename is used as the database name
	for backupFile in /$1/*.bak; do
		# Set variables
		filename="${backupFile##*/}"
		databaseName="${filename%%.*}" 
		databaseLog=""$databaseName"_log"

		echo "Restoring: $databaseName"

		if [[ "$databaseName" == "master" ]]; then
			echo "Skipping..."
		else
			databaseFile="$databaseName"

			/opt/mssql-tools/bin/sqlcmd -S "${MSSQL_HOST},${MSSQL_PORT}" -U "$MSSQL_USER" -P "$SA_PASSWORD" \
			-Q 'RESTORE FILELISTONLY FROM DISK = "'"$backupFile"'"' \
			| tr -s ' ' | cut -d ' ' -f 1-2

			MODE="NORECOVERY"
			if [[ ! -f "/$1/$databaseName.trn" ]]; then
				echo "Stand alone transaction log file not found!"
				MODE="RECOVERY"
			fi

			/opt/mssql-tools/bin/sqlcmd -S "${MSSQL_HOST},${MSSQL_PORT}" -U "$MSSQL_USER" -P "$SA_PASSWORD" \
			-Q 'RESTORE DATABASE '"$databaseName"' FROM DISK = "'"$backupFile"'" WITH REPLACE, '"$MODE"', MOVE "'"$databaseFile"'" TO "/var/opt/mssql/data/'"$databaseFile"'.mdf", MOVE "'"$databaseLog"'" TO "/var/opt/mssql/data/'"$databaseLog"'.ldf"'

			if [[ -f "/$1/$databaseName.trn" ]]; then
				echo "Restoring stand alone transaction log file!"

				/opt/mssql-tools/bin/sqlcmd -S "${MSSQL_HOST},${MSSQL_PORT}" -U "$MSSQL_USER" -P "$SA_PASSWORD" \
				-Q 'RESTORE LOG '"$databaseName"' FROM DISK = "'"/$1/$databaseName.trn"'" WITH NORECOVERY'

				/opt/mssql-tools/bin/sqlcmd -S "${MSSQL_HOST},${MSSQL_PORT}" -U "$MSSQL_USER" -P "$SA_PASSWORD" \
				-Q 'RESTORE DATABASE '"$databaseName"' WITH RECOVERY'
			fi
		fi
	done
	echo "Backup files restored"

	# Seed the login roles from the SQL file
	echo "Seeding the login roles from the seed-roles.sql file..."
	# Create and seed the database
	/opt/mssql-tools/bin/sqlcmd -S "${MSSQL_HOST},${MSSQL_PORT}" -U "$MSSQL_USER" -P "$SA_PASSWORD" \
	-i /usr/src/app/db/scripts/seed-roles.sql

	shopt -u nocaseglob
}

if [[ "$(ls -l /initial | grep -iE '.bak' | wc -l)" -ne "0" ]] && [[ ! -f /tmp/app-initialized ]]; then
	# Seed from initial backups
	echo "Seeding the database from the files in the initial directory..."
	restoreDatabase initial
	# Note that the container has been initialized
    touch /tmp/app-initialized
elif [ "$(ls -l /backups | grep -iE '.bak' | wc -l)" -ne "0" ]; then
	# Seed from cron backups
	echo "Seeding the database from the files in the backup directory..."
	restoreDatabase backups
elif [[ "$SEED" == true ]]; then
	# Seed from the SQL file
	echo "Seeding the database from the seed.sql file..."
	# Create and seed the database
	/opt/mssql-tools/bin/sqlcmd -S "${MSSQL_HOST},${MSSQL_PORT}" -U "$MSSQL_USER" -P "$SA_PASSWORD" \
	-i /usr/src/app/db/scripts/seed.sql
else
	echo "No backups found"
fi

# Notify other containers
nc -dlkt $RESTORE_NOTIFY_PORT &
echo "Restore complete: Notifying on port $RESTORE_NOTIFY_PORT"

echo "Restore finished: $(date)"
