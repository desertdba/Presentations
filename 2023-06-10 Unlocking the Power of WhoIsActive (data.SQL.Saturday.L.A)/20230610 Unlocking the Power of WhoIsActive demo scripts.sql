
	/***********************
	 1. Changing the output
	***********************/





	/*
	Change columns returned or column order
	*/
	EXEC sp_WhoIsActive
	 @output_column_list = '[session_id][login_name][sql_text][percent%][%]';






	/*
	Filter rows returned (inludes wildcard examples)
	*/
	 EXEC sp_WhoIsActive
	  @output_column_list = '[session_id][login_name][sql_text][%]'
	 , @filter_type = 'login'
	 , @filter = 'GlobalInc%'




	/*
	Filter rows returned (inludes wildcard examples)
	Filter Types: login, session, host, program, and database (not reliable)
	*/
	 EXEC sp_WhoIsActive
	  @output_column_list = '[session_id][login_name][sql_text][%]'
	 , @filter_type = 'login'
	 , @filter = 'GlobalInc%'
	 , @not_filter_type = 'login'
	 , @not_filter = '%anna';





	 /*
	 Change sort order
	 */
	 EXEC sp_WhoIsActive
	  @output_column_list = '[session_id][login_name][sql_text][%]'
	 , @filter_type = 'login'
	 , @filter = 'GlobalInc%'
	 , @sort_order = '[login_name] DESC';






	/****************************
	 2. Getting more information
	****************************/






	/*
	Show system spids
	*/
	EXEC sp_WhoIsActive
	 @show_system_spids = 1;





 
	/*
	Show sleeping spids
	*/
	EXEC sp_WhoIsActive
	 @show_sleeping_spids = 2;






	/*
	Show the plan for the current statement
	*/
	EXEC sp_WhoIsActive
	 @get_plans = 1;






	/*
	Show the plan for all queries in the batch
	*/
	EXEC sp_WhoIsActive
	 @get_plans = 2;
 
 




	/*
	Show the origial command/stored procedure that called the SQL statement
	*/
	EXEC sp_WhoIsActive 
	 @get_outer_command = 1;







	/*
	Show all the waits
	*/
	EXEC sp_WhoIsActive
	 @get_task_info = 2;






	/*
	Show all the locks
	*/
	EXEC sp_WhoIsActive
	 @get_locks = 1;






	/*
	Show transaction isolation level and other fortmatting options (ansi warnings, deadlock priority, etc)
	*/
	EXEC sp_WhoIsActive
	 @get_additional_info = 1;





 
	/*************************************
	 3. Troubleshooting specific problems
	*************************************/

	/*
	Backup restore percentage
	*/
	EXEC sp_WhoIsActive 
	 @output_column_list = '[dd%][percent%][database_name][sql_text][%]'



	/*
	Sample activity (delta interval in seconds)
	*/
	EXEC sp_WhoIsActive
	 @output_column_list = '[%delta][%]'
	 , @delta_interval = 5;






	/*
	Are these executions slower than usual? 
	*/
	EXEC sp_WhoIsActive
	 @get_avg_time = 1;






	 /*
	 What's causing the blocking?
	 */
	 EXEC sp_WhoIsActive
	 @output_column_list = '[start_time][session_id][block%][login%][sql_text][%]'
	 , @find_block_leaders = 1
	 , @sort_order = '[blocked_session_count] DESC'
	 , @get_locks = 1
	 , @get_additional_info = 1;



 



	/*
	What filled up the transaction log?
	*/
	EXEC sp_WhoIsActive
	 @output_column_list = '[start_time][session_id][tran%][login%][sql_text][%]'
	 , @get_transaction_info = 1;







	/*
	What filled up tempdb?
	*/
	EXEC sp_WhoIsActive
	 @output_column_list = '[start_time][session_id][temp%][sql_text][query_plan][wait_info][%]'
	 , @get_plans = 1
	 , @sort_order = '[tempdb_current] DESC';






	/*
	What's using tempdb now?
	*/
	EXEC sp_WhoIsActive
	 @output_column_list = '[start_time][session_id][temp%][sql_text][query_plan][wait_info][%]'
	 , @delta_interval = 5
	 , @get_plans = 1
	 , @sort_order = '[tempdb_current_delta] DESC';






	/*
	What filled up the memory? (v12 only)
	*/
	EXEC sp_WhoIsActive
	 @output_column_list = '[start_time][session_id][%memory][login%][sql_text][%]'
	 , @get_memory_info = 1;






	/*
	Is there Parameter sniffing?
	Check plan estimates and actuals, look at Parameter List in Properties of SELECT and compare Parameter Compiled Value to Parameter Runtime Value.
	*/
	EXEC sp_WhoIsActive
	 @get_avg_time = 1
	 , @get_outer_command = 1 
	 , @get_plans = 1;






	/***********************************************
	 4. Create a table and job for tracking activity
	***********************************************/

	/*
	Create a table to track activity
	*/
	DECLARE 
	 @destination_table VARCHAR(500) = 'WhoIsActive'
	 , @schema VARCHAR(MAX);

	EXEC sp_WhoIsActive 
	 @get_transaction_info = 1
	 , @get_outer_command = 1
	 , @get_plans = 1
	 , @return_schema = 1
	 , @schema = @schema OUTPUT;

	SET @schema = REPLACE(@schema, '<table_name>', @destination_table);

	SELECT @schema;




	/*
	Create a clustered index on collection_time
	*/
	CREATE CLUSTERED INDEX cx_collection_time 
	ON WhoIsActive (collection_time);



	/*
	Create a job (with this step)
	*/
	DECLARE 
	 @destination_table VARCHAR(500) = 'WhoIsActive';

	EXEC sp_WhoIsActive 
	 @get_transaction_info = 1
	 , @get_outer_command = 1
	 , @get_plans = 1
     , @destination_table = @destination_table;


	 /*
	 Query the table
	 */
	 SELECT *
	 FROM WhoIsActive
	 WHERE collection_time BETWEEN '2023-03-12 00:00:00' AND '2023-03-12 01:00:00';




