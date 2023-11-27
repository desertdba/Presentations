/*------------------------------------
Accelerated Database Recovery
------------------------------------*/
/*
Setup
*/
USE DMLTest;
GO
ALTER DATABASE DMLTest SET ACCELERATED_DATABASE_RECOVERY = OFF WITH ROLLBACK IMMEDIATE ;
GO

SET NOCOUNT ON;

DROP TABLE IF EXISTS AcceleratedDatabaseRecovery;
GO

-- Create a table with a non-clustered index
CREATE TABLE AcceleratedDatabaseRecovery (Id int PRIMARY KEY CLUSTERED, UpdateDate datetime2);

-- Let's INSERT 1,000,000 records
INSERT AcceleratedDatabaseRecovery WITH (TABLOCK) (Id, UpdateDate)
SELECT Id, UpdateDate
FROM OneMillionRecords
ORDER BY Id;

SET STATISTICS IO ON;
GO
CHECKPOINT
GO
DBCC FREEPROCCACHE;
GO





/*
First example
*/
BEGIN TRANSACTION

-- DELETE all the data
DELETE 
FROM AcceleratedDatabaseRecovery 
WHERE Id > 0


-- ROLLBACK
DECLARE @Start as datetime2 = SYSDATETIME();

ROLLBACK

SELECT CAST(DATEDIFF(ms, @Start, SYSDATETIME())/1000.000 as decimal(5,3)) as 'DurationInSeconds';
-- How many logical reads for DisableIndex with Index ENABLED?

-- Over 2,000,000 log records and over 3,000,000 locks
SELECT COUNT([Current LSN]) as 'LogRecords', SUM(ISNULL([Number of Locks],0)) as 'Locks' FROM fn_dblog(null,null) 








/*
Cleanup
*/
CHECKPOINT;

-- no cheating
DBCC FREEPROCCACHE;







/*
Second example
*/
ALTER DATABASE DMLTest SET ACCELERATED_DATABASE_RECOVERY = ON WITH ROLLBACK IMMEDIATE ;
GO
TRUNCATE TABLE AcceleratedDatabaseRecovery
GO

-- Let's INSERT 1,000,000 records
INSERT AcceleratedDatabaseRecovery WITH (TABLOCK) (Id, UpdateDate)
SELECT Id, UpdateDate
FROM OneMillionRecords
ORDER BY Id;

SET STATISTICS IO ON;
GO
CHECKPOINT
GO
DBCC FREEPROCCACHE;
GO


-- DELETE all the data
BEGIN TRANSACTION

DELETE 
FROM AcceleratedDatabaseRecovery 
WHERE Id > 0


-- ROLLBACK
DECLARE @Start as datetime2 = SYSDATETIME();

ROLLBACK

SELECT CAST(DATEDIFF(ms, @Start, SYSDATETIME())/1000.000 as decimal(5,3)) as 'DurationInSeconds';
-- How many logical reads for DisableIndex with Index ENABLED?

-- Still over 2,000,000 log records, but over 1,000,000 less locks
SELECT COUNT([Current LSN]) as 'LogRecords', SUM(ISNULL([Number of Locks],0)) as 'Locks' FROM fn_dblog(null,null) 
