# Docker MSSQL Strong

This repository contains docker files to setup MSSQL using [microsoft-mssql-server](https://hub.docker.com/_/microsoft-mssql-server) as base, it automates the execution of database scripts to create database tables and seed data. Additionally database backups and restores are integrated, you can read more about this process [below](#backup_and_restore).

### Getting Started

1.  Install [docker](https://docs.docker.com/install/)
2.  Install [docker compose](https://docs.docker.com/compose/install/)
3.  Run `docker-compose up` from your terminal

### Build Image

To build the image execute `docker build --rm -t mssql/strong/2017:1.0 .` / `docker-compose up --build`

### Environment Variables

| Variable              | Required? | Default      | Description                                                                                   |
| --------------------- | :-------- | :----------- | :-------------------------------------------------------------------------------------------- |
| `ACCEPT_EULA`         | Required  | Y            | Accept Microsoft's license agreement                                                          |
| `MSSQL_PID`           | Required  | Express      | The MSSQL database variant                                                                    |
| `SA_PASSWORD`         | Required  | `None`       | The password for accessing the database                                                       |
| `MSSQL_USER`          | Required  | mssql        | The user for accessing the database                                                           |
| `MSSQL_HOST`          | Optional  | localhost    | The hostname of the database                                                                  |
| `MSSQL_PORT`          | Optional  | `1433`       | The port for the database                                                                     |
| `RESTORE_NOTIFY_PORT` | Optional  | 1439         | The port that the restore process will use to notify other containers on completion           |
| `BACKUP`              | Optional  | true         | Whether or not to perform backups                                                             |
| `RESTORE`             | Optional  | true         | Whether or not to perform restores                                                            |
| `CRON_SCHEDULE`       | Required  | 0 0 \* \* \* | The cron schedule at which to run the backup process                                          |
| `DELETE_OLDER_THAN`   | Optional  | `None`       | Optionally, delete files older than `DELETE_OLDER_THAN` minutes. Do not include `+` or `-`.   |
| `SEED`                | Optional  | true         | Fail over to the default seed.sql script if the `initial`, and `backup` directories are empty |

### Backup and Restore

The backup process is invoked via a cronjob, the `BACKUP` environment variable must be set to `true`, and you need to add a volume for storing backups, e.g. `./backups:/backups`. The `CRON_SCHEDULE` environment variable should be used to schedule backups as required. The cronjob executes the `scripts/backup.sh` shell script, which uses the `db/scripts/backup.sql` SQL script to create full database backups of EVERY user database. The backups are in standard MSSQL `.bak` format, and placed in the `db/backups` directory. This directory is a volume which is mapped to the `/backups` folder of the container. The `DELETE_OLDER_THAN` environment variable can be used to delete old backups by specifying the oldest age in minutes. If `BACKUP` is set to `true`, database backups will also be automatically created every time the container is gracefully stopped, e.g. using `docker-compose stop`. You must also specify a large enough `stop_grace_period` in your `docker-compose.yml` in order to allow enough time for the backup process to complete before the container is killed.

The restore process is kicked off after the container and database have been started. The `RESTORE` environment variable must be set to `true` to enable restoration. The restore process is multi-layered. When the container is started for the first time it will attempt to restore files from the `initial` directory. It will only seed once from this directory, thereafter the `backup` directory is used. If, on first start both the `initial` and `backup` directories are empty, and the `SEED` environment variable is set to `true`, the SQL from `db/scripts/seed.sql` will be used to create the required database tables. The `initial` directory is a volume and needs to be added to your `docker-compose.yml` in order to seed from this source, e.g. `initial:/initial`. The `RESTORE_NOTIFY_PORT` is used to notify other containers that the restore has successfully completed and the database is up and accepting connections. This is important when you have other containers that rely on the database.

### Docker Compose Sample

See the `docker-compose.yml` file in the root directory.

### Contribution Guidelines

Do not commit directly to master, create a feature branch, and submit a pull request.
