 

DEFINE VARIABLE vBodyString         AS LONGCHAR                            NO-UNDO. 
DEFINE VARIABLE vURL                AS CHARACTER                           NO-UNDO. 
DEFINE VARIABLE sfdcREST            AS SFDC.SFDCREST                       NO-UNDO.
DEFINE VARIABLE jsonResponse        AS LONGCHAR                            NO-UNDO. 
DEFINE VARIABLE httpClient          AS System.Net.Http.HttpClient          NO-UNDO.   
DEFINE VARIABLE httpResponseMessage AS System.Net.Http.HttpResponseMessage NO-UNDO.
DEFINE VARIABLE httpRequestMessage  AS System.Net.Http.HttpRequestMessage  NO-UNDO.   

sfdcREST = NEW SFDC.SFDCREST().
sfdcREST:SFDCPasswordConnect().

vURL = sfdcREST:ServerURL + "/services/data/v35.0/sobjects/Account/".
vBodyString = 
  '~{                                           ' +
  '   "Name":"Bob Loblaw~'s Lawblog Pogs",      ' +
  '   "Type":"Legal"                            ' +
  ' ~}'.  

httpClient = NEW System.Net.Http.HttpClient().
httpRequestMessage = NEW System.Net.Http.HttpRequestMessage().
httpRequestMessage:Method = System.Net.Http.HttpMethod:Post.
httpRequestMessage:RequestUri = NEW System.Uri(vUrl).
httpRequestMessage:Content = NEW System.Net.Http.StringContent(vBodyString, System.Text.Encoding:UTF8, "application/json").
httpRequestMessage:Headers:Add ("Authorization", "Bearer " + sfdcREST:AccessToken).
    
/* Use SendAsync in a synchronous manner by directly accessing the result */
httpResponseMessage = httpClient:SendAsync(httpRequestMessage):Result. 
jsonResponse = httpResponseMessage:Content:ReadAsStringAsync():RESULT NO-ERROR.

IF  httpResponseMessage:StatusCode:value__ <> 200 THEN 
DO:
  MESSAGE 
    STRING (jsonResponse) SKIP 
    httpResponseMessage:StatusCode:value__
    VIEW-AS ALERT-BOX.
  RETURN.
END.

MESSAGE STRING (jsonResponse)
  VIEW-AS ALERT-BOX.
    