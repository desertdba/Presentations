/*------------------------------------ 
Delete Double INSERT with TRUNCATE
------------------------------------*/
/*
Setup
*/
USE DMLTest;

DROP TABLE IF EXISTS DoubleInsert, DoubleInsertNew;
GO

-- Create a table with a check constraint, then INSERT 1,000,000 records
CREATE TABLE DoubleInsert (Id int IDENTITY (1,1) PRIMARY KEY CLUSTERED, UpdateDate datetime2, SomeText varchar(100));

INSERT DoubleInsert WITH (TABLOCK) (UpdateDate, SomeText)
SELECT UpdateDate, REPLICATE('ABCDE',20)
FROM OneMillionRows;

SET STATISTICS IO ON;






/*
First example
*/
-- DELETE 90% of the table
DECLARE @Start as datetime2 = SYSDATETIME();

DELETE
FROM DoubleInsert
WHERE Id > 100000; 

SELECT CAST(DATEDIFF(ms, @Start, SYSDATETIME())/1000.000 as decimal(5,3)) as 'DurationInSeconds';

-- Over 150,000 logical page reads for DoubleInsert







/*
Cleanup
*/
SET STATISTICS IO OFF;

-- Let's reset the table to 1,000,000 records
TRUNCATE TABLE DoubleInsert;

INSERT DoubleInsert WITH (TABLOCK) (UpdateDate, SomeText)
SELECT UpdateDate, REPLICATE('ABCDE',20)
FROM OneMillionRows;

SET STATISTICS IO ON;
GO
CHECKPOINT;







/*
Second example
*/
-- Let's try creating a new table, INSERT only what we want to keep, then rename the tables
DECLARE @Start as datetime2 = SYSDATETIME();

CREATE TABLE DoubleInsertNew (Id int PRIMARY KEY CLUSTERED, UpdateDate datetime2, SomeText varchar(200));

INSERT DoubleInsertNew WITH (TABLOCK) (Id, UpdateDate, SomeText)
SELECT Id, UpdateDate, SomeText
FROM DoubleInsert
WHERE Id <= 100000;
-- You can probably guess this has less logical reads

-- Now we TRUNCATE the original table and add back what we need
TRUNCATE TABLE DoubleInsert;

SET IDENTITY_INSERT DoubleInsert ON;

INSERT DoubleInsert WITH (TABLOCK) (Id, UpdateDate, SomeText)
SELECT Id, UpdateDate, SomeText
FROM DoubleInsertNew;
-- Look ma, less logical reads!

SET IDENTITY_INSERT DoubleInsert OFF;

SELECT CAST(DATEDIFF(ms, @Start, SYSDATETIME())/1000.000 as decimal(5,3)) as 'DurationInSeconds';

-- Just over 1500 logical page reads for DoubleInsert and DoubleInsertNew
