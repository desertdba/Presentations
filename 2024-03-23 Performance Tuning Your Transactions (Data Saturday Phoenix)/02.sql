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

-- Let's INSERT 100,000 records
INSERT DisableIndex (UpdateDate)
SELECT TOP 100000 UpdateDate
FROM OneMillionRows
ORDER BY Id;

SET STATISTICS IO ON;






/*
First example
*/
DECLARE @Start as datetime2 = SYSDATETIME();

-- UPDATE with the Non-Clustered Index ENABLED
UPDATE DisableIndex 
SET UpdateDate = @Start

SELECT CAST(DATEDIFF(ms, @Start, SYSDATETIME())/1000.000 as decimal(5,3)) as 'DurationInSeconds';
-- How many logical reads for DisableIndex with Index ENABLED?

-- Over 400,000 logical page reads for DisableIndex

-- Over 300,000 log records and locks
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
DECLARE @Start as datetime2 = SYSDATETIME();

-- Let's try the UPDATE with the index DISABLED
ALTER INDEX NC01_DisableIndex ON DisableIndex DISABLE;

UPDATE DisableIndex 
SET UpdateDate = @Start

-- ...then REBUILD the non-clustered index
ALTER INDEX NC01_DisableIndex ON DisableIndex REBUILD;

SELECT CAST(DATEDIFF(ms, @Start, SYSDATETIME())/1000.000 as decimal(5,3)) as 'DurationInSeconds';
-- How many logical reads for DisableIndex with Index DISABLED?

-- Less than 300 logical page reads for DisableIndex (we did this twice)

-- Only around 100,000 log records and locks
SELECT COUNT([Current LSN]) as 'LogRecords', SUM(ISNULL([Number of Locks],0)) as 'Locks' FROM fn_dblog(null,null) 

