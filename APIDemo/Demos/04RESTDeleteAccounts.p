DEFINE VARIABLE vURL                AS CHARACTER                           NO-UNDO. 
DEFINE VARIABLE sfdcREST            AS SFDC.SFDCREST                       NO-UNDO.
DEFINE VARIABLE httpClient          AS System.Net.Http.HttpClient          NO-UNDO.   
DEFINE VARIABLE httpResponseMessage AS System.Net.Http.HttpResponseMessage NO-UNDO.
DEFINE VARIABLE httpRequestMessage  AS System.Net.Http.HttpRequestMessage  NO-UNDO. 
DEFINE VARIABLE jsonResponse        AS LONGCHAR                            NO-UNDO. 

sfdcREST = NEW SFDC.SFDCREST().
sfdcREST:SFDCPasswordConnect().

vURL = sfdcREST:ServerURL + "/services/data/v35.0/sobjects/Account/" + "0011100001EkceXAAR".

httpClient = NEW System.Net.Http.HttpClient().
httpRequestMessage = NEW System.Net.Http.HttpRequestMessage().
httpRequestMessage:Method = System.Net.Http.HttpMethod:Delete.
httpRequestMessage:RequestUri = NEW System.Uri(vUrl).
httpRequestMessage:Headers:Add ("Authorization", "Bearer " + sfdcREST:AccessToken).

/* Use SendAsync in a synchronous manner by directly accessing the result */
httpResponseMessage = httpClient:SendAsync(httpRequestMessage):Result.
jsonResponse = httpResponseMessage:Content:ReadAsStringAsync():RESULT NO-ERROR.

IF  httpResponseMessage:StatusCode:value__ <> 204 THEN 
DO:
  IF httpResponseMessage:StatusCode:value__ = 404 THEN 
  DO:
    /* entity already deleted */ 
    MESSAGE 
      "Ingoring 'Already Deleted' Error: " SKIP 
      STRING (jsonResponse)  
      VIEW-AS ALERT-BOX. 
  END.
  ELSE 
  DO:
    /* bomb out - real error */ 
    MESSAGE 
      STRING (jsonResponse) SKIP 
      httpResponseMessage:StatusCode:value__
      VIEW-AS ALERT-BOX.
    RETURN.
  END.
END.

  
  
MESSAGE "Deleted"
  VIEW-AS ALERT-BOX.
    