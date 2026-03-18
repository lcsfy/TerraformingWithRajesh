param(
  [string]$SqlServer = "${azurerm_mssql_server.sql_server.fqdn}:1433",
  [string]$DbName = "DemoDB",
  [string]$SqlUser = "sqladmin",
  [string]$SqlPass = "P@ssw0rd123!Complex2026"
)

# IIS
Install-WindowsFeature Web-Server, Web-Mgmt-Tools | Out-Null

# Conn string
$connStr = "Server=$SqlServer;Database=$DbName;User Id=$SqlUser;Password=$SqlPass;Encrypt=yes;TrustServerCertificate=no;"

# Init table
sqlcmd -S $SqlServer -U $SqlUser -P $SqlPass -d $DbName -Q "IF NOT EXISTS(SELECT * FROM sys.tables WHERE name='Nume') CREATE TABLE Nume(Id INT IDENTITY PRIMARY KEY, Nume VARCHAR(100), Added DATETIME DEFAULT GETDATE())"

# HTML + JS CRUD app (ca în răspunsul anterior)
$html = @' ... (păstrează HTML-ul interactiv cu jquery + POST/GET la /api/names)'@
$html | Out-File 'C:\inetpub\wwwroot\index.html' -Encoding UTF8

# API endpoint ASP
$apiAsp = @"
<%
Response.ContentType = "application/json"
Dim connStr : connStr = "$connStr"
If Request.ServerVariables("REQUEST_METHOD") = "POST" Then
  Dim name : name = Request.Form("name")
  Dim conn : Set conn = Server.CreateObject("ADODB.Connection")
  conn.Open connStr
  conn.Execute "INSERT DemoDB.dbo.Nume (Nume) VALUES ('" & Replace(name,"'","''") & "')"
  conn.Close
  Response.Write "{""success"":true}"
Else
  Dim rs : Set rs = conn.Execute("SELECT TOP 20 Id, Nume, Added FROM DemoDB.dbo.Nume ORDER BY Id DESC")
  Response.Write "["
  Dim first : first = True
  Do While Not rs.EOF
    If Not first Then Response.Write ","
    Response.Write "{""Id"":" & rs("Id") & ",""Nume"":""" & Replace(rs("Nume"),"""","\""") & """,""Added"":""" & rs("Added") & """ }"
    rs.MoveNext : first = False
  Loop
  Response.Write "]"
End If
%>
"@
New-Item 'C:\inetpub\wwwroot\api' -Force
$apiAsp | Out-File 'C:\inetpub\wwwroot\api\names.asp'

iisreset
netsh advfirewall firewall add rule name="HTTP" dir=in action=allow protocol=TCP localport=80
