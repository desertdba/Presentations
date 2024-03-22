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

--DROP TABLE OneMillionRows

-- create a base table
CREATE TABLE OneMillionRows (Id int PRIMARY KEY CLUSTERED, UpdateDate datetime2);
GO

-- populate that table with 1,000,000 records
DECLARE @id int =1

BEGIN TRANSACTION;

WHILE @id <= 1000000 BEGIN

	INSERT OneMillionRows WITH (TABLOCK) (Id, UpdateDate) 
	SELECT @id, getdate()

	SET @id += 1

	END;

COMMIT;

-- SELECT * FROM OneMillionRows