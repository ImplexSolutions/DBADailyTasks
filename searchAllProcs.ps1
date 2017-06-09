param (
    [Parameter(Mandatory=$true)][string]$serverName,
	[Parameter(Mandatory=$true)][string]$searchPattern
)
	
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO')
$sqlserver = New-Object('Microsoft.SqlServer.Management.Smo.Server') $serverName
$databases = $sqlserver.databases


$so = new-object (‘Microsoft.SqlServer.Management.Smo.ScriptingOptions’)
$so.IncludeIfNotExists = 0
$so.SchemaQualify = 1
$so.AllowSystemObjects = 0
$so.ScriptDrops = 0         
Clear-Host

$line = 1

foreach ($database in $databases)
{
  foreach($storedProcedure in $database.StoredProcedures)
  {
	if ($storedProcedure.Schema -eq "sys") { Continue };
	[console]::setcursorposition(0, $line)
	$database.Name + "." + $storedProcedure.Schema + "." + $storedProcedure.Name + " " * 100
	
	if ($storedProcedure.Script($so) -like $searchPattern)
	{
		[console]::setcursorposition(0, $line)
		$database.Name + "." + $storedProcedure.Schema + "." + $storedProcedure.Name + " " * 100
		$line = $line + 1
	}
  }
}
[console]::setcursorposition(0, $line)
" " * 200
