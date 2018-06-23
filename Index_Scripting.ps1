param(
    [Parameter(Mandatory=$false)] [string]$Instance="DILBERT\SQL2017",
    [Parameter(Mandatory=$false)] [string]$Database="AdventureWorks2016CTP3",
    [Parameter(Mandatory=$false)] [string]$Username,
    [Parameter(Mandatory=$false)] [string]$Password,
    [Parameter(Mandatory=$false)] [boolean]$IncludeClusteredIndexes=$True,
    [Parameter(Mandatory=$false)] [boolean]$ScriptToDrop=$False,
    [Parameter(Mandatory=$false)] [string]$ScriptPath
    )

clear-host

$scripterDirectory = Split-Path $MyInvocation.MyCommand.Path

Try
{

    [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.ConnectionInfo") | out-null
    [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null 

    if (![string]::IsNullOrEmpty($Username) -And [string]::IsNullOrEmpty($Password)) {
        [System.Security.SecureString]$SecurePassword = Read-Host "Enter Password" -AsSecureString
        [String]$Password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword));
    }

    if ([string]::IsNullOrEmpty($ScriptPath)) { $ScriptPath= $scripterDirectory }

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

    $scripter = new-object ('Microsoft.SqlServer.Management.Smo.Scripter') ($Server)

    $scripter.Options.ScriptDrops = $scriptToDrop
    $scripter.Options.ClusteredIndexes = $IncludeClusteredIndexes
    $scripter.Options.DriAll = $True
    $scripter.Options.ContinueScriptingOnError = $True
    $scripter.Options.IncludeIfNotExists = $True
    $scripter.Options.IncludeHeaders = $True
    $scripter.Options.ToFileOnly = $True
    $scripter.Options.Indexes = $True
    $scripter.Options.WithDependencies = $False
    $scripter.Options.IncludeDatabaseContext = $True
    $scripter.Options.FileName = "$ScriptPath\$($db.Name)_IDX_" + $Action + ".sql"

    $smoObjects = New-Object Microsoft.SqlServer.Management.Smo.UrnCollection

    # Generate IDX script for tables
    foreach ($tb in $db.Tables) 
    {
        If ($tb.IsSystemObject -eq $false)
        {
            foreach ($ix in $tb.Indexes) 
            {     
                $smoObjects.Add($ix.Urn)
            }
        }
    }

    # Generate IDX script for indexed view
    Foreach ($vw in $db.Views)
    {
       If ($vw.IsSystemObject -eq $false)
       {
          foreach ($ix in $vw.Indexes) 
            {     
                $smoObjects.Add($ix.Urn)
            }
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