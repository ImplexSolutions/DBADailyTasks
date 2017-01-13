CREATE FUNCTION [dbo].[FormatRunDate] 
(
 @run_date int,
 @run_time int
 )
 returns datetime
 as 
 Begin
   if (@run_date = 0 or @run_time = 0 ) return null
   Declare @date date = cast(cast(@run_date as varchar(8)) as date)
	return dateadd(second, (@run_time % 100), dateadd(minute, (@run_time % 10000) / 100, dateadd(hour, @run_time / 10000, cast(@date as datetime))))
 End
