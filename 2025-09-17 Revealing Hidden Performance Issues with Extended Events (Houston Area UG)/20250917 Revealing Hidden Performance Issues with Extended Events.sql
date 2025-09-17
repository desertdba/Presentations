/*
Do this first, you'll find out why later
*/
DBCC TRACEON(9708, -1);
GO






/*
Let's create a table with indexes for testing
*/

USE [StackOverflow]
GO

DROP TABLE IF EXISTS [dbo].[Users_antipattern]
GO

CREATE TABLE [dbo].[Users_antipattern](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[AboutMe] [nvarchar](max) NULL,
	[Age] [int] NULL,
	[CreationDate] [datetime] NOT NULL,
	[DisplayName] [varchar](40) NOT NULL, -- changed from nvarchar to varchar
	[DownVotes] [int] NOT NULL,
	[EmailHash] [nvarchar](40) NULL,
	[LastAccessDate] [datetime] NOT NULL,
	[Location] [nvarchar](100) NULL,
	[Reputation] [int] NOT NULL,
	[UpVotes] [int] NOT NULL,
	[Views] [nvarchar](20) NOT NULL, --changed from int to nvarchar
	[WebsiteUrl] [nvarchar](200) NULL,
	[AccountId] [int] NULL,
 CONSTRAINT [PK_Users_antipattern_Id] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO


SET IDENTITY_INSERT Users_antipattern ON

INSERT Users_antipattern
([Id], [AboutMe], [Age], [CreationDate], [DisplayName], [DownVotes], [EmailHash], [LastAccessDate], [Location], [Reputation], [UpVotes], [Views], [WebsiteUrl], [AccountId])
SELECT TOP 100000
[Id], [AboutMe], [Age], [CreationDate], CONVERT(VARCHAR(40),[DisplayName]), [DownVotes], [EmailHash], [LastAccessDate], [Location], [Reputation], [UpVotes], CONVERT(NVARCHAR(20),[Views]), [WebsiteUrl], [AccountId]
FROM Users;

SET IDENTITY_INSERT Users_antipattern OFF
GO

CREATE INDEX ix_Users_antipattern_DisplayName ON Users_antipattern (DisplayName)
GO

CREATE INDEX ix_Users_antipattern_Views ON Users_antipattern ([Views])
GO

CREATE INDEX ix_Users_antipattern_UpVotes ON Users_antipattern (UpVotes)
GO



CREATE INDEX ix_Users_Views ON Users ([Views])
GO




/*
Long-running queries (1 second/1,000,000 microseconds)
*/
USE [master];
GO 

IF EXISTS (
	SELECT * 
     FROM sys.server_event_sessions 
    WHERE [name] = '_long_running_queries') 
  BEGIN 
      DROP event session [_long_running_queries] ON server; 
  END
GO 

CREATE EVENT SESSION [_long_running_queries]  
ON SERVER  
ADD EVENT sqlserver.sql_statement_completed  (
	ACTION (
		sqlserver.client_app_name
		, sqlserver.plan_handle
		, sqlserver.query_hash
		, sqlserver.query_plan_hash
		, sqlserver.database_id
		, sqlserver.database_name
		, sqlserver.sql_text
		)
    WHERE duration >= 1000000
		)
	ADD TARGET package0.ring_buffer(SET max_memory=(1000)
	);
GO

ALTER EVENT SESSION _long_running_queries ON SERVER STATE = START;
GO






/*
Watch the live data!
(Check the duration)
*/
USE [StackOverflow];

SELECT top 1000000 *
FROM Users






/*
Let's query the plan cache using the plan_handle
...and view the execution plan!
*/
DECLARE @plan_handle VARBINARY(64) = 0x06000100653D0F13B0D1D368BE01000001000000000000000000000000000000000000000000000000000000
/*PlanHandleGoesHere*/;

SELECT 
    cp.plan_handle,
    cp.cacheobjtype,
    cp.objtype,
    cp.usecounts,
    qp.query_plan
FROM sys.dm_exec_cached_plans AS cp
CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) AS qp
WHERE cp.plan_handle = @plan_handle;








/*
Blocking
*/
USE [master];
GO 

IF EXISTS (
	SELECT * 
     FROM sys.server_event_sessions 
    WHERE [name] = '_blocked_process_report') 
  BEGIN 
      DROP event session [_blocked_process_report] ON server; 
  END
GO 

EXECUTE sp_configure 'blocked process threshold', 5; /* threshold in seconds */
GO
RECONFIGURE;
GO

CREATE EVENT SESSION [_blocked_process_report]
ON SERVER
ADD EVENT sqlserver.blocked_process_report
ADD TARGET 
        package0.event_file
    (
        SET filename = N'C:\XE\blocked_process_report.xel'
    );

/*
Includes:
	blocked_process (a bunch of XML, but useful!)
	database_id
	database_name
	duration
	index_id
	lock_mode
	object_id
	resouce_owner_type
	transaction_id
*/

ALTER EVENT SESSION _blocked_process_report ON SERVER STATE = START;
GO






/*
Let's test this XE
*/
USE [tempdb];
GO
CREATE TABLE [BlockParty] (
	Id INT IDENTITY(1,1) PRIMARY KEY,
	PartyFavor VARCHAR(20)
);
GO
 
BEGIN TRANSACTION
	INSERT INTO [BlockParty] (PartyFavor) 
	VALUES ('Bloc Bloc Bloc');
GO





/*
Run this in a different window and check the XE results
...after a few seconds.
*/
USE [tempdb];
GO
SELECT *
FROM [BlockParty];





