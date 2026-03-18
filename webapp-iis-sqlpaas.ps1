Install-WindowsFeature -Name Web-Server -IncludeManagementTools | Out-Null

# SQL PaaS connection
$sqlServer = "${azurerm_mssql_server.sql_server.fqdn}:1433"  # Inject din tf
$db = "DemoDB"
$user = "sqladmin"
$pass = "P@ssw0rd123!Complex2026"

$connStr = "Server=$sqlServer;Database=$db;User Id=$user;Password=$pass;Encrypt=yes;TrustServerCertificate=no;Connection Timeout=30;"

# Init DB + table
$sql = @"
IF NOT EXISTS(SELECT * FROM sys.tables WHERE name='Nume') 
BEGIN
    CREATE TABLE Nume(Id INT IDENTITY PRIMARY KEY, Nume VARCHAR(100), DataAdded DATETIME DEFAULT GETDATE());
    INSERT INTO Nume(Nume) VALUES ('Initial Lucian'), ('PaaS Demo');
END
"@
sqlcmd -S $sqlServer -U $user -P $pass -d $db -Q $sql

# Interactive HTML + JS CRUD
$html = @"
<!DOCTYPE html>
<html><head><title>IIS + Azure SQL PaaS CRUD</title>
<meta charset="UTF-8">
<script src="https://code.jquery.com/jquery-3.6.0.min.js"></script>
<style>
body{font-family:Segoe UI;padding:20px;max-width:900px;margin:auto;background:#f5f5f5;}
h1{color:#0078d4;margin-bottom:30px;}
#add-form{background:white;padding:20px;border-radius:10px;box-shadow:0 2px 10px rgba(0,0,0,0.1);margin-bottom:20px;}
input[type=text]{padding:10px;width:300px;margin-right:10px;border:1px solid #ddd;border-radius:5px;}
button{padding:10px 20px;background:#0078d4;color:white;border:none;border-radius:5px;cursor:pointer;}
button:hover{background:#106ebe;}
table{width:100%;border-collapse:collapse;margin-top:20px;background:white;border-radius:10px;overflow:hidden;box-shadow:0 2px 10px rgba(0,0,0,0.1);}
th,td{padding:12px;text-align:left;border-bottom:1px solid #eee;}
th{background:#4285f4;color:white;}
tr:hover{background:#f8f9fa;}
.success{color:#4CAF50;font-weight:bold;}
.error{color:#f44336;}
#status{padding:10px;border-radius:5px;margin:10px 0;display:none;}
</style></head>
<body>
<h1>🗄️ IIS + Azure SQL PaaS - CRUD Demo</h1>
<div id='status'></div>

<div id='add-form'>
    <input type='text' id='newName' placeholder='Enter name (ex: Test User)'>
    <button onclick='addRecord()'>Add Record</button>
    <button onclick='refreshTable()'>Refresh</button>
</div>

<table id='dataTable'>
    <thead><tr><th>ID</th><th>Nume</th><th>Data Added</th></tr></thead>
    <tbody></tbody>
</table>

<script>
const connStr = '$connStr';  // Server-side injected
const apiUrl = '/api/names';  // Proxy via IIS

function showStatus(msg, isError=false) {
    const status = $('#status');
    status.text(msg).removeClass('success error').addClass(isError ? 'error' : 'success').show().delay(3000).fadeOut();
}

async function refreshTable() {
    try {
        const res = await fetch(apiUrl);
        const data = await res.json();
        let html = '';
        data.forEach(row => {
            html += `<tr><td>${row.Id}</td><td>${row.Nume}</td><td>${new Date(row.DataAdded).toLocaleString()}</td></tr>`;
        });
        $('#dataTable tbody').html(html);
        showStatus(`Loaded ${data.length} records`);
    } catch(e) {
        showStatus('Error loading data: ' + e.message, true);
    }
}

async function addRecord() {
    const name = $('#newName').val().trim();
    if (!name) return showStatus('Enter a name', true);
    
    try {
        const res = await fetch(apiUrl, {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({name: name})
        });
        if (res.ok) {
            $('#newName').val('');
            refreshTable();
            showStatus('Added successfully!');
        } else {
            showStatus('Add failed', true);
        }
    } catch(e) {
        showStatus('Network error', true);
        }
}

$(refreshTable);  // Load on start
</script>
</body></html>
"@

$html | Out-File 'C:\inetpub\wwwroot\index.html' -Encoding UTF8

# IIS API proxy pentru SQL (web.config + handler)
@"
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
<system.webServer>
<handlers>
<add name="api" path="/api/*" verb="*" modules="IsapiModule" scriptProcessor="%windir%\system32\inetsrv\asp.dll" resourceType="Unspecified" />
</handlers>
</system.webServer>
</configuration>
"@ | Out-File 'C:\inetpub\wwwroot\web.config'

# Simple ASP.NET handler pentru SQL CRUD (salvează ca /api/names.asp)
$asp = @"
<%
Response.ContentType = "application/json"
Dim connStr : connStr = "$connStr"
Dim action : action = Request.QueryString("action")
Dim conn, rs

If Request.ServerVariables("REQUEST_METHOD") = "POST" Then
    Set conn = Server.CreateObject("ADODB.Connection")
    conn.Open connStr
    Dim name : name = Request.Form("name")
    conn.Execute "INSERT INTO DemoDB.dbo.Nume (Nume) VALUES ('" & Replace(name,"'","''") & "')"
    conn.Close
    Response.Write "{""success"":true}"
Else
    Set conn = Server.CreateObject("ADODB.Connection")
    conn.Open connStr
    Set rs = conn.Execute("SELECT Id, Nume, DataAdded FROM DemoDB.dbo.Nume ORDER BY Id DESC")
    Response.Write "["
    Dim first : first = True
    Do While Not rs.EOF
        If Not first Then Response.Write ","
        Response.Write "{""Id"":" & rs("Id") & ",""Nume"":""" & Replace(rs("Nume"),"""","\""") & """,""DataAdded"":""" & rs("DataAdded") & """ }"
        first = False
        rs.MoveNext
    Loop
    Response.Write "]"
    rs.Close
    conn.Close
End If
%>
"@

$asp | Out-File 'C:\inetpub\wwwroot\api\names.asp' -Encoding ASCII
New-Item 'C:\inetpub\wwwroot\api' -ItemType Directory -Force

netsh advfirewall firewall add rule name="HTTP80" dir=in action=allow protocol=TCP localport=80
iisreset /restart

"✅ PaaS SQL + CRUD App ready!" | Out-File 'C:\temp\success.txt'
