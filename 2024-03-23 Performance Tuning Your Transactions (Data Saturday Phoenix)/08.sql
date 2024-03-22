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

-- Let's INSERT 1,000,000 record...with minimal logging!
INSERT AcceleratedDatabaseRecovery WITH (TABLOCK) (Id, UpdateDate)
SELECT Id, UpdateDate
FROM OneMillionRows
ORDER BY Id;
GO

SET STATISTICS IO OFF;
GO
CHECKPOINT
GO
DBCC FREEPROCCACHE;
GO





/*
First example
*/
BEGIN TRANSACTION

-- UPDATE all the rows
UPDATE AcceleratedDatabaseRecovery
SET UpdateDate = GETDATE()

-- ...then ROLLBACK
DECLARE @Start as datetime2 = SYSDATETIME();

ROLLBACK

SELECT CAST(DATEDIFF(ms, @Start, SYSDATETIME())/1000.000 as decimal(5,3)) as 'DurationInSeconds';


-- Over 2,000,000 log records and locks
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


-- UPDATE all the rows again
BEGIN TRANSACTION

UPDATE AcceleratedDatabaseRecovery
SET UpdateDate = GETDATE()



-- ROLLBACK is now instant
DECLARE @Start as datetime2 = SYSDATETIME();

ROLLBACK

SELECT CAST(DATEDIFF(ms, @Start, SYSDATETIME())/1000.000 as decimal(5,3)) as 'DurationInSeconds';


-- Just over 1,000,000 log records and 1,500,000 locks
SELECT COUNT([Current LSN]) as 'LogRecords', SUM(ISNULL([Number of Locks],0)) as 'Locks' FROM fn_dblog(null,null) 
