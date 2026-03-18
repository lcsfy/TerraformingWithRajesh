Install-WindowsFeature -Name Web-Server -IncludeManagementTools | Out-Null

New-Item 'C:\temp' -ItemType Directory -Force | Out-Null

# SQL installer
$sqlUrl = 'https://download.microsoft.com/download/7/f/8/7f8a9c43-8c8a-4f7c-9f92-83c18d96b681/SQL2019-SSEI-Expr.exe'
$sqlPath = 'C:\temp\SQL2019-SSEI-Expr.exe'
Invoke-WebRequest $sqlUrl -OutFile $sqlPath -UseBasicParsing

# Instal cu wait + log
Start-Process $sqlPath -ArgumentList @(
    '/ACTION=Install','/QUIET','/NORESTART','/IACCEPTSQLSERVERLICENSETERMS',
    '/FEATURES=SQLENGINE','/INSTANCENAME=SQLEXPRESS',
    '/SQLSVCACCOUNT="NT AUTHORITY\NETWORK SERVICE"','/ADDCURRENTUSERASSQLADMIN=1',
    '/SKIPRULES=RebootRequired','/LOGGINGLEVEL=Full','/SQLLOGDIR="C:\temp"'
) -Wait -NoNewWindow

if ($LASTEXITCODE -ne 0) { 
    Get-Content 'C:\temp\Summary.txt' | Write-Output 
    exit $LASTEXITCODE 
}

# SUPER WAIT pentru SQL + DB ready (max 20min)
$maxWait = 1200  # secunde
$start = Get-Date
do {
    $service = Get-Service 'MSSQL$SQLEXPRESS' -ErrorAction SilentlyContinue
    if ($service -and $service.Status -eq 'Running') {
        # Test sqlcmd
        $version = sqlcmd -S .\SQLEXPRESS -E -Q "SELECT @@VERSION" -h-1 -W -w 300 2>$null
        if ($version -and $version -match 'Microsoft SQL Server') { break }
    }
    Start-Sleep 30
    $elapsed = (Get-Date) - $start
} while ($elapsed.TotalSeconds -lt $maxWait)

if ($elapsed.TotalSeconds -ge $maxWait) { 
    Write-Error "SQL/DB timeout after 20min. Service: $($service.Status)"; exit 1 
}

Write-Output "SQL ready! Version: $version"

# Creează DB + table + data
sqlcmd -S .\SQLEXPRESS -E -Q "
IF NOT EXISTS(SELECT name FROM sys.databases WHERE name='DemoDB') 
    CREATE DATABASE DemoDB;
"
sqlcmd -S .\SQLEXPRESS -E -d DemoDB -Q "
IF OBJECT_ID('Nume','U') IS NULL 
    CREATE TABLE Nume(Id INT IDENTITY PRIMARY KEY, Nume VARCHAR(100));
DELETE FROM Nume;
INSERT INTO Nume(Nume) VALUES('Lucian Enache'),('Demo User'),('Azure Terraform');
"

# LIVE QUERY pentru HTML
$recordCount = sqlcmd -S .\SQLEXPRESS -E -d DemoDB -h-1 -Q "SELECT COUNT(*) FROM Nume"
$liveRecords = sqlcmd -S .\SQLEXPRESS -E -d DemoDB -h-1 -Q "SELECT TOP 10 CAST(Id AS VARCHAR(10)) + ': ' + Nume FROM Nume ORDER BY Id" -W

# Gen HTML cu live data
$html = @"
<!DOCTYPE html>
<html><head><title>IIS + SQL Live Demo</title>
<style>body{font-family:Segoe UI;padding:20px;max-width:800px;margin:auto;}
h1{color:#0078d4;} pre{background:#f0f0f0;padding:15px;border-radius:8px;font-family:Consolas;}
.stats{background:#e3f2fd;padding:10px;border-radius:5px;}</style>
</head><body>
<h1>✅ IIS + SQL Server Express 2019</h1>
<div class='stats'>
<p><strong>Live Records:</strong> $recordCount</p>
<p><strong>Query Time:</strong> $(Get-Date -Format 'HH:mm:ss')</p>
<p><strong>Server:</strong> $(hostname)</p>
</div>
<h2>DemoDB.dbo.Nume (LIVE QUERY):</h2>
<pre>$liveRecords</pre>
<hr><p>Terraform CustomScriptExtension success! <a href='https://github.com'>Source</a></p>
</body></html>
"@
$html | Out-File 'C:\inetpub\wwwroot\index.html' -Encoding UTF8

# Firewall + IIS
netsh advfirewall firewall add rule name='HTTP80' dir=in action=allow protocol=TCP localport=80
iisreset

Write-Output "✅ Setup done! Visit http://localhost/index.html"
