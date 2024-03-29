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
FROM OneMillionRecords
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







/*
Cleanup
*/
TRUNCATE TABLE WHILEwithTOP;

-- Let's INSERT 500,000 records
INSERT WHILEwithTOP (Id, UpdateDate)
SELECT TOP 500000 Id, UpdateDate
FROM OneMillionRecords
ORDER BY Id;

GO
CHECKPOINT;
GO







/*
Second example
*/
-- Let's DELETE 80% of the records in detailed 50,000 record batches
DECLARE @Start as datetime2 = SYSDATETIME();

DECLARE
	@BatchIdMin int = 100000
	, @BatchIdMax int
	, @RowCount int = 1

WHILE (@RowCount > 0) BEGIN

	SELECT TOP (50000) @BatchIdMax = Id
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




/*
Cleanup
*/
TRUNCATE TABLE WHILEwithTOP;

-- Let's INSERT 500,000 records
INSERT WHILEwithTOP (Id, UpdateDate)
SELECT TOP 500000 Id, UpdateDate
FROM OneMillionRecords
ORDER BY Id;

GO
CHECKPOINT;
GO




/*
Third example with view
*/
DROP VIEW IF EXISTS dbo.WHILEwithTOP_DELETE;
GO
CREATE VIEW dbo.WHILEwithTOP_DELETE AS
    SELECT TOP 50000 *
    FROM dbo.WHILEwithTOP
	WHERE Id > 100000
    ORDER BY Id;
GO

DECLARE @Start as datetime2 = SYSDATETIME();

DECLARE @RowCount int = 1;

WHILE (@RowCount > 0) BEGIN
	DELETE dbo.WHILEwithTOP_DELETE
	WHERE Id > 100000;

	SET @RowCount = @@ROWCOUNT;

	END;

SELECT CAST(DATEDIFF(ms, @Start, SYSDATETIME())/1000.000 as decimal(5,3)) as 'DurationInSeconds';

