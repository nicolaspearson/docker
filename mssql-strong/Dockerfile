FROM mcr.microsoft.com/mssql/server:2017-latest

# Install netcat and clean up APT when done
RUN apt-get update && apt-get install -y cron apt-utils netcat-openbsd \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src/app
COPY . /usr/src/app

# Make scripts executable
RUN chmod +x /usr/src/app/entrypoint.sh && chmod +x /usr/src/app/scripts/*
RUN mkdir -p /backup-logs && chmod 755 /backup-logs

VOLUME [ "/backups", "/initial" ]

ENTRYPOINT [ "/bin/bash", "./entrypoint.sh" ]

CMD [ "./entrypoint.sh" ]