/*
Don't leave me hanging!
After reviewing results, run this here
*/
ROLLBACK;
GO 
DROP TABLE tempdb..BlockParty






/*
How can we view the blocked process report?
-- https://github.com/erikdarlingdata/DarlingData/tree/main/sp_HumanEvents
*/
USE [master];
GO 
EXEC sp_HumanEventsBlockViewer @session_name = '_blocked_process_report';






/*
Deadlocks
*/
USE [master];
GO 

IF EXISTS (
	SELECT * 
     FROM sys.server_event_sessions 
    WHERE [name] = '_deadlocks') 
  BEGIN 
      DROP event session [_deadlocks] ON server; 
  END
GO 

CREATE EVENT SESSION [_deadlocks] ON SERVER 
--Events to track Lock_deadlock and Lock_deadlock_chain
ADD EVENT sqlserver.lock_deadlock(
    ACTION(sqlserver.sql_text))
, ADD EVENT sqlserver.lock_deadlock_chain(
    ACTION(sqlserver.sql_text)
	)
ADD TARGET package0.ring_buffer(SET max_memory=(1000));
GO

ALTER EVENT SESSION _deadlocks ON SERVER STATE = START;
GO






/*
Watch the live data and start a deadlock here...
*/
USE [tempdb];
GO
CREATE TABLE [Dead] (
	ID INT IDENTITY(1,1) PRIMARY KEY,
	DeadName VARCHAR(20)
);
GO
CREATE TABLE [Lock] (
	ID INT IDENTITY(1,1) PRIMARY KEY,
	LockName VARCHAR(20)
);
GO
INSERT INTO [Dead] (DeadName) VALUES ('Deadpool');
GO
INSERT INTO [Lock] (LockName) VALUES ('John Locke');
GO
BEGIN TRAN
	UPDATE Dead
	SET DeadName = 'I''m dead'
	WHERE ID = 1;





/*
...run this in another window...then come back
*/
USE [tempdb];
GO
BEGIN TRAN
	UPDATE Lock
	SET LockName = 'I''m locked'
	WHERE ID = 1

	UPDATE Dead
	SET DeadName = 'You''re dead'
	WHERE ID = 1;





/*
...now here run this and wait a few seconds:
*/
	UPDATE Lock
	SET LockName = 'You''re locked'
	WHERE ID = 1;

-- ROLLBACK






/*
But we already are capturing this in the system_health XE
*/
SELECT XEvent.query('(event/data/value/deadlock)[1]') AS DeadlockGraph
FROM (
    SELECT XEvent.query('.') AS XEvent
    FROM (
        SELECT CAST(target_data AS XML) AS TargetData
        FROM sys.dm_xe_session_targets st
        INNER JOIN sys.dm_xe_sessions s 
			ON s.address = st.event_session_address
        WHERE s.NAME = 'system_health'
            AND st.target_name = 'ring_buffer'
        ) AS [data]
CROSS APPLY TargetData.nodes('RingBufferTarget/event[@name="xml_deadlock_report"]') AS XEventData(XEvent)
) AS [source];






/*
...but that XML is gross.
Try sp_BlitzLock!
https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit/blob/dev/sp_BlitzLock.sql
*/
USE [master];
GO 
EXEC sp_BlitzLock;








/*
Failed queries...have errors
*/
USE [master];
GO 
 
IF EXISTS (
	SELECT * 
     FROM sys.server_event_sessions 
    WHERE [name] = '_failed_queries') 
  BEGIN 
      DROP EVENT SESSION [_failed_queries] ON SERVER; 
  END
GO 

CREATE EVENT SESSION [_failed_queries] ON SERVER 
	ADD EVENT sqlserver.error_reported (
		ACTION(
			sqlserver.client_app_name
			, sqlserver.client_hostname
			, sqlserver.database_name
			, sqlserver.sql_text
			, sqlserver.username
			) 
	WHERE ([package0].[greater_than_int64]([severity], (10)))) 
ADD TARGET package0.ring_buffer(SET max_memory=(1000))
GO

ALTER EVENT SESSION _failed_queries ON SERVER
STATE = START;
GO






/*
Watch live data and make a fail!
*/
SELECT * FROM ThisTableDoesNotExist;

SELECT 1/0;






/*
But what if I abort a query?
(Stop this after a second or two)
*/
USE StackOverflow;

SELECT TOP (1000) 
    u.Id 
FROM dbo.Users AS u
ORDER BY u.Reputation
OPTION(MAXDOP 1);












/*
Aborted queries...do not have errors
*/
USE [master];
GO 
 
IF EXISTS (
	SELECT * 
    FROM sys.server_event_sessions 
    WHERE [name] = '_aborted_queries') 
  BEGIN 
      DROP EVENT SESSION [_aborted_queries] ON SERVER; 
  END
GO 

CREATE EVENT SESSION [_aborted_queries] ON SERVER 
	ADD EVENT sqlserver.query_abort
	ADD TARGET package0.ring_buffer(SET max_memory=(1000))
GO

ALTER EVENT SESSION _aborted_queries ON SERVER
STATE = START;
GO





/*
Watch live data and abort!
*/
/*
But what if I abort a query?
(Stop this after a second or two)
*/
USE StackOverflow;

SELECT TOP (1000) 
    u.Id 
FROM dbo.Users AS u
ORDER BY u.Reputation
OPTION(MAXDOP 1);







/*
View the data...
...and review the "task_callstack_rva" values in SQLCallstackResolver
-- https://github.com/microsoft/SQLCallStackResolver
...to determine if it was cancelled, killed, or a timeout.

-- full examples here: https://sqlbits.com/Sessions/Event23/SQL_Server_2022_hidden_gems
*/







