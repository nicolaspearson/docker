-- Usage: docker exec -it dev-mssql /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'Masterkey1433' -i /usr/src/app/db/scripts/backup.sql

DECLARE @name VARCHAR(50) -- database name  
DECLARE @path VARCHAR(256) -- path for backup files  
DECLARE @fileName VARCHAR(256) -- filename for backup  
DECLARE @fileDate VARCHAR(20) -- used for file name
 
-- specify database backup directory
SET @path = '/backups/'

SELECT @fileDate = CONVERT(VARCHAR(20),GETDATE(),112) + REPLACE(CONVERT(VARCHAR(20),GETDATE(),108),':','')
 
DECLARE db_cursor CURSOR READ_ONLY FOR  
SELECT name 
FROM master.dbo.sysdatabases 
WHERE name NOT IN ('master', 'model', 'msdb', 'tempdb')  -- exclude these databases
 
OPEN db_cursor   
FETCH NEXT FROM db_cursor INTO @name   
 
WHILE @@FETCH_STATUS = 0   
BEGIN   
   SET @fileName = @path + @name + '.' + @fileDate + '.bak'
   BACKUP DATABASE @name TO DISK = @fileName WITH FORMAT
   
   FETCH NEXT FROM db_cursor INTO @name   
END
 
CLOSE db_cursor   
DEALLOCATE db_cursor
