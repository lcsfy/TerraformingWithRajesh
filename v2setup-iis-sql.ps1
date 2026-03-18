Install-WindowsFeature -Name Web-Server -IncludeManagementTools

$content = '<html><body><h1>Hello from Lucian IIS + SQL demo test</h1></body></html>'
Set-Content -Path 'C:\inetpub\wwwroot\index.html' -Value $content -Encoding UTF8

New-Item -ItemType Directory -Path 'C:\temp' -Force | Out-Null
$sqlUrl = 'https://download.microsoft.com/download/2/1/0/210B5C9A-DF68-4AA0-9A2D-6A1E1E6A9791/SQL2019-SSEI-Expr.exe'
$sqlInstaller = 'C:\temp\SQL2019-SSEI-Expr.exe'
Invoke-WebRequest -Uri $sqlUrl -OutFile $sqlInstaller

& $sqlInstaller /ACTION=Install /QUIET /IACCEPTSQLSERVERLICENSETERMS /FEATURES=SQLENGINE /INSTANCENAME=SQLEXPRESS /SQLSVCACCOUNT='NT AUTHORITY\NETWORK SERVICE' /ADDCURRENTUSERASSQLADMIN=1
