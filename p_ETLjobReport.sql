CREATE Procedure [dbo].[p_ETLjobReport] as
Begin
DECLARE @xp_results TABLE (job_id                UNIQUEIDENTIFIER NOT NULL,
                            last_run_date         INT              NOT NULL,
                            last_run_time         INT              NOT NULL,
                            next_run_date         INT              NOT NULL,
                            next_run_time         INT              NOT NULL,
                            next_run_schedule_id  INT              NOT NULL,
                            requested_to_run      INT              NOT NULL, -- BOOL
                            request_source        INT              NOT NULL,
                            request_source_id     sysname          COLLATE database_default NULL,
                            running               INT              NOT NULL, -- BOOL
                            current_step          INT              NOT NULL,
                            current_retry_attempt INT              NOT NULL,
                            job_state             INT              NOT NULL)

INSERT INTO @xp_results
EXECUTE master.dbo.xp_sqlagent_enum_jobs 1, sa
Declare @xml xml
;
with 
jobhistory as 
(
select jh.job_id, run_status, run_duration, run_date, RIGHT('000000'+CAST(run_time AS VARCHAR(6)),6) run_time from msdb.dbo.sysjobhistory jh 
	inner join 
		(select job_id, max(instance_id) inst from msdb.dbo.sysjobhistory group by job_id) last_jh on jh.job_id = last_jh.job_id and jh.instance_id = last_jh.inst
)
,ja as
(
select job_id, start_execution_date from msdb.dbo.sysjobactivity
where session_id = (select top 1 session_id FROM msdb.dbo.syssessions order by agent_start_date desc)
and start_execution_date is not null and stop_execution_date is null
)
,report as
(
select j.name, case when j.enabled = 1 then 'Yes' else 'No' end job, case when next_run_schedule_id = 0 then 'No' else 'Yes' end Sch,
case jh.run_status	when 0 then 'Failed'
								when 1 then 'Succeeded'
								when 2 then 'Retry'
								when 3 then 'Canceled'
								else 'No History'
			end last_run_status, DBA.dbo.[MinutesToDuration](run_duration, 1) last_run_duraiton, [DBA].[dbo].FormatRunDate(xpr.last_run_date, xpr.last_run_time) last_run, 
[DBA].[dbo].FormatRunDate(xpr.next_run_date, xpr.next_run_time) next_run,
case job_state
when 1	then 'Executing'
when 2	then 'Waiting for thread'
when 3	then 'Between retries'
when 4	then 'Idle'
when 5	then 'Suspended'
when 7	then 'Completing'
else cast(job_state as varchar(10)) end job_state, js.step_name Current_step, current_retry_attempt step_retry, 
			ja.start_execution_date, DBA.dbo.[MinutesToDuration](datediff(minute, start_execution_date, getdate()), 0) elapsedTime
from @xp_results xpr
inner join msdb.dbo.sysjobs j on xpr.job_id = j.job_id
left join msdb.dbo.sysjobsteps js on xpr.current_step = js.step_id and js.job_id = j.job_id 
left join jobhistory jh on j.job_id = jh.job_id
left join ja on ja.job_id = j.job_id
)
select @xml = (
select 
case when last_run_status = 'Failed' then 'error' when job_state = 'Executing' then 'warning' else 'done' end '@class'
 ,ISNULL(convert(varchar(100), name), '&nbsp;') td, ''
--,ISNULL(convert(varchar(100), job), '&nbsp;') td, ''
--,ISNULL(convert(varchar(100), Sch), '&nbsp;') td, ''
,ISNULL(convert(varchar(100), last_run_status), '&nbsp;') td, ''
,ISNULL(convert(varchar(100), job_state), '&nbsp;') td, ''
,ISNULL(convert(varchar(100), last_run_duraiton), '&nbsp;') td, ''
,ISNULL(convert(varchar(100), last_run), '&nbsp;') td, ''
,ISNULL(convert(varchar(100), next_run), '&nbsp;') td, ''
,ISNULL(convert(varchar(100), Current_step), '&nbsp;') td, ''
--,ISNULL(convert(varchar(100), step_retry), '&nbsp;') td, ''
,ISNULL(convert(varchar(100), start_execution_date), '&nbsp;') td , ''
,ISNULL(convert(varchar(100), elapsedTime), '&nbsp;') td, ''
 from report
where job = 'Yes' and Sch = 'Yes' --and name like 'ABC%' -- any addtional filters
order by job_state, case last_run_status when 'Failed' then 0 when 'Retry' then 1 when 'Canceled' then 3 when 'Succeeded' then 4 else 5 end, name
For XML PATH('tr')
 )

Declare @html varchar(max)
 select @html = '<html><body><style>body{font-family:"calibri";font-size:13px;}.error{color:red;}.warning{color:orange;}.done{color:green;}</style><table border="1" cellpadding="5"><tr><th>Name</th><th> last_run_status</th><th> job_state</th><th>last_run_duraiton</th><th> last_run</th><th> next_run</th><th>Current_step</th><th>Start_time</th><th>ElapsedTime</th></tr>'  
			+ replace(cast(@xml as varchar(max)), '&amp;', '&')
			+ '</table>'
 
 EXEC msdb.dbo.sp_send_dbmail
 	   @profile_name = 'DBA Profile',				
 	   @recipients = 'myEmail@implexsolutions.com', 	
  	   @importance =  'HIGH',
 	   @sensitivity='Confidential',	        
 	   @body = @html,
 	   @subject = 'Sql job Report',
 	   @body_format = 'HTML'
End

GO
