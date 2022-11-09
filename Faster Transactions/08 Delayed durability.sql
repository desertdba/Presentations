/*------------------------------------
Delayed Durability
------------------------------------*/
/*
Setup
*/
USE DMLTest;

DROP TABLE IF EXISTS DelayedDurability;
GO

SET NOCOUNT ON;
SET STATISTICS IO OFF;
GO

CREATE TABLE DelayedDurability (Id int IDENTITY (1,1) PRIMARY KEY CLUSTERED, UpdateDate datetime);

INSERT DelayedDurability WITH (TABLOCK) (UpdateDate)
SELECT UpdateDate
FROM OneMillionRecords;








/*
First example
*/
-- Let's DELETE any EVEN Ids in the first 50,000 records - one at a time
DECLARE @Start as datetime2 = SYSDATETIME();

DECLARE @id int =1

WHILE @id <= 50000 BEGIN

	-- DELETE only EVEN numbers
	IF (@id % 2) = 0
		DELETE
		FROM DelayedDurability
		WHERE Id = @id

	SET @id += 1

	END;

SELECT CAST(DATEDIFF(ms, @Start, SYSDATETIME())/1000.000 as decimal(5,3)) as 'DurationInSeconds';
-- How long did that take?






/*
Second example
*/
ALTER DATABASE DMLTest SET DELAYED_DURABILITY = ALLOWED;
GO

-- -- Let's DELETE any EVEN Ids in the next 50,000 records - one at a time, but with DELAYED_DURABILITY
DECLARE @Start as datetime2 = SYSDATETIME();

DECLARE @id int =50001

WHILE @id <= 100000 BEGIN

	BEGIN TRAN -- <-- ADD THIS

	IF (@id % 2) = 0
		DELETE
		FROM DelayedDurability
		WHERE Id = @id

	SET @id += 1

	COMMIT WITH (DELAYED_DURABILITY = ON) -- <-- ...AND THIS

	END;

SELECT CAST(DATEDIFF(ms, @Start, SYSDATETIME())/1000.000 as decimal(5,3)) as 'DurationInSeconds';
-- This takes a little less time, right?

