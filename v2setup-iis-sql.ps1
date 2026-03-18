# IIS
Install-WindowsFeature -Name Web-Server -IncludeManagementTools | Out-Null

# FORȚEAZĂ C:\temp
if (-not (Test-Path 'C:\temp')) { New-Item 'C:\temp' -ItemType Directory -Force | Out-Null }
Remove-Item 'C:\temp\*' -Force -Recurse -ErrorAction SilentlyContinue

# Prereq VC++ (pentru SQL)
$vcUrl = 'https://aka.ms/vs/17/release/vc_redist.x64.exe'
Invoke-WebRequest -Uri $vcUrl -OutFile 'C:\temp\vc_redist.exe' -UseBasicParsing
Start-Process 'C:\temp\vc_redist.exe' -ArgumentList '/quiet','/norestart' -Wait -NoNewWindow | Out-Null

# SQL installer
$sqlUrl = 'https://download.microsoft.com/download/7/f/8/7f8a9c43-8c8a-4f7c-9f92-83c18d96b681/SQL2019-SSEI-Expr.exe'
$sqlExe = 'C:\temp\sql_installer.exe'  # Nume safe
if (Test-Path $sqlExe) { Remove-Item $sqlExe -Force }
Invoke-WebRequest -Uri $sqlUrl -OutFile $sqlExe -UseBasicParsing

# Instal SQL
Write-Output "SQL install start..."
$p = Start-Process -FilePath $sqlExe -ArgumentList @(
    '/ACTION=Install', '/QS', '/NORESTART', '/IACCEPTSQLSERVERLICENSETERMS',
    '/FEATURES=SQLENGINE', '/INSTANCENAME=SQLEXPRESS', '/TCPENABLED=1',
    '/SQLSVCACCOUNT="NT AUTHORITY\NETWORK SERVICE"', 
    '/SQLSYSADMINACCOUNTS="BUILTIN\Administrators"',
    '/SKIPRULES=RebootRequired'
) -PassThru -Wait

if ($p.ExitCode -ne 0 -or $p.ExitCode -gt 3010) {
    Write-Output "SQL FAIL. Exit: $($p.ExitCode). Logs:"
    Get-ChildItem 'C:\temp' -Filter '*.log','Summary.txt' | ForEach { Get-Content $_.FullName -Tail 10 }
    exit 1
}

# Wait SQL ready (max 15min)
$waited = 0
do {
    Start-Sleep 20
    $waited += 20
    $svc = Get-Service 'MSSQL$SQLEXPRESS' -ErrorAction SilentlyContinue
} while ((-not $svc -or $svc.Status -ne 'Running') -and $waited -lt 900)

if ($svc.Status -ne 'Running') { 
    Write-Error "SQL service down after 15min"; exit 1 
}

# Test query
Start-Sleep 60
$test = sqlcmd -S .\SQLEXPRESS -E -Q "SELECT @@VERSION" -h-1 2>$null
if (-not $test) { Write-Error "sqlcmd fail"; exit 1 }

# DB + live data
sqlcmd -S .\SQLEXPRESS -E -Q "CREATE DATABASE DemoDB IF NOT EXISTS"
sqlcmd -S .\SQLEXPRESS -E -d DemoDB -Q @"
IF NOT EXISTS(SELECT * FROM sys.tables WHERE name='Nume')
    CREATE TABLE Nume(Id INT IDENTITY PRIMARY KEY, Nume VARCHAR(100), Created DATETIME DEFAULT GETDATE());
TRUNCATE TABLE Nume;
INSERT INTO Nume (Nume) VALUES ('Lucian Enache'), ('Terraform Win'), ('$(hostname)');
"@

# LIVE query pentru HTML
$count = sqlcmd -S .\SQLEXPRESS -E -d DemoDB -Q "SELECT COUNT(*) FROM Nume" -h-1
$rows = sqlcmd -S .\SQLEXPRESS -E -d DemoDB -Q "SELECT Id, Nume, Created FROM Nume ORDER BY Id" -h-1 -s',' -W

$html = @"
<!DOCTYPE html>
<title>IIS + SQL Live</title>
<style>body{padding:20px;font-family:Arial;}
table{border-collapse:collapse;width:100%;} th,td{border:1px solid #ddd;padding:8px;}
th{background:#f2f2f2;}</style>
<h1>✅ SQL Express + IIS Success!</h1>
<p>Rows: <b>$count</b> | Server: <b>$(hostname)</b></p>
<table><tr><th>ID</th><th>Nume</th><th>Created</th></tr>$($rows -replace '^','<tr><td>')replace('\n','</td></tr><tr><td>')</table>
"@

$html | Out-File 'C:\inetpub\wwwroot\index.html' -Encoding UTF8

netsh advfirewall firewall add rule name="HTTP" dir=in action=allow protocol=TCP localport=80
iisreset /timeout 60

Write-Output "SUCCESS - Check http://localhost"
