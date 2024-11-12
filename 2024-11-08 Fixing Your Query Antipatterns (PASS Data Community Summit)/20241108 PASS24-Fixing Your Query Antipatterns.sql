SET STATISTICS IO ON


-- 1. Unnatural SELECTion

	-- Junior's way

	SELECT *
	FROM Person.Person 
	WHERE LastName = 'Barker';
	
	-- A better way

	SELECT FirstName, LastName
	FROM Person.Person 
	WHERE LastName = 'Barker';




-- 2. DISTINCT Disadvantage

	-- Junior's way

	SELECT DISTINCT soh.SalesOrderID
	FROM Sales.SalesOrderHeader soh
	INNER JOIN Sales.SalesOrderDetail sod
	 ON soh.SalesOrderID = sod.SalesOrderID
	INNER JOIN Production.Product pd
	 ON sod.ProductID = pd.ProductID
	WHERE pd.Color = 'Yellow';

	-- A better way

	SELECT soh.SalesOrderID
	FROM Sales.SalesOrderHeader soh
	WHERE soh.SalesOrderID IN (
		SELECT sod.SalesOrderID
		FROM Sales.SalesOrderDetail sod
		INNER JOIN Production.Product pd
		 ON sod.ProductID = pd.ProductID
		WHERE pd.Color = 'Yellow');




-- 3. JOIN-zilla

	-- Junior's way

	SELECT sp.[Name]
	FROM Sales.SalesOrderHeader soh
	INNER JOIN Sales.SalesOrderDetail sod
	 ON soh.SalesOrderID = sod.SalesOrderID
	INNER JOIN Production.Product pd
	 ON sod.ProductID = pd.ProductID
	INNER JOIN Sales.Customer c
	 ON soh.CustomerID = c.CustomerID
	INNER JOIN Person.Person pr
	 ON c.PersonID = pr.BusinessEntityID
	INNER JOIN Person.BusinessEntityAddress bea
	 ON pr.BusinessEntityID = bea.BusinessEntityID
	INNER JOIN Person.Address a
	 ON bea.AddressID = a.AddressID
	INNER JOIN Person.StateProvince sp
	 ON a.StateProvinceID = sp.StateProvinceID
	WHERE pr.Suffix = 'Jr.'
	 AND pd.Color = 'Black'
	 

	-- A better way
	
	SELECT c.CustomerID, sp.[Name] as StateProvince
	INTO #JrState
	FROM Sales.Customer c
	INNER JOIN Person.Person pr
	 ON c.PersonID = pr.BusinessEntityID
	INNER JOIN Person.BusinessEntityAddress bea
	 ON pr.BusinessEntityID = bea.BusinessEntityID
	INNER JOIN Person.Address a
	 ON bea.AddressID = a.AddressID
	INNER JOIN Person.StateProvince sp
	 ON a.StateProvinceID = sp.StateProvinceID
	WHERE Suffix = 'Jr.'

	SELECT ProductID
	INTO #Black
	FROM Production.Product
	WHERE Color = 'Black'

	SELECT jr.StateProvince
	FROM Sales.SalesOrderHeader soh
	INNER JOIN Sales.SalesOrderDetail sod
	 ON soh.SalesOrderID = sod.SalesOrderID
	INNER JOIN #Black black
	 ON sod.ProductID = black.ProductID
	INNER JOIN #JrState jr
	 ON soh.CustomerID = jr.CustomerID



-- 4. Avoiding the Semi (Join)

	-- Junior's way

	SELECT p.FirstName, p.LastName
	FROM Person.Person p
	LEFT OUTER JOIN Person.BusinessEntityAddress a
	 ON p.BusinessEntityID = a.BusinessEntityID
	WHERE a.BusinessEntityID IS NULL;

	-- A better way

	SELECT p.FirstName, p.LastName
	FROM Person.Person p
	WHERE NOT EXISTS (
		SELECT 1
		FROM Person.BusinessEntityAddress a
		WHERE p.BusinessEntityID = a.BusinessEntityID);