/*
You can also capture aborted queries with something like this:
*/
CREATE EVENT SESSION [_aborted_queries_old_school] ON SERVER 
	ADD EVENT sqlserver.sql_batch_completed (
		ACTION(
			sqlserver.[database_name]
			, sqlserver.sql_text
			) 
		WHERE (result = 'Abort')) 
	ADD TARGET package0.ring_buffer(SET max_memory=(1000))
GO








/*
Event: query_antipattern
Expected to detect:
 - Implicit type conversion that prevents index usage
 - Large IN clause
 - Large number of OR predicates
 - Non-optimal use of OR
 */

USE [master];
GO 
 
IF EXISTS (
	SELECT * 
     FROM sys.server_event_sessions 
    WHERE [name] = '_query_antipattern') 
  BEGIN 
      DROP event session [_query_antipattern] ON server; 
  END
GO 

 
CREATE EVENT SESSION [_query_antipattern] ON SERVER  
	ADD EVENT sqlserver.query_antipattern (   
		ACTION(
			sqlserver.client_app_name
			, sqlserver.plan_handle
			, sqlserver.query_hash
			, sqlserver.query_plan_hash
			, sqlserver.sql_text
			)
		WHERE ( 
			sqlserver.client_app_name <> N'Microsoft SQL Server Management Studio - Transact-SQL IntelliSense'
			AND sqlserver.client_app_name <> N'Microsoft SQL Server Management Studio'
			)
		)
	ADD TARGET package0.ring_buffer(SET max_memory=(1000));
GO


ALTER EVENT SESSION _query_antipattern ON SERVER
STATE = START;
GO





/*
Let's test this new query_antipattern event! (Watch live data)
!!! And let's enable Actual Execution Plan !!!
*/

/*
Implict conversion from varchar to nvarchar
*/
DBCC FREEPROCCACHE;
GO
USE [StackOverflow];
GO
SELECT Id, DisplayName
FROM Users_antipattern
WHERE DisplayName = N'???';





/*
Implict conversion from using an operator with a literal value
*/
DBCC FREEPROCCACHE;
GO
SELECT Id, DisplayName
FROM Users_antipattern
WHERE DisplayName = '??' + N'?';







/*
Scan from using an operator with the column...is NOT caught
...even though the exectuion plan shows an Implicit Conversion.
*/
DBCC FREEPROCCACHE;
GO
SELECT Id, DisplayName
FROM Users_antipattern
WHERE DisplayName + N'?' = N'??';







/*
(Common causes: Non-SARGable Predicates)

WHERE...
	FUNCTION(column) = something
	column + column = something
	column + value = something
	column = @something or @something IS NULL
	column like ‘%something%’
	column = CASE WHEN...
*/







/*
What about:
 - Large IN clause
 - Large number of OR predicates
 - Non-optimal use of OR
*/
/*
This catches nothing (unindexed INT column)
*/
DBCC FREEPROCCACHE;
GO
SELECT *  
FROM Users_antipattern
WHERE [DownVotes] IN (
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
    41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80,
    81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120,
    121, 122, 123, 124, 125, 126, 127, 128, 129, 130, 131, 132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142, 143, 144, 145, 146, 147, 148, 149, 150, 151, 152, 153, 154, 155, 156, 157, 158, 159, 160,
    161, 162, 163, 164, 165, 166, 167, 168, 169, 170, 171, 172, 173, 174, 175, 176, 177, 178, 179, 180, 181, 182, 183, 184, 185, 186, 187, 188, 189, 190, 191, 192, 193, 194, 195, 196, 197, 198, 199, 200,
    201, 202, 203, 204, 205, 206, 207, 208, 209, 210, 211, 212, 213, 214, 215, 216, 217, 218, 219, 220, 221, 222, 223, 224, 225, 226, 227, 228, 229, 230, 231, 232, 233, 234, 235, 236, 237, 238, 239, 240,
    241, 242, 243, 244, 245, 246, 247, 248, 249, 250, 251, 252, 253, 254, 255, 256, 257, 258, 259, 260, 261, 262, 263, 264, 265, 266, 267, 268, 269, 270, 271, 272, 273, 274, 275, 276, 277, 278, 279, 280,
    281, 282, 283, 284, 285, 286, 287, 288, 289, 290, 291, 292, 293, 294, 295, 296, 297, 298, 299, 300, 301, 302, 303, 304, 305, 306, 307, 308, 309, 310, 311, 312, 313, 314, 315, 316, 317, 318, 319, 320,
    321, 322, 323, 324, 325, 326, 327, 328, 329, 330, 331, 332, 333, 334, 335, 336, 337, 338, 339, 340, 341, 342, 343, 344, 345, 346, 347, 348, 349, 350, 351, 352, 353, 354, 355, 356, 357, 358, 359, 360,
    361, 362, 363, 364, 365, 366, 367, 368, 369, 370, 371, 372, 373, 374, 375, 376, 377, 378, 379, 380, 381, 382, 383, 384, 385, 386, 387, 388, 389, 390, 391, 392, 393, 394, 395, 396, 397, 398, 399, 400,
    401, 402, 403, 404, 405, 406, 407, 408, 409, 410, 411, 412, 413, 414, 415, 416, 417, 418, 419, 420, 421, 422, 423, 424, 425, 426, 427, 428, 429, 430, 431, 432, 433, 434, 435, 436, 437, 438, 439, 440,
    441, 442, 443, 444, 445, 446, 447, 448, 449, 450, 451, 452, 453, 454, 455, 456, 457, 458, 459, 460, 461, 462, 463, 464, 465, 466, 467, 468, 469, 470, 471, 472, 473, 474, 475, 476, 477, 478, 479, 480,
    481, 482, 483, 484, 485, 486, 487, 488, 489, 490, 491, 492, 493, 494, 495, 496, 497, 498, 499, 500
);






