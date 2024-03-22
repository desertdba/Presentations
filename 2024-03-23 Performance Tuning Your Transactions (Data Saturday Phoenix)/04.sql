/*------------------------------------ 
Explicit transactions 
------------------------------------*/
/*
Setup
*/
USE DMLTest;

DROP TABLE IF EXISTS ExplicitTransactions;
GO

SET NOCOUNT ON;
SET STATISTICS IO OFF;

-- create a table with 100,000 rows
CREATE TABLE ExplicitTransactions (Id int IDENTITY (1,1) PRIMARY KEY CLUSTERED, UpdateDate datetime2);

INSERT ExplicitTransactions (UpdateDate)
SELECT TOP 100000 UpdateDate
FROM OneMillionRows
ORDER BY Id;


-- CREATE stored procedure used in testing
CREATE OR ALTER PROCEDURE usp_UpdateDate
	@Id int
AS

SET NOCOUNT ON;

DECLARE @Start as datetime2 = SYSDATETIME();

-- UPDATE the UpdateDate for any EVEN Ids
IF (@id % 2) = 0
		UPDATE ExplicitTransactions
		SET UpdateDate = @Start
		WHERE Id = @id;



-- clear the transaction log
CHECKPOINT;
GO
SELECT COUNT(*) as TransactionLogRows FROM fn_dblog(null,null)





/*
First example
*/
-- UPDATE any EVEN Ids in the first 20,000 records with Autocommit (default)
DECLARE @Start as datetime2 = SYSDATETIME();

DECLARE @id int =1

WHILE @id <= 20000 BEGIN

	EXEC usp_UpdateDate @Id = @id

	SET @id += 1

	END;

SELECT CAST(DATEDIFF(ms, @Start, SYSDATETIME())/1000.000 as decimal(5,3)) as 'DurationInSeconds';

-- check the 30,000+ records in the transaction log
SELECT COUNT(*) as TransactionLogRecords FROM fn_dblog(null,null);


-- note LOP_BEGIN_XACT, LOP_MODIFY_ROW, LOP_COMMIT_XACT for each UPDATE
SELECT * FROM fn_dblog(null,null) ORDER BY [Current LSN] DESC;








/*
Cleanup
*/
-- clear the transaction log
CHECKPOINT;
GO
SELECT COUNT(*) FROM fn_dblog(null,null);





/*
Second example
*/
-- UPDATE any EVEN Ids in the next 20,000 records, but with an Explicit Transaction
DECLARE @Start as datetime2 = SYSDATETIME();

DECLARE @id int = 20001

BEGIN TRAN	-- <-- BEGIN Explicit Transaction

WHILE @id <= 40000 BEGIN

	EXEC usp_UpdateDate @Id = @id

	SET @id += 1

	END;

COMMIT;	-- <-- COMMIT Explicit Transaction

SELECT CAST(DATEDIFF(ms, @Start, SYSDATETIME())/1000.000 as decimal(5,3)) as 'DurationInSeconds';

-- check the 10,000 or so rows in the transaction log
SELECT COUNT(*) as TransactionLogRows FROM fn_dblog(null,null);

-- where did all of the LOP_BEGIN_XACTs & LOP_COMMIT_XACTs go?
SELECT * FROM fn_dblog(null,null) ORDER BY [Current LSN] DESC;
