# 1. IIS + Firewall
Install-WindowsFeature -Name Web-Server -IncludeManagementTools
netsh advfirewall firewall add rule name="Open Port 80" dir=in action=allow protocol=TCP localport=80

# 2. SQL Express (ca înainte)
New-Item -ItemType Directory -Path 'C:\temp' -Force | Out-Null
$sqlUrl = 'https://download.microsoft.com/download/2/1/0/210B5C9A-DF68-4AA0-9A2D-6A1E1E6A9791/SQL2019-SSEI-Expr.exe'
$sqlInstaller = 'C:\temp\SQL2019-SSEI-Expr.exe'
Invoke-WebRequest -Uri $sqlUrl -OutFile $sqlInstaller
& $sqlInstaller /ACTION=Install /QUIET /IACCEPTSQLSERVERLICENSETERMS /FEATURES=SQLENGINE /INSTANCENAME=SQLEXPRESS /SQLSVCACCOUNT='NT AUTHORITY\NETWORK SERVICE' /ADDCURRENTUSERASSQLADMIN=1

Start-Sleep -Seconds 30  # Așteaptă SQL să pornească

# 3. DB + date TEST (sintaxă fixată)
sqlcmd -S .\SQLEXPRESS -E -Q "IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'MyDemoDB') BEGIN CREATE DATABASE MyDemoDB END; USE MyDemoDB; IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Nume') BEGIN CREATE TABLE Nume (Id INT IDENTITY PRIMARY KEY, Numele NVARCHAR(100)) END; DELETE FROM Nume; INSERT INTO Nume (Numele) VALUES ('Lucian Enache'), ('Demo User');"

# 4. Verifică DB și generează HTML
$recordCount = sqlcmd -S .\SQLEXPRESS -E -d MyDemoDB -h-1 -Q "SELECT COUNT(*) AS Count FROM Nume"
$records = sqlcmd -S .\SQLEXPRESS -E -d MyDemoDB -h-1 -Q "SELECT CAST(Id AS VARCHAR(10)) + ': ' + Numele AS Record FROM Nume ORDER BY Id"

$content = @"
<!DOCTYPE html>
<html>
<head><title>Lucian IIS + SQL ✅</title>
<style>body {font-family: Arial; margin: 40px;} h1 {color: green;}</style>
</head>
<body>
<h1>🎉 IIS + SQL Express - FUNCȚIONEAZĂ!</h1>
<h2>Date din MyDemoDB.Nume:</h2>
<p><strong>Total înregistrări: $recordCount</strong></p>
<pre style="background: #f4f4f4; padding: 20px; border-radius: 5px;">
$records
</pre>
<hr>
<p>Script GitHub rulat perfect via Terraform! 🛠️</p>
</body>
</html>
"@

Set-Content -Path 'C:\inetpub\wwwroot\index.html' -Value $content -Encoding UTF8
iisreset /restart

Write-Output "Script finalizat - verifica http://localhost"