/*
This also catches nothing (indexed INT column)
*/
DBCC FREEPROCCACHE;
GO
SELECT *  
FROM Users_antipattern
WHERE [UpVotes] IN (
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
    41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80,
    81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120,
    121, 122, 123, 124, 125, 126, 127, 128, 129, 130, 131, 132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142, 143, 144, 145, 146, 147, 148, 149, 150, 151, 152, 153, 154, 155, 156, 157, 158, 159, 160,
    161, 162, 163, 164, 165, 166, 167, 168, 169, 170, 171, 172, 173, 174, 175, 176, 177, 178, 179, 180, 181, 182, 183, 184, 185, 186, 187, 188, 189, 190, 191, 192, 193, 194, 195, 196, 197, 198, 199, 200,
    201, 202, 203, 204, 205, 206, 207, 208, 209, 210, 211, 212, 213, 214, 215, 216, 217, 218, 219, 220, 221, 222, 223, 224, 225, 226, 227, 228, 229, 230, 231, 232, 233, 234, 235, 236, 237, 238, 239, 240,
    241, 242, 243, 244, 245, 246, 247, 248, 249, 250, 251, 252, 253, 254, 255, 256, 257, 258, 259, 260, 261, 262, 263, 264, 265, 266, 267, 268, 269, 270, 271, 272, 273, 274, 275, 276, 277, 278, 279, 280,
    281, 282, 283, 284, 285, 286, 287, 288, 289, 290, 291, 292, 293, 294, 295, 296, 297, 298, 299, 300, 301, 302, 303, 304, 305, 306, 307, 308, 309, 310, 311, 312, 313, 314, 315, 316, 317, 318, 319, 320,
    321, 322, 323, 324, 325, 326, 327, 328, 329, 330, 331, 332, 333, 334, 335, 336, 337, 338, 339, 340, 341, 342, 343, 344, 345, 346, 347, 348, 349, 350, 351, 352, 353, 354, 355, 356, 357, 358, 359, 360,
    361, 362, 363, 364, 365, 366, 367, 368, 369, 370, 371, 372, 373, 374, 375, 376, 377, 378, 379, 380, 381, 382, 383, 384, 385, 386, 387, 388, 389, 390, 391, 392, 393, 394, 395, 396, 397, 398, 399, 400,
    401, 402, 403, 404, 405, 406, 407, 408, 409, 410, 411, 412, 413, 414, 415, 416, 417, 418, 419, 420, 421, 422, 423, 424, 425, 426, 427, 428, 429, 430, 431, 432, 433, 434, 435, 436, 437, 438, 439, 440,
    441, 442, 443, 444, 445, 446, 447, 448, 449, 450, 451, 452, 453, 454, 455, 456, 457, 458, 459, 460, 461, 462, 463, 464, 465, 466, 467, 468, 469, 470, 471, 472, 473, 474, 475, 476, 477, 478, 479, 480,
    481, 482, 483, 484, 485, 486, 487, 488, 489, 490, 491, 492, 493, 494, 495, 496, 497, 498, 499, 500
);








/*
This...catches 2 things! (indexed NVARCHAR column)
1. Type convert preventing seek
2. Large number of OR in predicate
...but not Large IN clause?
*/
DBCC FREEPROCCACHE;
GO
SELECT *  
FROM Users_antipattern
WHERE [Views] IN (
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
    41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80,
    81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120,
    121, 122, 123, 124, 125, 126, 127, 128, 129, 130, 131, 132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142, 143, 144, 145, 146, 147, 148, 149, 150, 151, 152, 153, 154, 155, 156, 157, 158, 159, 160,
    161, 162, 163, 164, 165, 166, 167, 168, 169, 170, 171, 172, 173, 174, 175, 176, 177, 178, 179, 180, 181, 182, 183, 184, 185, 186, 187, 188, 189, 190, 191, 192, 193, 194, 195, 196, 197, 198, 199, 200,
    201, 202, 203, 204, 205, 206, 207, 208, 209, 210, 211, 212, 213, 214, 215, 216, 217, 218, 219, 220, 221, 222, 223, 224, 225, 226, 227, 228, 229, 230, 231, 232, 233, 234, 235, 236, 237, 238, 239, 240,
    241, 242, 243, 244, 245, 246, 247, 248, 249, 250, 251, 252, 253, 254, 255, 256, 257, 258, 259, 260, 261, 262, 263, 264, 265, 266, 267, 268, 269, 270, 271, 272, 273, 274, 275, 276, 277, 278, 279, 280,
    281, 282, 283, 284, 285, 286, 287, 288, 289, 290, 291, 292, 293, 294, 295, 296, 297, 298, 299, 300, 301, 302, 303, 304, 305, 306, 307, 308, 309, 310, 311, 312, 313, 314, 315, 316, 317, 318, 319, 320,
    321, 322, 323, 324, 325, 326, 327, 328, 329, 330, 331, 332, 333, 334, 335, 336, 337, 338, 339, 340, 341, 342, 343, 344, 345, 346, 347, 348, 349, 350, 351, 352, 353, 354, 355, 356, 357, 358, 359, 360,
    361, 362, 363, 364, 365, 366, 367, 368, 369, 370, 371, 372, 373, 374, 375, 376, 377, 378, 379, 380, 381, 382, 383, 384, 385, 386, 387, 388, 389, 390, 391, 392, 393, 394, 395, 396, 397, 398, 399, 400,
    401, 402, 403, 404, 405, 406, 407, 408, 409, 410, 411, 412, 413, 414, 415, 416, 417, 418, 419, 420, 421, 422, 423, 424, 425, 426, 427, 428, 429, 430, 431, 432, 433, 434, 435, 436, 437, 438, 439, 440,
    441, 442, 443, 444, 445, 446, 447, 448, 449, 450, 451, 452, 453, 454, 455, 456, 457, 458, 459, 460, 461, 462, 463, 464, 465, 466, 467, 468, 469, 470, 471, 472, 473, 474, 475, 476, 477, 478, 479, 480,
    481, 482, 483, 484, 485, 486, 487, 488, 489, 490, 491, 492, 493, 494, 495, 496, 497, 498, 499, 500
);








