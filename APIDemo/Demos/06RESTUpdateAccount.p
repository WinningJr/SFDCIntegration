{i/SFDCTT.i}
 
DEFINE VARIABLE sfdcID              AS CHARACTER                           NO-UNDO. 
DEFINE VARIABLE htt                 AS HANDLE                              NO-UNDO. 
DEFINE VARIABLE vBodyString         AS LONGCHAR                            NO-UNDO. 
DEFINE VARIABLE vURL                AS CHARACTER                           NO-UNDO. 
DEFINE VARIABLE sfdcREST            AS SFDC.SFDCREST                       NO-UNDO.
DEFINE VARIABLE jsonResponse        AS LONGCHAR                            NO-UNDO. 
DEFINE VARIABLE httpClient          AS System.Net.Http.HttpClient          NO-UNDO.   
DEFINE VARIABLE httpResponseMessage AS System.Net.Http.HttpResponseMessage NO-UNDO.
DEFINE VARIABLE httpRequestMessage  AS System.Net.Http.HttpRequestMessage  NO-UNDO.   

sfdcREST = NEW SFDC.SFDCREST().
sfdcREST:SFDCPasswordConnect().
sfdcId = "0011100001EkcyIAAR". 

vURL = sfdcREST:ServerURL + "/services/data/v35.0/sobjects/Account/" + sfdcId.
vBodyString = 
  '~{                                       ' +
  '   "Name":"Bob Loblaw~'s Law Blog Pogs", ' +
  '   "Type":"Manufacturing"                ' +
  '~}'.  

httpClient = NEW System.Net.Http.HttpClient().
httpRequestMessage = NEW System.Net.Http.HttpRequestMessage().
httpRequestMessage:Method = NEW System.Net.Http.HttpMethod("PATCH").
httpRequestMessage:RequestUri = NEW System.Uri(vUrl).
httpRequestMessage:Content = NEW System.Net.Http.StringContent(vBodyString, System.Text.Encoding:UTF8, "application/json").
httpRequestMessage:Headers:Add ("Authorization", "Bearer " + sfdcREST:AccessToken).
    
/* Use SendAsync in a synchronous manner by directly accessing the result */
httpResponseMessage = httpClient:SendAsync(httpRequestMessage):Result. 
jsonResponse = httpResponseMessage:Content:ReadAsStringAsync():RESULT NO-ERROR.

IF  httpResponseMessage:StatusCode:value__ <> 204 THEN 
DO:
  MESSAGE 
    STRING (jsonResponse) SKIP 
    httpResponseMessage:StatusCode:value__
    VIEW-AS ALERT-BOX.
  RETURN.
END.

sfdcId = "0011100001EkcyIAAR".
 
htt = TEMP-TABLE ttCustomer:HANDLE. 

sfdcREST:readRecords (sfdcId, htt).   
FOR EACH ttCustomer:
  MESSAGE ttCustomer.custName SKIP 
    ttCustomer.custType
    VIEW-AS ALERT-BOX.   
END.    
    