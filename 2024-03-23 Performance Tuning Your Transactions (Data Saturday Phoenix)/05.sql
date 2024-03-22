/*------------------------------------ 
Minimally Logged INSERT
------------------------------------*/
/*
Setup
*/
USE DMLTest;

DROP TABLE IF EXISTS MinLogINSERT;
GO

CREATE TABLE MinLogINSERT (Id int IDENTITY (1,1), UpdateDate datetime2, SomeText varchar(100));

SET STATISTICS IO OFF;




/*
First example
*/
-- INSERT 1,000,000 records
DECLARE @Start as datetime2 = SYSDATETIME();

INSERT MinLogINSERT (UpdateDate, SomeText)
SELECT UpdateDate, REPLICATE('ABCDE',20)
FROM OneMillionRows;

SELECT CAST(DATEDIFF(ms, @Start, SYSDATETIME())/1000.000 as decimal(5,3)) as 'DurationInSeconds';


-- Now over 1,000,000 log records and locks
SELECT COUNT([Current LSN]) as 'LogRecords', SUM(ISNULL([Number of Locks],0)) as 'Locks' FROM fn_dblog(null,null) 






/*
Cleanup
*/
-- no cheating
DBCC FREEPROCCACHE;

-- clear the table
TRUNCATE TABLE MinLogINSERT;

-- clear the transaction log
CHECKPOINT;






/*
Second example
*/
-- INSERT 1,000,000 records with TABLOCK
DECLARE @Start as datetime2 = SYSDATETIME();

INSERT MinLogINSERT WITH (TABLOCK) (UpdateDate, SomeText)
SELECT UpdateDate, REPLICATE('ABCDE',20)
FROM OneMillionRows;

SELECT CAST(DATEDIFF(ms, @Start, SYSDATETIME())/1000.000 as decimal(5,3)) as 'DurationInSeconds';



-- Now less than 30,000 log records and 5,000 locks
SELECT COUNT([Current LSN]) as 'LogRecords', SUM(ISNULL([Number of Locks],0)) as 'Locks' FROM fn_dblog(null,null) 