/*
What is a "large number" though?
What if we have 100? That's caught.
*/
DBCC FREEPROCCACHE;
GO
SELECT *  
FROM Users_antipattern
WHERE [Views] IN (
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
    41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80,
    81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100
);






/*
What is a "large number" though?
What if we have 50? We only catch the Type convert preventing seek.
*/
DBCC FREEPROCCACHE;
GO
SELECT *  
FROM Users_antipattern
WHERE [Views] IN (
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
    41, 42, 43, 44, 45, 46, 47, 48, 49, 50
);






/*
The magic number is...65
65 or more catches "Large Number of OR predicates"...
*/
DBCC FREEPROCCACHE;
GO
SELECT *  
FROM Users_antipattern
WHERE [Views] IN (
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
    41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65
);







/*
...64 does not
*/
DBCC FREEPROCCACHE;
GO
SELECT *  
FROM Users_antipattern
WHERE [Views] IN (
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
    41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64
);







/*
But if we change the values from numeric to character, we catch nothing.
*/
DBCC FREEPROCCACHE;
GO
SELECT *  
FROM Users_antipattern
WHERE [Views] IN (
	'1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '13', '14', '15', '16', '17', '18', '19', '20', '21', '22', '23', '24', '25', '26', '27', '28', '29', '30', '31', '32', '33', '34', '35', '36', '37', '38', '39', '40',
    '41', '42', '43', '44', '45', '46', '47', '48', '49', '50', '51', '52', '53', '54', '55', '56', '57', '58', '59', '60', '61', '62', '63', '64', '65', '66', '67', '68', '69', '70', '71', '72', '73', '74', '75', '76', '77', '78', '79', '80',
    '81', '82', '83', '84', '85', '86', '87', '88', '89', '90', '91', '92', '93', '94', '95', '96', '97', '98', '99', '100', '101', '102', '103', '104', '105', '106', '107', '108', '109', '110', '111', '112', '113', '114', '115', '116', '117', '118', '119', '120',
    '121', '122', '123', '124', '125', '126', '127', '128', '129', '130', '131', '132', '133', '134', '135', '136', '137', '138', '139', '140', '141', '142', '143', '144', '145', '146', '147', '148', '149', '150', '151', '152', '153', '154', '155', '156', '157', '158', '159', '160',
    '161', '162', '163', '164', '165', '166', '167', '168', '169', '170', '171', '172', '173', '174', '175', '176', '177', '178', '179', '180', '181', '182', '183', '184', '185', '186', '187', '188', '189', '190', '191', '192', '193', '194', '195', '196', '197', '198', '199', '200',
    '201', '202', '203', '204', '205', '206', '207', '208', '209', '210', '211', '212', '213', '214', '215', '216', '217', '218', '219', '220', '221', '222', '223', '224', '225', '226', '227', '228', '229', '230', '231', '232', '233', '234', '235', '236', '237', '238', '239', '240',
    '241', '242', '243', '244', '245', '246', '247', '248', '249', '250', '251', '252', '253', '254', '255', '256', '257', '258', '259', '260', '261', '262', '263', '264', '265', '266', '267', '268', '269', '270', '271', '272', '273', '274', '275', '276', '277', '278', '279', '280',
    '281', '282', '283', '284', '285', '286', '287', '288', '289', '290', '291', '292', '293', '294', '295', '296', '297', '298', '299', '300', '301', '302', '303', '304', '305', '306', '307', '308', '309', '310', '311', '312', '313', '314', '315', '316', '317', '318', '319', '320',
    '321', '322', '323', '324', '325', '326', '327', '328', '329', '330', '331', '332', '333', '334', '335', '336', '337', '338', '339', '340', '341', '342', '343', '344', '345', '346', '347', '348', '349', '350', '351', '352', '353', '354', '355', '356', '357', '358', '359', '360',
    '361', '362', '363', '364', '365', '366', '367', '368', '369', '370', '371', '372', '373', '374', '375', '376', '377', '378', '379', '380', '381', '382', '383', '384', '385', '386', '387', '388', '389', '390', '391', '392', '393', '394', '395', '396', '397', '398', '399', '400',
    '401', '402', '403', '404', '405', '406', '407', '408', '409', '410', '411', '412', '413', '414', '415', '416', '417', '418', '419', '420', '421', '422', '423', '424', '425', '426', '427', '428', '429', '430', '431', '432', '433', '434', '435', '436', '437', '438', '439', '440',
    '441', '442', '443', '444', '445', '446', '447', '448', '449', '450', '451', '452', '453', '454', '455', '456', '457', '458', '459', '460', '461', '462', '463', '464', '465', '466', '467', '468', '469', '470', '471', '472', '473', '474', '475', '476', '477', '478', '479', '480',
    '481', '482', '483', '484', '485', '486', '487', '488', '489', '490', '491', '492', '493', '494', '495', '496', '497', '498', '499', '500'
);







