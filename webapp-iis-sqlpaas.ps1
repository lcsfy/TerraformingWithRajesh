param(
  [string]$SqlServer,
  [string]$DbName = "DemoDB",
  [string]$SqlUser = "sqladmin", 
  [string]$SqlPass = "P@ssw0rd123!Complex2026!"
)

$connStr = "Server=$SqlServer;Database=$DbName;User Id=$SqlUser;Password=$SqlPass;Encrypt=yes;TrustServerCertificate=no;"

Write-Output "Connecting to: $SqlServer"

# SQL init + test data
sqlcmd -S $SqlServer -U $SqlUser -P $SqlPass -d $DbName -Q "
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Nume') 
  CREATE TABLE Nume (Id INT IDENTITY PRIMARY KEY, Nume VARCHAR(100), Added DATETIME DEFAULT GETDATE());
DELETE FROM Nume WHERE Id > 3;
INSERT INTO Nume (Nume) VALUES ('Hello from Terraform'), ('PS Script OK'), ('Ready for CRUD');
"

Install-WindowsFeature -Name Web-Server, Web-Mgmt-Tools -Restart | Out-Null

# HTML cu toate fixurile (copiază varianta completă de mai devreme)
$html = @"
<!DOCTYPE html>
<html>
<head>
<title>IIS + Azure SQL PaaS CRUD</title>
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
.debug{background:yellow;padding:15px;margin:20px 0;border-radius:8px;font-family:monospace;}
</style>
</head>
<body>
<h1>🗄️ IIS + Azure SQL PaaS - CRUD Demo</h1>
<div id='status'></div>

<div class='debug'>
  <strong>🔧 DEBUG INFO (pentru test):</strong><br>
  SQL Server FQDN: <span id='sqlServer'>$SqlServer</span><br>
  ConnStr preview: Server=...;Database=$DbName (parola hidden)<br>
  <button onclick='testSql()'>🔍 Test SQL Connection</button>
  <button onclick='clearDebug()'>X Hide Debug</button>
</div>

<div id='add-form'>
    <input type='text' id='newName' placeholder='Enter name (ex: Test User)'>
    <button onclick='addRecord()'>➕ Add Record</button>
    <button onclick='refreshTable()'>🔄 Refresh</button>
</div>

<table id='dataTable'>
    <thead><tr><th>ID</th><th>Nume</th><th>Added</th><th>Actions</th></tr></thead>
    <tbody></tbody>
</table>

<script>
const connStr = '$connStr';
const apiUrl = '/api/names.asp';

function showStatus(msg, isError=false) {
    const status = $('#status');
    status.text(msg).removeClass('success error').addClass(isError ? 'error' : 'success').show().delay(4000).fadeOut();
}

function testSql() {
    fetch(apiUrl)
        .then(res => {
            if (!res.ok) throw new Error('HTTP ' + res.status);
            return res.json();
        })
        .then(data => showStatus('✅ SQL OK! ' + data.length + ' rows loaded'))
        .catch(e => showStatus('❌ SQL Error: ' + e.message, true));
}

function clearDebug() {
    $('.debug').hide();
}

async function refreshTable() {
    try {
        const res = await fetch(apiUrl);
        if (!res.ok) throw new Error('HTTP ' + res.status);
        const data = await res.json();
        let html = '';
        data.forEach(row => {
            html += `<tr><td>${row.Id}</td><td>${row.Nume}</td><td>${new Date(row.Added).toLocaleString()}</td><td><button onclick="deleteRecord(${row.Id})">🗑️</button></td></tr>`;
        });
        $('#dataTable tbody').html(html);
        showStatus(`✅ Loaded ${data.length} records`);
    } catch(e) {
        showStatus('Error loading: ' + e.message, true);
    }
}

async function addRecord() {
    const name = $('#newName').val().trim();
    if (!name) return showStatus('Enter a name', true);
    
    try {
        const res = await fetch(apiUrl, {
            method: 'POST',
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: 'name=' + encodeURIComponent(name)
        });
        if (res.ok) {
            $('#newName').val('');
            refreshTable();
            showStatus('✅ Added successfully!');
        } else {
            const err = await res.text();
            showStatus('Add failed: ' + err, true);
        }
    } catch(e) {
        showStatus('Network error: ' + e.message, true);
    }
}

function deleteRecord(id) {
    if (!confirm('Delete row ' + id + '?')) return;
    // Implementează DELETE dacă vrei
    refreshTable();
}

$(document).ready(function() {
    refreshTable();
    testSql();
});
</script>
</body>
</html>
"@
$html | Out-File 'C:\inetpub\wwwroot\index.html' -Encoding UTF8

# ASP (copiază varianta completă)
$apiAsp = @' [ADAUGĂ ASP-UL COMPLET ] '@  
New-Item 'C:\inetpub\wwwroot\api' -Force
$apiAsp | Out-File 'C:\inetpub\wwwroot\api\names.asp' -Encoding UTF8

iisreset
netsh advfirewall firewall add rule name="IIS-HTTP" dir=in action=allow protocol=TCP localport=80

Write-Output "✅ Deployment complete for $SqlServer"
