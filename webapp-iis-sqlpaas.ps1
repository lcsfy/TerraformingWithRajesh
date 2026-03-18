param([Parameter(Mandatory=$true)][string]$SqlServer,[string]$DbName="DemoDB",[string]$SqlUser="sqladmin",[string]$SqlPass="P@ssw0rd123!Complex2026!")

Write-Output "=== DEPLOYMENT START: $SqlServer ==="

# FIX 1: sqlcmd via MSI direct (winget fail pe Server 2019)
$sqlcmdPath = "C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\18.0\Tools\Binn\sqlcmd.exe"
if (!(Test-Path $sqlcmdPath)) {
  Write-Output "Installing sqlcmd..."
  Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/?linkid=2274700" -OutFile "sqlcmd.msi"
  Start-Process msiexec.exe -ArgumentList "/i sqlcmd.msi /quiet /norestart" -Wait
  $env:PATH += ";C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\18.0\Tools\Binn"
}

# FIX 2: Web-ASP + sqlcmd test
Install-WindowsFeature Web-Server,Web-Mgmt-Tools,Web-ASP | Out-Null
& $sqlcmdPath -S $SqlServer -U $SqlUser -P $SqlPass -d $DbName -Q "SELECT 'SQL OK'" | Out-Null

# FIX 3: dbo.Nume + table creation
& $sqlcmdPath -S $SqlServer -U $SqlUser -P $SqlPass -d $DbName -Q "
IF NOT EXISTS(SELECT * FROM sys.tables WHERE name='Nume')
  CREATE TABLE dbo.Nume(Id INT IDENTITY PRIMARY KEY, Nume VARCHAR(100), Added DATETIME DEFAULT GETDATE());
DELETE FROM dbo.Nume;
INSERT dbo.Nume(Nume) VALUES('Terraform OK'),('PS Fixed'),('CRUD Ready');
SELECT COUNT(*) as RowsCreated FROM dbo.Nume;
"

Write-Output "DB ready with 3 rows"

# HTML cu apiUrl OK + vanilla JS backup
$html = @"
<!DOCTYPE html>
<html><head><title>IIS+SQL CRUD</title><meta charset="UTF-8">
<script>window.jQuery||document.write('<script src="https://code.jquery.com/jquery-3.6.0.min.js"><\/script>')</script>
<style>body{font-family:Segoe UI;padding:20px;background:#f5f5f5;max-width:900px;margin:auto;}
table{width:100%;border-collapse:collapse;background:#fff;border-radius:10px;overflow:hidden;box-shadow:0 2px 10px rgba(0,0,0,.1);}
th{background:#4285f4;color:white;padding:12px;}td{padding:12px;border-bottom:1px solid #eee;}
button{padding:10px 20px;background:#0078d4;color:white;border:none;border-radius:5px;cursor:pointer;}
.debug{background:yellow;padding:15px;border-radius:8px;font-family:monospace;}
#status{padding:10px;margin:10px;border-radius:5px;display:none;}</style>
</head><body>
<h1>🗄️ IIS + Azure SQL CRUD Demo</h1><div id='status'></div>
<div class='debug'><strong>🔧 FQDN:</strong> <span id='sqlServer'>$SqlServer</span><br>
<button onclick='testSql()'>Test SQL</button><button onclick='hideDebug()'>Hide</button></div>
<input id='newName' placeholder='Enter name' style='padding:10px;width:300px;'>
<button onclick='addRecord()'>➕ Add</button><button onclick='refreshTable()'>🔄 Refresh</button>
<table id='dataTable'><thead><tr><th>ID</th><th>Nume</th><th>Added</th><th></th></tr></thead><tbody></tbody></table>

<script>
const apiUrl='/api/names.asp';let jq=document.querySelector||function(){};
try{jq=$;}catch(e){console.log('jQuery fallback');}
function showStatus(msg,isError=false){
  const s=document.getElementById('status');s.textContent=msg;s.style.background=isError?'#f44336':'#4caf50';
  s.style.color='white';s.style.display='block';setTimeout(()=>s.style.display='none',4e3);
}
async function refreshTable(){try{const r=await fetch(apiUrl);if(!r.ok)throw new Error(r.status);
const d=await r.json();let h='';d.forEach(row=>h+=`<tr><td>\${