/*
What about an actual large number of OR predicates? 
This is caught, but with the same Large Number Of OR In Predicate antipattern type.
*/
DBCC FREEPROCCACHE;
GO
SELECT *  
FROM Users_antipattern
WHERE [Views] = 1 
OR [Views] = 2 OR [Views] = 3 OR [Views]  = 4 OR [Views]  = 5 
OR [Views] = 6 OR [Views]  = 7 OR [Views]  = 8 OR [Views]  = 9 
OR [Views]  = 10 OR [Views]  = 11 OR [Views]  = 12 OR [Views]  = 13 
OR [Views]  = 14 OR [Views]  = 15 OR [Views]  = 16 OR [Views]  = 17 
OR [Views]  = 18 OR [Views]  = 19 OR [Views]  = 20 OR [Views]  = 21 
OR [Views]  = 22 OR [Views]  = 23 OR [Views]  = 24 OR [Views]  = 25 
OR [Views]  = 26 OR [Views]  = 27 OR [Views]  = 28 OR [Views]  = 29 
OR [Views]  = 30 OR [Views]  = 31 OR [Views]  = 32 OR [Views]  = 33 
OR [Views]  = 34 OR [Views]  = 35 OR [Views]  = 36 OR [Views]  = 37 
OR [Views]  = 38 OR [Views]  = 39 OR [Views]  = 40 OR [Views]  = 41 
OR [Views]  = 42 OR [Views]  = 43 OR [Views]  = 44 OR [Views]  = 45 
OR [Views]  = 46 OR [Views]  = 47 OR [Views]  = 48 OR [Views]  = 49 
OR [Views]  = 50 OR [Views]  = 51 OR [Views]  = 52 OR [Views]  = 53 
OR [Views]  = 54 OR [Views]  = 55 OR [Views]  = 56 OR [Views]  = 57 
OR [Views]  = 58 OR [Views]  = 59 OR [Views]  = 60 OR [Views]  = 61 
OR [Views]  = 62 OR [Views]  = 63 OR [Views]  = 64 OR [Views]  = 65 
OR [Views]  = 66 OR [Views]  = 67 OR [Views]  = 68 OR [Views]  = 69 
OR [Views]  = 70 OR [Views]  = 71 OR [Views]  = 72 OR [Views]  = 73 
OR [Views]  = 74 OR [Views]  = 75 OR [Views]  = 76 OR [Views]  = 77 
OR [Views]  = 78 OR [Views]  = 79 OR [Views]  = 80 OR [Views]  = 81 
OR [Views]  = 82 OR [Views]  = 83 OR [Views]  = 84 OR [Views]  = 85 
OR [Views]  = 86 OR [Views]  = 87 OR [Views]  = 88 OR [Views]  = 89 
OR [Views]  = 90 OR [Views]  = 91 OR [Views]  = 92 OR [Views]  = 93 
OR [Views]  = 94 OR [Views]  = 95 OR [Views]  = 96 OR [Views]  = 97 
OR [Views]  = 98 OR [Views]  = 99 OR [Views]  = 100 OR [Views]  = 101 







/*
But again, the magic number is 65. This is caught.
*/
DBCC FREEPROCCACHE;
GO
SELECT *  
FROM Users_antipattern
WHERE [Views] = 1 
OR [Views] = 2 OR [Views] = 3 OR [Views]  = 4 OR [Views]  = 5 
OR [Views] = 6 OR [Views]  = 7 OR [Views]  = 8 OR [Views]  = 9 
OR [Views]  = 10 OR [Views]  = 11 OR [Views]  = 12 OR [Views]  = 13 
OR [Views]  = 14 OR [Views]  = 15 OR [Views]  = 16 OR [Views]  = 17 
OR [Views]  = 18 OR [Views]  = 19 OR [Views]  = 20 OR [Views]  = 21 
OR [Views]  = 22 OR [Views]  = 23 OR [Views]  = 24 OR [Views]  = 25 
OR [Views]  = 26 OR [Views]  = 27 OR [Views]  = 28 OR [Views]  = 29 
OR [Views]  = 30 OR [Views]  = 31 OR [Views]  = 32 OR [Views]  = 33 
OR [Views]  = 34 OR [Views]  = 35 OR [Views]  = 36 OR [Views]  = 37 
OR [Views]  = 38 OR [Views]  = 39 OR [Views]  = 40 OR [Views]  = 41 
OR [Views]  = 42 OR [Views]  = 43 OR [Views]  = 44 OR [Views]  = 45 
OR [Views]  = 46 OR [Views]  = 47 OR [Views]  = 48 OR [Views]  = 49 
OR [Views]  = 50 OR [Views]  = 51 OR [Views]  = 52 OR [Views]  = 53 
OR [Views]  = 54 OR [Views]  = 55 OR [Views]  = 56 OR [Views]  = 57 
OR [Views]  = 58 OR [Views]  = 59 OR [Views]  = 60 OR [Views]  = 61 
OR [Views]  = 62 OR [Views]  = 63 OR [Views]  = 64 OR [Views]  = 65;







