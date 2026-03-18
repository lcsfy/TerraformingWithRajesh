<%
Response.ContentType = "application/json"

' Connection string complet pentru Azure SQL cu SQLOLEDB
Dim connStr
connStr = "Provider=SQLOLEDB;Data Source=sql-iis-demo-jgj90dfn.database.windows.net,1433;" & _
          "Initial Catalog=DemoDB;User ID=sqladmin;Password=P@ssw0rd123!Complex2026;" & _
          "Encrypt=yes;TrustServerCertificate=no;Connection Timeout=30;"

Dim conn
Dim action : action = Trim(Request.QueryString("action"))

Set conn = Server.CreateObject("ADODB.Connection")
conn.Open connStr

If action = "delete" Then
  Dim id : id = Trim(Request.QueryString("id"))
  If IsNumeric(id) And CInt(id) > 0 Then
    conn.Execute "DELETE FROM dbo.Nume WHERE Id = " & CInt(id)
    Response.Write "{""success"":true,""message"":""Deleted row " & id & """}"
  Else
    Response.Write "{""success"":false,""error"":""Invalid ID""}"
  End If
ElseIf Request.ServerVariables("REQUEST_METHOD") = "POST" Then
  Dim name : name = Trim(Request.Form("name"))
  If Len(name) > 0 And Len(name) <= 100 Then
    conn.Execute "INSERT dbo.Nume (Nume) VALUES ('" & Replace(name, "'", "''") & "')"
    Response.Write "{""success"":true,""message"":""Added: " & name & """}"
  Else
    Response.Write "{""success"":false,""error"":""Name too long or empty""}"
  End If
Else
  ' GET - return all records
  Dim rs : Set rs = conn.Execute("SELECT TOP 20 Id, Nume, Added FROM dbo.Nume ORDER BY Id DESC")
  Dim first : first = True
  Response.Write "["
  Do While Not rs.EOF
    If Not first Then Response.Write ","
    Response.Write "{""Id"":"
    Response.Write rs("Id")
    Response.Write ",""Nume"":"""
    Response.Write Replace(Replace(rs("Nume"), """", "'"), "\", "\\")
    Response.Write """,""Added"":"""
    Response.Write rs("Added")
    Response.Write """}"
    rs.MoveNext
    first = False
  Loop
  Response.Write "]"
  rs.Close
  Set rs = Nothing
End If

conn.Close
Set conn = Nothing
%>
