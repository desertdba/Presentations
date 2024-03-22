/*------------------------------------
Clustered Index on a Heap
------------------------------------*/
/*
Setup
*/
USE DMLTest;

DROP TABLE IF EXISTS ClusteredIndexOrHeap;
GO

SET STATISTICS IO ON;

-- Create a table with no clustered index
DROP TABLE IF EXISTS ClusteredIndexOrHeap;
GO
CREATE TABLE ClusteredIndexOrHeap (Id int, UpdateDate datetime2);
GO
CHECKPOINT;
GO
-- no cheating
DBCC FREEPROCCACHE;
GO




/*
First example
*/
DECLARE @Start as datetime2 = SYSDATETIME();

-- INSERT 1,000,000 records into the Heap
INSERT ClusteredIndexOrHeap (Id, UpdateDate)
SELECT Id, UpdateDate
FROM OneMillionRows
ORDER BY Id;

SELECT CAST(DATEDIFF(ms, @Start, SYSDATETIME())/1000.000 as decimal(5,3)) as 'DurationInSeconds';

-- Over 1,000,000 logical page reads for ClusteredIndexOrHeap

-- Over 1,000,000 log records and locks
SELECT COUNT([Current LSN]) as 'LogRecords', SUM(ISNULL([Number of Locks],0)) as 'Locks' FROM fn_dblog(null,null) 






/*
Cleanup
*/
CHECKPOINT;
GO
-- no cheating
DBCC FREEPROCCACHE;
GO
-- Recreate the table with a clustered index
DROP TABLE IF EXISTS ClusteredIndexOrHeap;
GO
CREATE TABLE ClusteredIndexOrHeap (Id int PRIMARY KEY CLUSTERED, UpdateDate datetime2) --, SomeText varchar(100));







/*
Second example
*/
DECLARE @Start as datetime2 = SYSDATETIME();

-- INSERT into table with Clustered Index
INSERT ClusteredIndexOrHeap (Id, UpdateDate)
SELECT Id, UpdateDate
FROM OneMillionRows
ORDER BY Id;

SELECT CAST(DATEDIFF(ms, @Start, SYSDATETIME())/1000.000 as decimal(5,3)) as 'DurationInSeconds';

-- Less than 14,000 logical page reads for ClusteredIndexOrHeap now

-- Less than 32,000 log records and 5000 locks
SELECT COUNT([Current LSN]) as 'LogRecords', SUM(ISNULL([Number of Locks],0)) as 'Locks' FROM fn_dblog(null,null) 