/*
With 64, this is not caught
*/
DBCC FREEPROCCACHE;
GO
SELECT *  
FROM Users_antipattern
WHERE [Views] = 1 
OR [Views] = 2 OR [Views] = 3 OR [Views]  = 4 OR [Views]  = 5 
OR [Views] = 6 OR [Views]  = 7 OR [Views]  = 8 OR [Views]  = 9 
OR [Views]  = 10 OR [Views]  = 11 OR [Views]  = 12 OR [Views]  = 13 
OR [Views]  = 14 OR [Views]  = 15 OR [Views]  = 16 OR [Views]  = 17 
OR [Views]  = 18 OR [Views]  = 19 OR [Views]  = 20 OR [Views]  = 21 
OR [Views]  = 22 OR [Views]  = 23 OR [Views]  = 24 OR [Views]  = 25 
OR [Views]  = 26 OR [Views]  = 27 OR [Views]  = 28 OR [Views]  = 29 
OR [Views]  = 30 OR [Views]  = 31 OR [Views]  = 32 OR [Views]  = 33 
OR [Views]  = 34 OR [Views]  = 35 OR [Views]  = 36 OR [Views]  = 37 
OR [Views]  = 38 OR [Views]  = 39 OR [Views]  = 40 OR [Views]  = 41 
OR [Views]  = 42 OR [Views]  = 43 OR [Views]  = 44 OR [Views]  = 45 
OR [Views]  = 46 OR [Views]  = 47 OR [Views]  = 48 OR [Views]  = 49 
OR [Views]  = 50 OR [Views]  = 51 OR [Views]  = 52 OR [Views]  = 53 
OR [Views]  = 54 OR [Views]  = 55 OR [Views]  = 56 OR [Views]  = 57 
OR [Views]  = 58 OR [Views]  = 59 OR [Views]  = 60 OR [Views]  = 61 
OR [Views]  = 62 OR [Views]  = 63 OR [Views]  = 64;








/*
What about Non-optimal use of OR?
This is not caught
*/
DBCC FREEPROCCACHE;
GO
SELECT ua.Id, ua.[Views]
FROM Users_antipattern ua
JOIN Users u
	ON ua.Id = u.Id
WHERE ua.[Views] = 1 
OR ua.[Views] = 2 OR ua.[Views] = 3 OR ua.[Views]  = 4 OR ua.[Views]  = 5 
OR ua.[Views] = 6 OR ua.[Views]  = 7 OR ua.[Views]  = 8 OR ua.[Views]  = 9 
OR ua.[Views]  = 10 OR ua.[Views]  = 11 OR ua.[Views]  = 12 OR ua.[Views]  = 13 
OR ua.[Views]  = 14 OR ua.[Views]  = 15 OR ua.[Views]  = 16 OR ua.[Views]  = 17 
OR ua.[Views]  = 18 OR ua.[Views]  = 19 OR ua.[Views]  = 20 OR ua.[Views]  = 21 
OR ua.[Views]  = 22 OR ua.[Views]  = 23 OR ua.[Views]  = 24 OR ua.[Views]  = 25 
OR ua.[Views]  = 26 OR ua.[Views]  = 27 OR ua.[Views]  = 28 OR ua.[Views]  = 29 
OR ua.[Views]  = 30 OR ua.[Views]  = 31 OR ua.[Views]  = 32 OR ua.[Views]  = 33 
OR ua.[Views]  = 34 OR ua.[Views]  = 35 OR ua.[Views]  = 36 OR ua.[Views]  = 37 
OR ua.[Views]  = 38 OR ua.[Views]  = 39 OR ua.[Views]  = 40 OR ua.[Views]  = 41 
OR ua.[Views]  = 42 OR ua.[Views]  = 43 OR ua.[Views]  = 44 OR ua.[Views]  = 45 
OR ua.[Views]  = 46 OR ua.[Views]  = 47 OR ua.[Views]  = 48 OR ua.[Views]  = 49 
OR ua.[Views]  = 50 OR ua.[Views]  = 51 OR ua.[Views]  = 52 OR ua.[Views]  = 53 
OR ua.[Views]  = 54 OR ua.[Views]  = 55 OR ua.[Views]  = 56 OR ua.[Views]  = 57 
OR ua.[Views]  = 58 OR ua.[Views]  = 59 OR ua.[Views]  = 60 OR ua.[Views]  = 61 
OR ua.[Views]  = 62 OR ua.[Views]  = 63 OR ua.[Views]  = 64
OR u.[Views] = 2 OR u.[Views] = 3 OR u.[Views]  = 4 OR u.[Views]  = 5 
OR u.[Views] = 6 OR u.[Views]  = 7 OR u.[Views]  = 8 OR u.[Views]  = 9 
OR u.[Views]  = 10 OR u.[Views]  = 11 OR u.[Views]  = 12 OR u.[Views]  = 13 
OR u.[Views]  = 14 OR u.[Views]  = 15 OR u.[Views]  = 16 OR u.[Views]  = 17 
OR u.[Views]  = 18 OR u.[Views]  = 19 OR u.[Views]  = 20 OR u.[Views]  = 21 
OR u.[Views]  = 22 OR u.[Views]  = 23 OR u.[Views]  = 24 OR u.[Views]  = 25 
OR u.[Views]  = 26 OR u.[Views]  = 27 OR u.[Views]  = 28 OR u.[Views]  = 29 
OR u.[Views]  = 30 OR u.[Views]  = 31 OR u.[Views]  = 32 OR u.[Views]  = 33 
OR u.[Views]  = 34 OR u.[Views]  = 35 OR u.[Views]  = 36 OR u.[Views]  = 37 
OR u.[Views]  = 38 OR u.[Views]  = 39 OR u.[Views]  = 40 OR u.[Views]  = 41 
OR u.[Views]  = 42 OR u.[Views]  = 43 OR u.[Views]  = 44 OR u.[Views]  = 45 
OR u.[Views]  = 46 OR u.[Views]  = 47 OR u.[Views]  = 48 OR u.[Views]  = 49 
OR u.[Views]  = 50 OR u.[Views]  = 51 OR u.[Views]  = 52 OR u.[Views]  = 53 
OR u.[Views]  = 54 OR u.[Views]  = 55 OR u.[Views]  = 56 OR u.[Views]  = 57 
OR u.[Views]  = 58 OR u.[Views]  = 59 OR u.[Views]  = 60 OR u.[Views]  = 61 
OR u.[Views]  = 62 OR u.[Views]  = 63 OR u.[Views]  = 64;









