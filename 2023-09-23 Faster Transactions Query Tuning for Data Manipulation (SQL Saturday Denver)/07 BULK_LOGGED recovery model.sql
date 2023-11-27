/*------------------------------------
BULK_LOGGED Recovery Model 
------------------------------------*/
USE DMLTest;

SET STATISTICS IO OFF;

-- Backup to NUL (since we're in SIMPLE)
BACKUP DATABASE DMLTest TO DISK = 'NUL';

-- drop table RecoveryModel
DROP TABLE IF EXISTS RecoveryModel;
GO
CREATE TABLE RecoveryModel (Id int IDENTITY (1,1), UpdateDate datetime2, SomeText varchar(100));

-- Let's go FULL
ALTER DATABASE DMLTest SET RECOVERY FULL;

-- clear the transaction log
CHECKPOINT;

-- Backup to NUL (since we're in FULL now)
BACKUP DATABASE DMLTest TO DISK = 'NUL';









/*
First example
*/
-- INSERT 1,000,000 records
DECLARE @Start as datetime2 = SYSDATETIME();

-- INSERT 1,000,000 records in FULL
INSERT MinLogINSERT (UpdateDate, SomeText)
SELECT UpdateDate, REPLICATE('ABCDE',20)
FROM OneMillionRecords;

SELECT CAST(DATEDIFF(ms, @Start, SYSDATETIME())/1000.000 as decimal(5,3)) as 'DurationInSeconds';
-- How long did that take?







/*
Cleanup and Backup
*/
-- clear the memory
DBCC DROPCLEANBUFFERS;

-- clear the table
TRUNCATE TABLE RecoveryModel;

-- Backup LOG to NUL (since we're in FULL)
BACKUP LOG DMLTest TO DISK = 'NUL';

-- Let's try BULK_LOGGED
ALTER DATABASE DMLTest SET RECOVERY BULK_LOGGED;
GO








/*
Second example
*/
-- INSERT 1,000,000 records with TABLOCK
DECLARE @Start as datetime2 = SYSDATETIME();

INSERT RecoveryModel WITH (TABLOCK) (UpdateDate, SomeText)
SELECT UpdateDate, REPLICATE('ABCDE',20)
FROM OneMillionRecords;

SELECT CAST(DATEDIFF(ms, @Start, SYSDATETIME())/1000.000 as decimal(5,3)) as 'DurationInSeconds';
-- Does this seem faster?






/*
Backup and Reset to SIMPLE (for other scripts)
*/
-- Back to FULL
ALTER DATABASE DMLTest SET RECOVERY FULL;

-- Back up the log
BACKUP LOG DMLTest TO DISK = 'NUL';

-- Back to Simple
ALTER DATABASE DMLTest SET RECOVERY SIMPLE;
