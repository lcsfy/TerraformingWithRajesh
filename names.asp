<%
Response.ContentType = "application/json"
Dim connStr : connStr = "__CONNSTR__"

Dim conn

If Request.ServerVariables("REQUEST_METHOD") = "POST" Then
  Dim name : name = Trim(Request.Form("name"))
  If Len(name) > 0 Then
    Set conn = Server.CreateObject("ADODB.Connection")
    conn.Open "Provider=SQLNCLI11; " & connStr
    conn.Execute "INSERT dbo.Nume (Nume) VALUES ('" & Replace(name, "'", "''") & "')"
    conn.Close
    Set conn = Nothing
    Response.Write "{""success"":true}"
  Else
    Response.Write "{""success"":false}"
  End If
Else
  Set conn = Server.CreateObject("ADODB.Connection")
  conn.Open "Provider=SQLNCLI11; " & connStr
  Dim rs : Set rs = conn.Execute("SELECT TOP 20 Id, Nume, Added FROM dbo.Nume ORDER BY Id DESC")
  Dim first : first = True
  Response.Write "["
  Do While Not rs.EOF
    If Not first Then Response.Write ","
    Response.Write "{""Id"":"
    Response.Write rs("Id")
    Response.Write ",""Nume"":"""
    Response.Write Replace(rs("Nume"), """", "'")
    Response.Write """,""Added"":"""
    Response.Write rs("Added")
    Response.Write """}"
    rs.MoveNext
    first = False
  Loop
  Response.Write "]"
  rs.Close
  Set rs = Nothing
  conn.Close
  Set conn = Nothing
End If
%>
