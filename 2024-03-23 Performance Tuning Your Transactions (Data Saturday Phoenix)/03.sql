/*------------------------------------ 
Batching: WHILE with TOP
------------------------------------*/
/*
Setup
*/
USE DMLTest;

DROP TABLE IF EXISTS WHILEwithTOP;
GO

SET NOCOUNT ON;
SET STATISTICS IO OFF;

-- Let's CREATE a table & index, then INSERT 100,000 records
CREATE TABLE WHILEwithTOP (Id int PRIMARY KEY CLUSTERED, UpdateDate datetime2);

-- Let's INSERT 500,000 records
INSERT WHILEwithTOP (Id, UpdateDate)
SELECT TOP 500000 Id, UpdateDate
FROM OneMillionRows
ORDER BY Id;

GO
CHECKPOINT;
GO




/*
First example
*/
-- Let's delete 80% of the records
DECLARE @Start as datetime2 = SYSDATETIME();

DELETE
FROM WHILEwithTOP
WHERE Id > 100000;

SELECT CAST(DATEDIFF(ms, @Start, SYSDATETIME())/1000.000 as decimal(5,3)) as 'DurationInSeconds';

-- Over 400,000 log records and over 800,000 locks
SELECT COUNT([Current LSN]) as 'LogRecords', SUM(ISNULL([Number of Locks],0)) as 'Locks' FROM fn_dblog(null,null) 






/*
Cleanup
*/
TRUNCATE TABLE WHILEwithTOP;

-- Let's INSERT 500,000 records
INSERT WHILEwithTOP (Id, UpdateDate)
SELECT TOP 500000 Id, UpdateDate
FROM OneMillionRows
ORDER BY Id;

GO
CHECKPOINT;
GO







/*
Second example
*/
-- Let's DELETE 80% of the records in detailed 20,000 record batches
DECLARE @Start as datetime2 = SYSDATETIME();

DECLARE
	@BatchIdMin int = 100000
	, @BatchIdMax int
	, @RowCount int = 1

WHILE (@RowCount > 0) BEGIN

	SELECT TOP (20000) @BatchIdMax = Id
	FROM WHILEwithTOP
	WHERE Id > @BatchIdMin
	ORDER BY Id;

	DELETE 
	FROM WHILEwithTOP
	WHERE Id > @BatchIdMin
	 AND Id <= @BatchIdMax;

	SET @RowCount = @@ROWCOUNT;

	SET @BatchIdMin = @BatchIdMax

	END;

SELECT CAST(DATEDIFF(ms, @Start, SYSDATETIME())/1000.000 as decimal(5,3)) as 'DurationInSeconds';

-- Now over 500,000 log records, but less than 700,000 locks
SELECT COUNT([Current LSN]) as 'LogRecords', SUM(ISNULL([Number of Locks],0)) as 'Locks' FROM fn_dblog(null,null) 






