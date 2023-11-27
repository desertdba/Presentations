
	/*
	Query Store - current status (use this in a job to monitor status)
	*/
	SELECT 
		DB_NAME() as DatabaseName
		, actual_state_desc
		, readonly_reason
		, max_storage_size_mb
		, (max_storage_size_mb - current_storage_size_mb) AS query_store_free_space_mb
		, flush_interval_seconds
		, interval_length_minutes
		, stale_query_threshold_days
		, max_plans_per_query
		, query_capture_mode_desc
		, size_based_cleanup_mode_desc
	FROM sys.database_query_store_options


	/*
	Paul Randal's Wait Statistics script
	https://www.sqlskills.com/blogs/paul/wait-statistics-or-please-tell-me-where-it-hurts/
	*/


	/*
	Remove invalid forced plans
	*/
	sp_query_store_unforce_plan
		@query_id = 19
		, @plan_id = 1167;


	/*
	Find failed forced plans
	*/
	SELECT 
		p.query_id
		, p.plan_id
		, q.object_id as containing_object_id
		, p.force_failure_count
		, p.last_force_failure_reason
		, p.last_force_failure_reason_desc
		, p.last_execution_time
	FROM sys.query_store_plan AS p
	JOIN sys.query_store_query AS q 
		ON p.query_id = q.query_id
	WHERE p.is_forced_plan = 1
		AND p.force_failure_count > 0;


	/*
	Find query_id by object name (stored procedure, function, trigger, etc.)
	*/
	SELECT q.query_id
		, t.query_sql_text
	FROM sys.query_store_query AS q
	JOIN sys.query_store_query_text AS t
		ON q.query_text_id = t.query_text_id
	WHERE q.object_id = OBJECT_ID('zzz');


	/*
	Find query_id by string
	*/
	SELECT q.query_id
		, t.query_sql_text
	FROM sys.query_store_query AS q
	JOIN sys.query_store_query_text AS t
		ON q.query_text_id = t.query_text_id
	WHERE t.query_sql_text LIKE '%zzz%';


	/*
	Find query_id by time of execution
	*/
	SELECT q.query_id
		, t.query_sql_text
	FROM sys.query_store_query AS q
	JOIN sys.query_store_query_text AS t
		ON q.query_text_id = t.query_text_id
	WHERE q.last_execution_time BETWEEN '1900/01/30 23:00:00' AND '1900/01/31 01:00:00';


	/*
	sp_BlitzQueryStore
	https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit
	*/


	/*
	sp_QuickieStore
	https://github.com/erikdarlingdata/DarlingData/tree/main/sp_QuickieStore
	*/


	/*
	Find deadlocks (and other aborted/cancelled queries)
	*/
	SELECT
		q.query_id
		, t.query_sql_text
		, r.execution_type
		, r.execution_type_desc
		, x.query_plan_xml
		, r.count_executions
		, r.last_execution_time
	FROM sys.query_store_query q
	JOIN sys.query_store_plan p
		ON q.query_id=p.query_id
	JOIN sys.query_store_query_text t
		ON q.query_text_id=t.query_text_id
	OUTER APPLY (SELECT TRY_CONVERT(XML, p.query_plan) AS query_plan_xml) x
	JOIN sys.query_store_runtime_stats r
		ON p.plan_id = r.plan_id
	WHERE r.execution_type = 4 /* Exception aborted execution */
		AND q.last_execution_time > GETDATE() - 1;


	/*
	Alerting on Bad Parameter Sniffing Using Automatic Tuning
	https://straightpathsql.com/archives/2022/10/alerting-on-bad-parameter-sniffing-using-automatic-tuning/
	*/




