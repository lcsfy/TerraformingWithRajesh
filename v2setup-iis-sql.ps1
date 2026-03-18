# IIS + Firewall
Install-WindowsFeature Web-Server -IncludeManagementTools
netsh advfirewall firewall add rule name="HTTP80" dir=in action=allow protocol=TCP localport=80

# SQL installer
New-Item C:\temp -ItemType Directory -Force | Out-Null
Invoke-WebRequest 'https://download.microsoft.com/download/7/f/8/7f8a9c43-8c8a-4f7c-9f92-83c18d96b681/SQL2019-SSEI-Expr.exe' -OutFile C:\temp\SQL.exe
Start-Process C:\temp\SQL.exe -ArgumentList '/QS /ACTION=Install /FEATURES=SQLENGINE /INSTANCENAME=SQLEXPRESS /SQLSVCACCOUNT="NT AUTHORITY\NETWORK SERVICE" /ADDCURRENTUSERASSQLADMIN=1 /IACCEPTSQLSERVERLICENSETERMS=1' -Wait -NoNewWindow

# CHECK + WAIT LOOP - asteapta SQL pana porneste (max 5 min)
Write-Output "Waiting for SQL Express service..."
$timeout = 300  # 5 min
$elapsed = 0
do {
  $sqlSvc = Get-Service "SQL Server (SQLEXPRESS)" -ErrorAction SilentlyContinue
  if ($sqlSvc -and $sqlSvc.Status -eq 'Running') {
    Write-Output "SQL Express is running!"
    break
  }
  Write-Output "SQL not ready... waiting ($elapsed/$timeout sec)"
  Start-Sleep 10
  $elapsed += 10
} while ($elapsed -lt $timeout)

if (-not $sqlSvc -or $sqlSvc.Status -ne 'Running') {
  Write-Output "SQL Express FAILED to start - timeout!"
  $status = "SQL FAILED"
} else {
  # Test sqlcmd
  Start-Sleep 20  # Extra wait pentru sqlcmd
  sqlcmd -S .\SQLEXPRESS -E -Q "IF NOT EXISTS(SELECT * FROM sys.databases WHERE name='DemoDB') CREATE DATABASE DemoDB; USE DemoDB; IF OBJECT_ID('Nume') IS NULL CREATE TABLE Nume(Id INT IDENTITY PRIMARY KEY, Name VARCHAR(50)); DELETE FROM Nume; INSERT INTO Nume(Name) VALUES('Lucian'), ('Record 2'); SELECT COUNT(*) AS Records FROM Nume;"
  $records = sqlcmd -S .\SQLEXPRESS -E -d DemoDB -Q "SELECT COUNT(*) AS Total FROM Nume"
  $status = "SQL OK - $records records created!"
}

$content = @"
<!DOCTYPE html>
<html><head><title>IIS + SQL Status</title><meta charset='UTF-8'></head><body style='font-family:Arial;padding:40px;'>
<h1>Setup Complete</h1>
<h2>SQL Express: $status</h2>
<p>Script finished: $(Get-Date)</p>
<p>Service status: $((Get-Service 'SQL Server (SQLEXPRESS)' -ErrorAction SilentlyContinue).Status)</p>
</body></html>
"@

Set-Content 'C:\inetpub\wwwroot\index.html' $content
iisreset /restart
