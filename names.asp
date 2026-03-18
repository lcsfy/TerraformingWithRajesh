<%
Response.ContentType = "application/json"
Dim connStr : connStr = "__CONNSTR__"

If Request.ServerVariables("REQUEST_METHOD") = "POST" Then
  Dim name : name = Trim(Request.Form("name"))
  If Len(name) > 0 Then
    Dim conn : Set conn = Server.CreateObject("ADODB.Connection")
    conn.Open connStr
    conn.Execute "INSERT dbo.Nume (Nume) VALUES ('" & Replace(name, "'", "''") & "')"
    conn.Close
    Response.Write "{""success"":true}"
  Else
    Response.Write "{""success"":false}"
  End If
Else
  Dim conn : Set conn = Server.CreateObject("ADODB.Connection")
  conn.Open connStr
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
  conn.Close
End If
%>
