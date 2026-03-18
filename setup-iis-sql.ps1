Install-WindowsFeature -Name Web-Server -IncludeManagementTools

$content = '<html><body><h1>Hello from Lucian IIS + SQL demo</h1></body></html>'
Set-Content -Path 'C:\inetpub\wwwroot\index.html' -Value $content -Encoding UTF8

New-Item -ItemType Directory -Path 'C:\temp' -Force | Out-Null
$sqlUrl = 'https://download.microsoft.com/download/2/1/0/210B5C9A-DF68-4AA0-9A2D-6A1E1E6A9791/SQL2019-SSEI-Expr.exe'
$sqlInstaller = 'C:\temp\SQL2019-SSEI-Expr.exe'
Invoke-WebRequest -Uri $sqlUrl -OutFile $sqlInstaller

& $sqlInstaller /ACTION=Install /QUIET /IACCEPTSQLSERVERLICENSETERMS /FEATURES=SQLENGINE /INSTANCENAME=SQLEXPRESS /SQLSVCACCOUNT='NT AUTHORITY\NETWORK SERVICE' /ADDCURRENTUSERASSQLADMIN=1

Install-WindowsFeature NET-Framework-45-Core,NET-Framework-45-Features  # Pentru ASP.NET
netsh advfirewall firewall add rule name="Open HTTP 80" dir=in action=allow protocol=TCP localport=80  # Deschide firewall

# Creează DB + tabel (după ce SQL e instalat)
sqlcmd -S .\SQLEXPRESS -E -Q "IF NOT EXISTS(SELECT * FROM sys.databases WHERE name='MyDemoDB') CREATE DATABASE MyDemoDB; USE MyDemoDB; IF OBJECT_ID('Nume', 'U') IS NULL CREATE TABLE Nume (Id INT IDENTITY PRIMARY KEY, Numele NVARCHAR(100));"

# Copiază fișierul ASP.NET (înlocuiește index.html cu index.aspx)
$content = @'
<%@ Page Language="C#" %>
<%@ Import Namespace="System.Data.SqlClient" %>
<!DOCTYPE html>
<html><head><title>IIS+SQL Demo</title></head><body>
<h1>Lucian Demo: Adaugă/Citește din SQL</h1>
<form method="post">
  Nume: <input type="text" name="nume" />
  <input type="submit" value="Adaugă" />
</form>
<%
if (IsPostBack && Request.Form["nume"] != null) {
  string connStr = @"Server=.\\SQLEXPRESS;Database=MyDemoDB;Trusted_Connection=true;";
  using (SqlConnection conn = new SqlConnection(connStr)) {
    conn.Open();
    string sql = "INSERT INTO Nume (Numele) VALUES (@nume)";
    using (SqlCommand cmd = new SqlCommand(sql, conn)) {
      cmd.Parameters.AddWithValue("@nume", Request.Form["nume"]);
      cmd.ExecuteNonQuery();
    }
  }
  Response.Write("<p style='color:green'>Salvat în DB!</p>");
}
%>
<h2>Nume salvate:</h2><ul><%
using (SqlConnection conn = new SqlConnection(@"Server=.\\SQLEXPRESS;Database=MyDemoDB;Trusted_Connection=true;")) {
  conn.Open();
  string sql = "SELECT Id, Numele FROM Nume";
  using (SqlCommand cmd = new SqlCommand(sql, conn)) {
    using (SqlDataReader reader = cmd.ExecuteReader()) {
      while (reader.Read()) Response.Write($"<li>ID {reader["Id"]}: {reader["Numele"]}</li>");
    }
  }
}%></ul></body></html>
'@
Set-Content -Path 'C:\inetpub\wwwroot\index.aspx' -Value $content -Encoding UTF8
