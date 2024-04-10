


	/* check to see if sa is disabled */
	SELECT
		name
		, is_disabled
	FROM sys.server_principals
	WHERE sid = 0x01;


	/* disabled sa */
	ALTER LOGIN [sa] DISABLE;




	/* find members of sysadmin role */
	SELECT
		name
		,type_desc
		,is_disabled
	FROM sys.server_principals
	WHERE IS_SRVROLEMEMBER ('sysadmin',name) = 1
	ORDER BY name








	/* find logins with CONTROL SERVER */  
	SELECT
		name
		,type_desc
		,is_disabled
	FROM sys.server_principals AS pri
	WHERE pri.[principal_id] IN (
		SELECT p.[grantee_principal_id]
		FROM sys.server_permissions AS p
		WHERE p.[state] IN ( 'G', 'W' )
		AND p.[class] = 100
		AND p.[type] = 'CL'
		)
		AND pri.[name] NOT LIKE '##%##';






	/* blank passwords */
	SELECT name
	FROM sys.sql_logins
	WHERE PWDCOMPARE('',password_hash)=1;
	
	/* password same as login */
	SELECT name
	FROM sys.sql_logins
	WHERE PWDCOMPARE(name,password_hash)=1;

	/* passwords is password */
	SELECT name
	FROM sys.sql_logins
	WHERE PWDCOMPARE('password',password_hash)=1;



	/* is CLR enabled? */
	SELECT *
	FROM master.sys.configurations l
	WHERE [name] = 'clr enabled';


	/* is strict CLR enabled? */
	SELECT *
	FROM master.sys.configurations l
	WHERE [name] = 'clr strict security';






	/* is xp_cmdshell enabled? */
	SELECT *
	FROM master.sys.configurations
	WHERE [name] = 'xp_cmdshell';





	/* Check for full backups */
	SELECT
		s.server_name AS InstanceName
		, s.database_name AS DatabaseName
		, s.recovery_model AS RecoveryModel
		, s.is_copy_only
		, s.is_snapshot
		, s.has_backup_checksums
		, s.backup_start_date AS BackupStartDate
		, s.backup_finish_date AS BackupFinishDate
		, CAST(DATEDIFF(second, s.backup_start_date, s.backup_finish_date) AS VARCHAR(4)) 
			+ ' ' + 'Seconds' AS Duration
		, CAST(CAST(s.backup_size / 1000000 AS INT) AS VARCHAR(14)) + ' ' + 'MB' AS SizeInMB
		, m.physical_device_name AS PhysicalDevice
		, m.logical_device_name AS LogicalDevice
		, CASE m.device_type
			WHEN 2 THEN 'Disk'
			WHEN 5 THEN 'Tape'
			WHEN 7 THEN 'Virtual Device'
			WHEN 9 THEN 'Azure Storage'
			WHEN 2 THEN 'A permanent Backup Device'
			ELSE 'UNKNOWN'
			END AS DeviceType
		, s.[user_name] AS UserName
	FROM msdb.dbo.backupset s
	INNER JOIN msdb.dbo.backupmediafamily m
		ON s.media_set_id = m.media_set_id
	WHERE s.[Type] = 'D' /* Full backups */
	ORDER BY s.backup_start_date DESC




	/* Check for log backups */
	SELECT
		s.server_name AS InstanceName
		, s.database_name AS DatabaseName
		, s.recovery_model AS RecoveryModel
		, s.is_copy_only
		, s.is_snapshot
		, s.has_backup_checksums
		, s.backup_start_date AS BackupStartDate
		, s.backup_finish_date AS BackupFinishDate
		, CAST(DATEDIFF(second, s.backup_start_date, s.backup_finish_date) AS VARCHAR(4)) 
			+ ' ' + 'Seconds' AS Duration
		, CAST(CAST(s.backup_size / 1000000 AS INT) AS VARCHAR(14)) + ' ' + 'MB' AS SizeInMB
		, m.physical_device_name AS PhysicalDevice
		, m.logical_device_name AS LogicalDevice
		, CASE m.device_type
			WHEN 2 THEN 'Disk'
			WHEN 5 THEN 'Tape'
			WHEN 7 THEN 'Virtual Device'
			WHEN 9 THEN 'Azure Storage'
			WHEN 2 THEN 'A permanent Backup Device'
			ELSE 'UNKNOWN'
			END AS DeviceType
		, s.[user_name] AS UserName
	FROM msdb.dbo.backupset s
	INNER JOIN msdb.dbo.backupmediafamily m
		ON s.media_set_id = m.media_set_id
	WHERE s.[Type] = 'L' /* Log backups */
	ORDER BY s.backup_start_date DESC







