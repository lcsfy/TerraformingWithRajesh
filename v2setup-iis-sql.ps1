# 1. FORȚEAZĂ dir + IIS
New-Item -Path 'C:\temp' -ItemType Directory -Force -ErrorAction Stop | Out-Null
Install-WindowsFeature -Name Web-Server -IncludeManagementTools -ErrorAction Stop | Out-Null

# 2. Cleanup vechi
Get-ChildItem 'C:\temp' -Recurse | Remove-Item -Force -ErrorAction SilentlyContinue

# 3. VC++ prereq (SQL dep)
$vcUrl = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
$vcExe = "C:\temp\vc_redist.exe"
Invoke-WebRequest -Uri $vcUrl -OutFile $vcExe -UseBasicParsing -ErrorAction Stop
Start-Process -FilePath $vcExe -ArgumentList "/quiet", "/norestart" -Wait -NoNewWindow | Out-Null
Remove-Item $vcExe -Force  # Cleanup

# 4. SQL installer
$sqlUrl = "https://download.microsoft.com/download/7/f/8/7f8a9c43-8c8a-4f7c-9f92-83c18d96b681/SQL2019-SSEI-Expr.exe"
$sqlExe = "C:\temp\sql.exe"
Invoke-WebRequest -Uri $sqlUrl -OutFile $sqlExe -UseBasicParsing -ErrorAction Stop

# 5. Instal SQL
$args = @(
    '/ACTION=Install', '/QS', '/NORESTART', '/IACCEPTSQLSERVERLICENSETERMS',
    '/FEATURES=SQLENGINE', '/INSTANCENAME=SQLEXPRESS', '/TCPENABLED=1',
    '/SQLSVCACCOUNT="NT AUTHORITY\NETWORK SERVICE"', '/SQLSYSADMINACCOUNTS="BUILTIN\Administrators"',
    '/SKIPRULES=RebootRequired'
)
$proc = Start-Process -FilePath $sqlExe -ArgumentList $args -Wait -PassThru -NoNewWindow -ErrorAction Stop

if ($proc.ExitCode -ne 0) {
    "SQL ExitCode: $($proc.ExitCode)" | Out-File 'C:\temp\error.log'
    Get-ChildItem 'C:\temp' -Filter '*Summary*' | ForEach { Get-Content $_.FullName -Tail 20 } | Tee-Object 'C:\temp\logs.txt'
    exit 1
}

# 6. Wait service + test (10 loops = 5min)
for ($i = 0; $i -lt 10; $i++) {
    $svc = Get-Service 'MSSQL$SQLEXPRESS' -ErrorAction SilentlyContinue
    if ($svc -and $svc.Status -eq 'Running') {
        Start-Sleep 45
        $ver = sqlcmd -S .\SQLEXPRESS -E -Q "SELECT @@VERSION" -h-1 -W 2>$null
        if ($ver -match "SQL Server") { break }
    }
    Start-Sleep 30
}

if (-not $ver) { "SQL test fail" | Out-File 'C:\temp\sql_fail.txt'; exit 1 }

# 7. DB + data
sqlcmd -S .\SQLEXPRESS -E -Q "IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'DemoDB') CREATE DATABASE DemoDB"
sqlcmd -S .\SQLEXPRESS -E -d DemoDB -Q "IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Nume') CREATE TABLE Nume (Id INT IDENTITY PRIMARY KEY, Nume VARCHAR(100)); TRUNCATE TABLE Nume; INSERT INTO Nume (Nume) VALUES ('Lucian'), ('Demo $(Get-Date -Format ''yyyy-MM-dd'')')"

# 8. LIVE query
$count = sqlcmd -S .\SQLEXPRESS -E -d DemoDB -Q "SELECT COUNT(*) FROM Nume" -h-1
$data = sqlcmd -S .\SQLEXPRESS -E -d DemoDB -Q "SELECT * FROM Nume" -h-1 -W -s '|'

# 9. HTML cu table
$html = @"
<!DOCTYPE html><html><head><title>✅ IIS+SQL</title><meta charset="UTF-8">
<style>body{font-family:Arial;padding:20px;}table{border-collapse:collapse;width:100%;}th,td{border:1px solid #ccc;padding:12px;text-align:left;}th{background:#4285f4;color:white;}</style></head>
<body><h1>IIS + SQL Express Live Demo</h1>
<p><strong>Rows:</strong> $count | <strong>Time:</strong> $(Get-Date)</p>
<table><tr><th>ID</th><th>Nume</th></tr>$($data.Split("`n") -join '</td></tr><tr><td>')</table>
<p><small>Terraform CustomScript OK</small></p></body></html>
"@
$html | Out-File 'C:\inetpub\wwwroot\index.html' -Encoding UTF8

# 10. Final
netsh advfirewall firewall add rule name="IIS80" dir=in action=allow protocol=TCP localport=80
iisreset /restart

"Script 100% SUCCESS" | Out-File 'C:\temp\success.txt'
