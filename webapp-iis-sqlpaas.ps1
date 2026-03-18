param(
  [string]$SqlServer,
  [string]$DbName  = "DemoDB",
  [string]$SqlUser = "sqladmin",
  [string]$SqlPass = "P@ssw0rd123!Complex2026"   # IDENTIC cu azurerm_mssql_server
)

# --------- Conn string comun ---------
$sqlServerWithPort = "$SqlServer,1433"
$connStr           = "Server=$sqlServerWithPort;Database=$DbName;User Id=$SqlUser;Password=$SqlPass;Encrypt=yes;TrustServerCertificate=no;"

Write-Output "Connecting to: $SqlServer"
Write-Output "ConnStr (preview): Server=$sqlServerWithPort;Database=$DbName;User Id=$SqlUser;Encrypt=yes;..."

# --------- SQL init via .NET (fără sqlcmd) ---------
$createSql = @"
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Nume')
BEGIN
  CREATE TABLE dbo.Nume (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    Nume VARCHAR(100),
    Added DATETIME DEFAULT(GETDATE())
  );
END;

DELETE FROM dbo.Nume WHERE Id > 3;

INSERT INTO dbo.Nume (Nume)
VALUES ('Hello from Terraform'), ('PS Script OK'), ('Ready for CRUD');
"@

Add-Type -AssemblyName System.Data

try {
  $cn  = New-Object System.Data.SqlClient.SqlConnection $connStr
  $cn.Open()
  $cmd = $cn.CreateCommand()
  $cmd.CommandText = $createSql
  $cmd.ExecuteNonQuery() | Out-Null
  $cn.Close()
  Write-Output "SQL init done (table dbo.Nume, max 3 rows)."
}
catch {
  Write-Error "SQL init failed: $($_.Exception.Message)"
  throw
}

# --------- IIS + Classic ASP ---------
Install-WindowsFeature -Name Web-Server, Web-Mgmt-Tools, Web-ASP | Out-Null
Write-Output "IIS + Classic ASP installed."

# --------- Copiere fișiere statice ---------
# index.html și names.asp sunt descărcate de extensie în același folder cu acest script
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

$webRoot = 'C:\inetpub\wwwroot'

New-Item $webRoot -ItemType Directory -Force | Out-Null
New-Item "$webRoot\api" -ItemType Directory -Force | Out-Null

Copy-Item "$scriptDir\index.html" "$webRoot\index.html" -Force
Copy-Item "$scriptDir\names.asp" "$webRoot\api\names.asp" -Force

# --------- Înlocuire placeholder-e în fișiere ---------
# index.html: __SQLSERVER__ și __DBNAME__
$indexPath = "$webRoot\index.html"
$indexContent = Get-Content $indexPath -Raw
$indexContent = $indexContent.Replace('__SQLSERVER__', $SqlServer).Replace('__DBNAME__', $DbName)
Set-Content $indexPath $indexContent

# names.asp: __CONNSTR__
$apiPath = "$webRoot\api\names.asp"
$apiContent = Get-Content $apiPath -Raw
$apiContent = $apiContent.Replace('__CONNSTR__', $connStr)
Set-Content $apiPath $apiContent

iisreset | Out-Null
netsh advfirewall firewall add rule name="IIS-HTTP" dir=in action=allow protocol=TCP localport=80 | Out-Null

Write-Output "Deployment complete for $SqlServer"