/*
A slightly different version, but this is not caught either
*/
SELECT ua.Id, ua.[Views]
FROM Users_antipattern ua
JOIN Users u
	ON ua.Id = u.Id
WHERE ua.[Views] BETWEEN 1 AND 64
OR u.[Views] BETWEEN 1 AND 64;








/*
What about:
 - Large IN clause?
 - Non-optimal use of OR?
*/











/*
Spills to tempdb
*/
USE [master];
GO 
 
IF EXISTS (
	SELECT * 
     FROM sys.server_event_sessions 
    WHERE [name] = '_tempdb_spill') 
  BEGIN 
      DROP event session [_tempdb_spill] ON server; 
  END
GO 

 
CREATE EVENT SESSION [_tempdb_spill] ON SERVER  
	ADD EVENT sqlserver.spills_to_tempdb
	(
		ACTION 
		(
			sqlserver.sql_text,
			sqlserver.tsql_stack,
			sqlserver.session_id,
			sqlserver.database_id,
			sqlserver.client_app_name,
			sqlserver.username
		)
	)
	ADD TARGET package0.ring_buffer(SET max_memory=(1000));
GO

ALTER EVENT SESSION _tempdb_spill ON SERVER
STATE = START;
GO





/*
Here's a spill due to an insufficient memory grant
Let's watch the live data...?
*/
USE StackOverflow;

SELECT TOP (1000) 
    u.Id 
FROM dbo.Users AS u
ORDER BY u.Reputation
OPTION(MAXDOP 1);










/*
Why wasn't this caught?
...because this event captures "Sort spill to tempdb when 20% of max tempdb size"
*/








/*
We have another option if you want to find smaller spills
*/
IF EXISTS (
	SELECT * 
     FROM sys.server_event_sessions 
    WHERE [name] = '_statement_completed_spills') 
  BEGIN 
      DROP EVENT SESSION [_statement_completed_spills] ON server; 
  END
GO 

CREATE EVENT SESSION [_statement_completed_spills] ON SERVER 
	ADD EVENT sqlserver.sql_statement_completed (
		WHERE (sql_statement_completed.spills > 0))
	ADD TARGET package0.ring_buffer(SET max_memory=(1000));
GO

ALTER EVENT SESSION _statement_completed_spills ON SERVER STATE = START;
GO






/*
Watch live data and try the query again
*/
USE StackOverflow;

SELECT TOP (1000) 
    u.Id 
FROM dbo.Users AS u
ORDER BY u.Reputation
OPTION(MAXDOP 1);







/*
What happens with lots of spills?...contention!
*/






/*
Measure tempdb growth
!!! Restart the SQL Server service !!! <--DON'T DO THIS IN THE DEMO
*/
IF EXISTS (
	SELECT * 
     FROM sys.server_event_sessions 
    WHERE [name] = '_tempdb_growth') 
  BEGIN 
      DROP EVENT SESSION [_tempdb_growth] ON server; 
  END
GO 
CREATE EVENT SESSION [_tempdb_growth] ON SERVER
	ADD EVENT [sqlserver].[database_file_size_change] (
		ACTION ( 
			[sqlserver].[session_id]
			, [sqlserver].[database_id]
			, [sqlserver].[client_hostname]
			, [sqlserver].[sql_text] )
		WHERE ( [database_id] = (2) 
		AND [session_id] > (50)
		) 
	)
	, ADD EVENT [sqlserver].[databases_log_file_used_size_changed] (
		ACTION ( 
			[sqlserver].[session_id]
			, [sqlserver].[database_id]
			, [sqlserver].[client_hostname]
			, [sqlserver].[sql_text] )
		WHERE ( [database_id] = (2) 
		AND [session_id] > (50) 
		) 
	)
	ADD TARGET package0.ring_buffer(SET max_memory=(1000));
GO

ALTER EVENT SESSION [_tempdb_growth] ON SERVER STATE = START;








/*
Let's watch the live data...
...and run our query that spills to tempdb again
*/
USE StackOverflow;

SELECT TOP (1000) 
    u.Id 
FROM dbo.Users AS u
ORDER BY u.Reputation
OPTION(MAXDOP 1);









/*
Just for giggles, try reducing the size of the files in SSMS
...and check the live data!
*/










/*
Measuring Extended Events in SQL Server 2022 with sys.dm_xe_session_events:
	event_fire_count (requires trace flag 9708)
	event_fire_average_time (microseconds, requires trace flag 9708)
	event_fire_min_time (microseconds)
	event_fire_max_time (microseconds)

*/

DBCC TRACEON(9708, -1);
GO

SELECT 
	s.[name] AS session_name, 
	se.event_name,
	se.event_fire_count,
	se.event_fire_average_time, 
	se.event_fire_min_time, 
	se.event_fire_max_time
FROM sys.dm_xe_sessions AS s 
INNER JOIN sys.dm_xe_session_events AS se
	ON s.[address] = se.event_session_address
ORDER BY se.event_fire_count DESC;

