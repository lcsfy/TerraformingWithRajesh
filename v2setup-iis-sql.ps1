# IIS + Firewall
Install-WindowsFeature -Name Web-Server -IncludeManagementTools
netsh advfirewall firewall add rule name="Open Port 80" dir=in action=allow protocol=TCP localport=80

# SQL Express install
New-Item -ItemType Directory -Path 'C:\temp' -Force | Out-Null
$sqlUrl = 'https://download.microsoft.com/download/2/1/0/210B5C9A-DF68-4AA0-9A2D-6A1E1E6A9791/SQL2019-SSEI-Expr.exe'
$sqlInstaller = 'C:\temp\SQL2019-SSEI-Expr.exe'
Invoke-WebRequest -Uri $sqlUrl -OutFile $sqlInstaller
& $sqlInstaller /ACTION=Install /QUIET /IACCEPTSQLSERVERLICENSETERMS /FEATURES=SQLENGINE /INSTANCENAME=SQLEXPRESS /SQLSVCACCOUNT='NT AUTHORITY\NETWORK SERVICE' /ADDCURRENTUSERASSQLADMIN=1

# DEBUG: Asteapta SQL service + testeaza
Write-Output "Waiting for SQL Express..."
Start-Sleep -Seconds 60
$sqlService = Get-Service -Name 'SQL Server (SQLEXPRESS)'
if ($sqlService.Status -ne 'Running') { 
  Restart-Service 'SQL Server (SQLEXPRESS)' -Force
  Start-Sleep -Seconds 30 
}

# Test conexiune SQL
Write-Output "Testing SQL connection..."
sqlcmd -S .\SQLEXPRESS -E -Q "SELECT @@VERSION" > C:\temp\sql-test.txt

# Creeaza DB + date - cu verificare
Write-Output "Creating DB..."
sqlcmd -S .\SQLEXPRESS -E -Q "IF NOT EXISTS(SELECT * FROM sys.databases WHERE name='DemoDB') CREATE DATABASE DemoDB"
sqlcmd -S .\SQLEXPRESS -E -d DemoDB -Q "IF OBJECT_ID('Nume','U') IS NULL CREATE TABLE Nume(Id INT IDENTITY PRIMARY KEY, Nume VARCHAR(100))"
sqlcmd -S .\SQLEXPRESS -E -d DemoDB -Q "DELETE FROM Nume"
sqlcmd -S .\SQLEXPRESS -E -d DemoDB -Q "INSERT INTO Nume(Nume) VALUES('Lucian'), ('Rajesh'), ('Demo User')"

# Citeste rezultatul
$recordCount = sqlcmd -S .\SQLEXPRESS -E -d DemoDB -h-1 -Q "SELECT COUNT(*) AS Total FROM Nume"
$recordsRaw = sqlcmd -S .\SQLEXPRESS -E -d DemoDB -h-1 -Q "SELECT CAST(Id AS VARCHAR)+': '+Nume FROM Nume"
$records = $recordsRaw -replace "`r`n","<br>"

$content = @"
<!DOCTYPE html>
<html>
<head><title>IIS + SQL Debug</title>
<meta charset='UTF-8'>
<style>body{font-family:Arial;padding:20px;} pre{background:#f5f5f5;padding:15px;}</style>
</head>
<body>
<h1>IIS + SQL Express Debug Mode</h1>
<h2>DemoDB.Nume Status:</h2>
<p><b>Total records:</b> $recordCount</p>
<h3>All records:</h3>
<pre>$records</pre>
<h3>SQL Service:</h3>
<pre>$(Get-Service 'SQL Server (SQLEXPRESS)' | Select Status,StartType)</pre>
<h3>Debug files:</h3>
<ul>
<li><a href='/temp/sql-test.txt'>SQL Version Test</a></li>
</ul>
</body>
</html>
"@

Set-Content -Path 'C:\inetpub\wwwroot\index.html' -Value $content -Encoding UTF8
iisreset /restart