-- 5. Bad Arguments

	-- Junior's way

	DECLARE @Year int;

	SET @Year = 2012;

	SELECT COUNT(SalesOrderID)
	FROM Sales.SalesOrderHeader
	WHERE YEAR(OrderDate) = @Year;

	-- Other non SARGable queries

	SELECT COUNT(SalesOrderID)
	FROM Sales.SalesOrderHeader
	WHERE CAST(OrderDate AS CHAR(10)) = '2016-01-01';

	SELECT COUNT(SalesOrderID)
	FROM Sales.SalesOrderHeader
	WHERE DATEADD(YEAR, -1, OrderDate) = GETDATE();

	SELECT COUNT(SalesOrderID)
	FROM Sales.SalesOrderHeader
	WHERE TotalDue - 1000.00 > 0;
	
	GO

	-- A better way

	DECLARE @Year int;

	SET @Year = 2012;

	DECLARE @YearStart datetime, @YearEnd datetime

	SELECT @YearStart = CAST(CAST(@Year as VARCHAR(4)) + '-01-01' AS DATETIME)
	SELECT @YearEnd = CAST(CAST(@Year as VARCHAR(4)) + '-12-31' AS DATETIME)

	SELECT COUNT(SalesOrderID)
	FROM Sales.SalesOrderHeader
	WHERE OrderDate BETWEEN @YearStart AND @YearEnd;

	GO

	-- An even better way (to add orders during 12-31)

	DECLARE @Year int;

	SET @Year = 2012;

	DECLARE @YearStart datetime

	SELECT @YearStart = CAST(CAST(@Year as VARCHAR(4)) + '-01-01' AS DATETIME)

	SELECT COUNT(SalesOrderID)
	FROM Sales.SalesOrderHeader
	WHERE OrderDate >= @YearStart
	 AND OrderDate < DATEADD(YY, 1, @YearStart);

	GO

-- 6. A Lot of Nothing

-- You're gonna need to create this index
-- CREATE NONCLUSTERED INDEX IX_SalesOrderHeader_ShipDate ON Sales.SalesOrderHeader (ShipDate);

	-- Junior's way

	DECLARE @ShipDate datetime;

	SET @ShipDate = NULL;

	SELECT SalesOrderID, ShipDate
	FROM Sales.SalesOrderHeader
	WHERE ISNULL(ShipDate, '19010101')
	 = ISNULL(@ShipDate, '19010101');

	GO


	CREATE PROCEDURE usp_GetShippedOrders
		@ShipDate datetime 
	AS

	SELECT SalesOrderID, ShipDate
	FROM Sales.SalesOrderHeader
	WHERE ISNULL(ShipDate, '19010101')
	 = ISNULL(@ShipDate, '19010101');

	GO


-- A better way

	DECLARE @ShipDate datetime;

	SET @ShipDate = NULL;

	SELECT SalesOrderID, ShipDate
	FROM Sales.SalesOrderHeader
	WHERE ShipDate = @ShipDate
	 OR (ShipDate IS NULL AND @ShipDate IS NULL);

	GO
	

	CREATE OR ALTER PROCEDURE usp_GetShippedOrders
		@ShipDate datetime 
	AS

	SELECT SalesOrderID, ShipDate
	FROM Sales.SalesOrderHeader
	WHERE ShipDate = @ShipDate
	 OR (ShipDate IS NULL AND @ShipDate IS NULL);
	
	GO


-- Another way (using INTERSECT)

	DECLARE @ShipDate datetime;

	SET @ShipDate = NULL;

	SELECT SalesOrderID, ShipDate
	FROM Sales.SalesOrderHeader
	WHERE EXISTS (
		SELECT ShipDate INTERSECT SELECT @ShipDate
		);

	GO


	CREATE OR ALTER PROCEDURE usp_GetShippedOrders
		@ShipDate datetime 
	AS

	SELECT SalesOrderID, ShipDate
	FROM Sales.SalesOrderHeader
	WHERE EXISTS (
		SELECT ShipDate INTERSECT SELECT @ShipDate
		);

	GO

	

-- 7. Involuntary Conversion

	-- Junior's way

	DECLARE @CCAprovalCode NVARCHAR(15);

	SET @CCAprovalCode = '142999Vi76678';

	SELECT SalesOrderID
	FROM Sales.SalesOrderHeader
	WHERE CreditCardApprovalCode = @CCAprovalCode;

	GO


	CREATE OR ALTER PROCEDURE usp_GetShippedOrders
		@CCAprovalCode NVARCHAR(15)
	AS
	
	SELECT SalesOrderID
	FROM Sales.SalesOrderHeader
	WHERE CreditCardApprovalCode = @CCAprovalCode;
	GO

	-- A better way

	DECLARE @CCAprovalCode VARCHAR(15);

	SET @CCAprovalCode = '142999Vi76678';

	SELECT SalesOrderID
	FROM Sales.SalesOrderHeader
	WHERE CreditCardApprovalCode = @CCAprovalCode;

	GO


	CREATE OR ALTER PROCEDURE usp_GetShippedOrders
		@CCAprovalCode VARCHAR(15)
	AS
	
	SELECT SalesOrderID
	FROM Sales.SalesOrderHeader
	WHERE CreditCardApprovalCode = @CCAprovalCode;
	GO

	-- Pinal Dave's query to find execution plans with implict conversion
	-- https://blog.sqlauthority.com/2017/01/29/find-all-queries-with-implicit-conversion-in-sql-server-interview-question-of-the-week-107/
