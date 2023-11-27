/*------------------------------------
	Initial setup
------------------------------------*/
-- create the test database
CREATE DATABASE DMLTest;
GO
ALTER DATABASE DMLTest SET RECOVERY SIMPLE;
GO
USE DMLTest;
GO
SET NOCOUNT ON;

-- create a base table (soon you'll learn ways to do this part faster!)
CREATE TABLE OneMillionRecords (Id int PRIMARY KEY CLUSTERED, UpdateDate datetime2);
GO

-- populate that table with 1,000,000 records
DECLARE @id int =1

WHILE @id <= 1000000 BEGIN

	INSERT OneMillionRecords (Id, UpdateDate)
	SELECT @id, getdate()

	SET @id += 1

	END;
