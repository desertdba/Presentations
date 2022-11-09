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

-- create a table with 100,000 records
CREATE TABLE ExplicitTransactions (Id int IDENTITY (1,1) PRIMARY KEY CLUSTERED, UpdateDate datetime2);

INSERT ExplicitTransactions (UpdateDate)
SELECT TOP 100000 UpdateDate
FROM OneMillionRecords
ORDER BY Id;


-- clear the transaction log
CHECKPOINT;






/*
First example
*/
-- UPDATE any EVEN Ids in the first 20,000 records with Autocommit (default)
DECLARE @Start as datetime2 = SYSDATETIME();

DECLARE @id int =1

WHILE @id <= 20000 BEGIN

	IF (@id % 2) = 0
		UPDATE ExplicitTransactions
		SET UpdateDate = @Start
		WHERE Id = @id

	SET @id += 1

	END;

SELECT CAST(DATEDIFF(ms, @Start, SYSDATETIME())/1000.000 as decimal(5,3)) as 'DurationInSeconds';


-- check the transaction log (note LOP_BEGIN_XACT, LOP_MODIFY_ROW, LOP_COMMIT_XACT for each UPDATE)
select * from fn_dblog(null,null) order by [Current LSN] desc








/*
Cleanup
*/
-- clear the transaction log
CHECKPOINT;






/*
Second example
*/
-- UPDATE any EVEN Ids in the next 20,000 records, but with an Explicit Transaction
DECLARE @Start as datetime2 = SYSDATETIME();

DECLARE @id int = 20001

BEGIN TRAN	-- <-- BEGIN Explicit Transaction

WHILE @id <= 40000 BEGIN

	IF (@id % 2) = 0
		UPDATE ExplicitTransactions
		SET UpdateDate = @Start
		WHERE Id = @id

	SET @id += 1

	END;
COMMIT	-- <-- COMMIT Explicit Transaction

SELECT CAST(DATEDIFF(ms, @Start, SYSDATETIME())/1000.000 as decimal(5,3)) as 'DurationInSeconds';


-- check the transaction log (where did all of the LOP_BEGIN_XACTs & LOP_COMMIT_XACTs go?)
select * from fn_dblog(null,null) order by [Current LSN] desc
