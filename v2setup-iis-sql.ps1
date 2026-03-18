Install-WindowsFeature -Name Web-Server -IncludeManagementTools

New-Item -ItemType Directory -Path 'C:\temp' -Force | Out-Null
$sqlUrl = 'https://download.microsoft.com/download/2/1/0/210B5C9A-DF68-4AA0-9A2D-6A1E1E6A9791/SQL2019-SSEI-Expr.exe'
$sqlInstaller = 'C:\temp\SQL2019-SSEI-Expr.exe'
Invoke-WebRequest -Uri $sqlUrl -OutFile $sqlInstaller

& $sqlInstaller /ACTION=Install /QUIET /IACCEPTSQLSERVERLICENSETERMS /FEATURES=SQLENGINE /INSTANCENAME=SQLEXPRESS /SQLSVCACCOUNT='NT AUTHORITY\NETWORK SERVICE' /ADDCURRENTUSERASSQLADMIN=1

netsh advfirewall firewall add rule name="Open HTTP 80" dir=in action=allow protocol=TCP localport=80

# FIX: Creează DB + date TEST (cu output verificat)
sqlcmd -S .\SQLEXPRESS -E -Q "IF NOT EXISTS(SELECT * FROM sys.databases WHERE name='MyDemoDB') CREATE DATABASE MyDemoDB; USE MyDemoDB; IF OBJECT_ID('Nume', 'U') IS NULL CREATE TABLE Nume (Id INT IDENTITY PRIMARY KEY, Numele NVARCHAR(100)); DELETE FROM Nume; INSERT INTO Nume (Numele) VALUES ('Lucian Enache'), ('Demo User 2'); SELECT COUNT(*) AS Records FROM Nume;"

# FIX: Citește DB și formatează HTML corect
$records = sqlcmd -S .\SQLEXPRESS -E -d MyDemoDB -h-1 -W -s' | ' "SELECT CAST(Id AS VARCHAR(10)) AS ID, Numele FROM Nume ORDER BY Id;"
$htmlList = ($records -split "`n" | ForEach-Object { "<li>$_</li>" }) -join "`n"

$content = @"
<!DOCTYPE html>
<html>
<head><title>Lucian IIS + SQL Live Demo</title><style>body{font-family:Arial;}</style></head>
<body>
<h1>✅ IIS + SQL Express - FUNCȚIONEAZĂ!</h1>
<h2>Date LIVE din MyDemoDB.Nume:</h2>
<ul>
$htmlList
</ul>
<p><strong>Număr înregistrări: $($records.Count)</strong></p>
<hr>
<p><small>Script GitHub rulat cu succes via Terraform Custom Script Extension!</small></p>
</body>
</html>
"@

Set-Content -Path 'C:\inetpub\wwwroot\index.html' -Value $content -Encoding UTF8
iisreset /restart
