/*------------------------------------
Disable Indexes
------------------------------------*/
/*
Setup
*/
USE DMLTest;

SET NOCOUNT ON;

DROP TABLE IF EXISTS DisableIndex;
GO

-- Create a table with a non-clustered index
CREATE TABLE DisableIndex (Id int IDENTITY (1,1) PRIMARY KEY CLUSTERED, UpdateDate datetime2);

CREATE NONCLUSTERED INDEX NC01_DisableIndex ON DisableIndex (UpdateDate);  

SET STATISTICS IO ON;






/*
First example
*/
DECLARE @Start as datetime2 = SYSDATETIME();

-- INSERT 1,000,000 records with the Non-Clustered Index ENABLED
INSERT DisableIndex (UpdateDate)
SELECT UpdateDate
FROM OneMillionRecords

SELECT CAST(DATEDIFF(ms, @Start, SYSDATETIME())/1000.000 as decimal(5,3)) as 'DurationInSeconds';
-- How many logical reads for DisableIndex with Index ENABLED?


-- check the number of log records and the number of locks
-- SELECT COUNT([Current LSN]) as 'LogRecords', SUM(ISNULL([Number of Locks],0)) as 'Locks' FROM fn_dblog(null,null) 








/*
Cleanup
*/
TRUNCATE TABLE DisableIndex

CHECKPOINT;

-- no cheating
DBCC FREEPROCCACHE;







/*
Second example
*/
DECLARE @Start as datetime2 = SYSDATETIME();

-- Let's try the UPDATE with the index DISABLED
ALTER INDEX NC01_DisableIndex ON DisableIndex DISABLE;

INSERT DisableIndex (UpdateDate)
SELECT UpdateDate
FROM OneMillionRecords

-- ...then REBUILD the non-clustered index
ALTER INDEX NC01_DisableIndex ON DisableIndex REBUILD;

SELECT CAST(DATEDIFF(ms, @Start, SYSDATETIME())/1000.000 as decimal(5,3)) as 'DurationInSeconds';
-- How many logical reads for DisableIndex with Index DISABLED?


-- check the number of log records and the number of locks
-- SELECT COUNT([Current LSN]) as 'LogRecords', SUM(ISNULL([Number of Locks],0)) as 'Locks' FROM fn_dblog(null,null) 

