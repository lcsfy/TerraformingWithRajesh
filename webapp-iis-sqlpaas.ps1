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
