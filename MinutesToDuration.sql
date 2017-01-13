CREATE FUNCTION [dbo].[MinutesToDuration]
(
    @minutes int , @format int = 0
)
RETURNS nvarchar(100)

AS
BEGIN
   if (@format = 1) set @minutes = @minutes / 10000 * 60 + ((@minutes % 10000) / 100) 

   Declare @time varchar(100) = ''

	 if (@minutes > 1440)
		  select @time = cast(@minutes / 1440 as varchar(5)) + 'd ', @minutes = @minutes % 1440 
      
	select @time = @time + CAST((@minutes / 60) AS VARCHAR(2)) + 'h ', @minutes = @minutes % 60
	select @time = @time + CAST(@minutes AS VARCHAR(2)) + 'm '

   return @time
END

