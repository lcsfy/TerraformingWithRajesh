# Prereqs (VC++ redist pentru SQL)
$vcUrl = 'https://aka.ms/vs/17/release/vc_redist.x64.exe'
Invoke-WebRequest $vcUrl -OutFile 'C:\temp\vc_redist.exe' -UseBasicParsing
& 'C:\temp\vc_redist.exe' /quiet /norestart | Out-Null

# IIS
Install-WindowsFeature Web-Server,Web-Mgmt-Tools | Out-Null

# Clean temp
rmdir C:\temp -Recurse -Force -ErrorAction SilentlyContinue
New-Item C:\temp -Force | Out-Null

# SQL
$sqlUrl = 'https://download.microsoft.com/download/7/f/8/7f8a9c43-8c8a-4f7c-9f92-83c18d96b681/SQL2019-SSEI-Expr.exe'
$sqlExe = 'C:\temp\SQL.exe'
Invoke-WebRequest $sqlUrl -OutFile $sqlExe

Write-Output "Installing SQL..."
$proc = Start-Process $sqlExe -ArgumentList @(
    '/ACTION=Install','/QS','/NORESTART','/IACCEPTSQLSERVERLICENSETERMS',
    '/FEATURES=SQLENGINE','/INSTANCENAME=SQLEXPRESS','/TCPENABLED=1',
    '/SQLSVCACCOUNT="NT AUTHORITY\NETWORK SERVICE"','/SQLSYSADMINACCOUNTS="BUILTIN\Administrators"',
    '/SKIPRULES=RebootRequired','/IAcceptSQLServerLicenseTerms'
) -PassThru -Wait

if ($proc.ExitCode -ne 0) {
    Write-Output "SQL FAIL exit: $($proc.ExitCode). Logs in C:\temp"
    Get-Content C:\temp\*.log | Select -Last 20
    exit 1
}

# Wait & test SQL (10min max)
for ($i=0; $i -lt 120; $i++) {
    if ((Get-Service MSSQL$SQLEXPRESS).Status -eq 'Running') {
        Start-Sleep 60
        try {
            sqlcmd -S .\SQLEXPRESS -E -Q "SELECT @@VERSION" -h-1 -W
            break
        } catch {}
    }
    Start-Sleep 30
}

# DB live
sqlcmd -S .\SQLEXPRESS -E -Q "CREATE DATABASE DemoDB"
sqlcmd -S .\SQLEXPRESS -E -d DemoDB -Q "CREATE TABLE Nume(Id INT PRIMARY KEY, Nume VARCHAR(50)); INSERT INTO Nume VALUES (1,'Lucian'),(2,'Success'),(3,'$(hostname)')"

# Query live pentru HTML
$count = sqlcmd -S .\SQLEXPRESS -E -d DemoDB -Q "SELECT COUNT(*) FROM Nume" -h-1
$data = sqlcmd -S .\SQLEXPRESS -E -d DemoDB -Q "SELECT * FROM Nume" -h-1

@"
<h1>LIVE SQL Data ($count rows)</h1><pre>$data</pre>
"@ | Out-File C:\inetpub\wwwroot\index.html -Encoding UTF8

netsh advfirewall firewall add rule name="Port80" dir=in action=allow protocol=TCP localport=80
iisreset
