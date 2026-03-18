
$sqlUrl = 'https://download.microsoft.com/download/7/f/8/7f8a9c43-8c8a-4f7c-9f92-83c18d96b681/SQL2019-SSEI-Expr.exe'

Install-WindowsFeature -Name Web-Server -IncludeManagementTools

New-Item -ItemType Directory -Path 'C:\temp' -Force | Out-Null
$sqlUrl = 'https://download.microsoft.com/download/7/f/8/7f8a9c43-8c8a-4f7c-9f92-83c18d96b681/SQL2019-SSEI-Expr.exe'
$sqlInstaller = 'C:\temp\SQL2019-SSEI-Expr.exe'
Invoke-WebRequest -Uri $sqlUrl -OutFile $sqlInstaller

& $sqlInstaller /ACTION=Install /QUIET /IACCEPTSQLSERVERLICENSETERMS /FEATURES=SQLENGINE /INSTANCENAME=SQLEXPRESS /SQLSVCACCOUNT='NT AUTHORITY\NETWORK SERVICE' /ADDCURRENTUSERASSQLADMIN=1

Start-Sleep -Seconds 30

netsh advfirewall firewall add rule name="Open Port 80" dir=in action=allow protocol=TCP localport=80

# Fix DB creation + test data - sintaxa simplificata
sqlcmd -S .\SQLEXPRESS -E -Q "IF NOT EXISTS(SELECT * FROM sys.databases WHERE name='DemoDB') CREATE DATABASE DemoDB"
sqlcmd -S .\SQLEXPRESS -E -d DemoDB -Q "IF OBJECT_ID('Nume','U') IS NULL CREATE TABLE Nume(Id INT IDENTITY PRIMARY KEY, Nume VARCHAR(100))"
sqlcmd -S .\SQLEXPRESS -E -d DemoDB -Q "DELETE FROM Nume; INSERT INTO Nume(Nume) VALUES('Lucian'),('Demo User')"

# Verifica DB
$recordCount = sqlcmd -S .\SQLEXPRESS -E -d DemoDB -h-1 -Q "SELECT COUNT(*) AS Total FROM Nume"
$records = sqlcmd -S .\SQLEXPRESS -E -d DemoDB -h-1 -Q "SELECT CAST(Id AS VARCHAR)+': '+Nume FROM Nume"

$content = @"
<!DOCTYPE html>
<html>
<head><title>IIS + SQL Demo</title>
<meta charset='UTF-8'>
<style>body{font-family:Arial;padding:20px;} h1{color:green;}</style>
</head>
<body>
<h1>IIS + SQL Express - Working!</h1>
<h2>DemoDB.Nume table:</h2>
<p><b>Total records: $recordCount</b></p>
<pre style='background:#f5f5f5;padding:15px;border-radius:5px;font-family:monospace;'>
$records
</pre>
<hr>
<p>Test completed successfully via Terraform + GitHub script!</p>
</body>
</html>
"@

Set-Content -Path 'C:\inetpub\wwwroot\index.html' -Value $content -Encoding UTF8
iisreset /restart
