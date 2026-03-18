Install-WindowsFeature -Name Web-Server -IncludeManagementTools

New-Item -ItemType Directory -Path 'C:\temp' -Force | Out-Null
$sqlUrl = 'https://download.microsoft.com/download/2/1/0/210B5C9A-DF68-4AA0-9A2D-6A1E1E6A9791/SQL2019-SSEI-Expr.exe'
$sqlInstaller = 'C:\temp\SQL2019-SSEI-Expr.exe'
Invoke-WebRequest -Uri $sqlUrl -OutFile $sqlInstaller

& $sqlInstaller /ACTION=Install /QUIET /IACCEPTSQLSERVERLICENSETERMS /FEATURES=SQLENGINE /INSTANCENAME=SQLEXPRESS /SQLSVCACCOUNT='NT AUTHORITY\NETWORK SERVICE' /ADDCURRENTUSERASSQLADMIN=1

# NOUL COD: Firewall + DB + date test + HTML cu read
netsh advfirewall firewall add rule name="Open HTTP 80" dir=in action=allow protocol=TCP localport=80

# Creează DB + tabel + 2 înregistrări test
sqlcmd -S .\SQLEXPRESS -E -Q "IF NOT EXISTS(SELECT * FROM sys.databases WHERE name='MyDemoDB') CREATE DATABASE MyDemoDB; USE MyDemoDB; IF OBJECT_ID('Nume', 'U') IS NULL CREATE TABLE Nume (Id INT IDENTITY PRIMARY KEY, Numele NVARCHAR(100)); DELETE FROM Nume; INSERT INTO Nume (Numele) VALUES ('Lucian Enache'), ('Demo User');"

# Generează HTML cu date din DB
$dbData = sqlcmd -S .\SQLEXPRESS -E -d MyDemoDB -h-1 -s' | ' -W "SELECT 'ID: ' + CAST(Id AS VARCHAR(10)) + ' - ' + Numele AS Record FROM Nume ORDER BY Id;"
$content = @"
<html><head><title>Lucian IIS + SQL Demo</title></head><body>
<h1>Hello from Lucian IIS + SQL Express!</h1>
<h2>Date din baza MyDemoDB:</h2>
<ul>$dbData</ul>
<p><strong>DB gata de test! Conectează-te cu RDP să adaugi mai multe.</strong></p>
</body></html>
"@

Set-Content -Path 'C:\inetpub\wwwroot\index.html' -Value $content -Encoding UTF8
iisreset /restart
