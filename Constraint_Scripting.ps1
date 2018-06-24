param(
    [Parameter(Mandatory=$false)] [string]$Instance="localhost",
    [Parameter(Mandatory=$false)] [string]$Database="AdventureWorks2016CTP3",
    [Parameter(Mandatory=$false)] [string]$Username="sa",
    [Parameter(Mandatory=$false)] [string]$Password,
    [Parameter(Mandatory=$false)] [boolean]$ScriptToDrop=$False,
    [Parameter(Mandatory=$false)] [string]$ScriptPath 
    )

clear-host

$ScriptDirectory = Split-Path $MyInvocation.MyCommand.Path

Try
{

    [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.ConnectionInfo") | out-null
    [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null 

    if (![string]::IsNullOrEmpty($Username) -And [string]::IsNullOrEmpty($Password)) {
        [System.Security.SecureString]$SecurePassword = Read-Host "Enter Password" -AsSecureString
        [String]$Password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword));
    }

    if ([string]::IsNullOrEmpty($ScriptPath)) { $ScriptPath= $ScriptDirectory }

    if ($ScriptToDrop -eq $False) { $Action = "Create" } else { $Action = "Drop" }


    $Conn = New-Object Microsoft.SqlServer.Management.Common.ServerConnection
    $Conn.ServerInstance=$Instance

    $Server = New-Object Microsoft.SqlServer.Management.Smo.Server($Conn)

    if (![string]::IsNullOrEmpty($Username)) {
        $Server.ConnectionContext.LoginSecure = $false
        $Server.ConnectionContext.Login=$Username
        $Server.ConnectionContext.Password=$Password
    }

    $db = $Server.Databases.Item($Database)

    if ($db.name -ne $Database) { Throw "Can't find the database '$Database' in $Instance" }

    $scripter = New-Object ('Microsoft.SqlServer.Management.Smo.Scripter') ($Server)

    $scripter.Options.ScriptDrops = $ScriptToDrop;
    $scripter.Options.DriForeignKeys = $true;
    $scripter.Options.DriChecks = $true;
    $scripter.Options.ContinueScriptingOnError = $True
    $scripter.Options.IncludeIfNotExists = $True
    $scripter.Options.IncludeHeaders = $True
    $scripter.Options.ToFileOnly = $True
    $scripter.Options.IncludeDatabaseContext = $True
    $scripter.Options.FileName = "$ScriptPath\$($db.Name)_Constraints_" + $Action + ".sql"

    $smoObjects = New-Object Microsoft.SqlServer.Management.Smo.UrnCollection

    $dbObjCollection = @();

    foreach($tb in $db.Tables)
    {
      $dbObjCollection += $tb.Checks;
      $dbObjCollection += $tb.ForeignKeys;
    }

    foreach ($dbObj in $dbObjCollection) 
    {   
        If ($dbObj.Parent.IsSystemObject -eq $false) {       
            $smoObjects.Add($dbObj.Urn)
         }
    }

    $sc = $scripter.Script($smoObjects)

}
Catch
{   
  $errorMessage = $_.Exception.Message
  $line = $_.InvocationInfo.ScriptLineNumber
  $script_name = $_.InvocationInfo.ScriptName
  Write-Host "Error: Occurred on line $line in script $script_name." -ForegroundColor Red
  Write-Host "Error: $ErrorMessage" -ForegroundColor Red
}
