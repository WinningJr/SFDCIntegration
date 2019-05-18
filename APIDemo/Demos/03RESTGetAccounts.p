DEFINE VARIABLE vURL                AS CHARACTER                                   NO-UNDO. 
DEFINE VARIABLE sfdcREST            AS SFDC.SFDCREST                               NO-UNDO.
DEFINE VARIABLE httpClient          AS System.Net.Http.HttpClient                  NO-UNDO.   
DEFINE VARIABLE httpResponseMessage AS System.Net.Http.HttpResponseMessage         NO-UNDO.
DEFINE VARIABLE httpRequestMessage  AS System.Net.Http.HttpRequestMessage          NO-UNDO. 
DEFINE VARIABLE jsonResponse        AS LONGCHAR                                    NO-UNDO. 
DEFINE VARIABLE objectModelParser   AS Progress.Json.ObjectModel.ObjectModelParser NO-UNDO.
DEFINE VARIABLE jsonObject          AS Progress.Json.ObjectModel.JsonObject        NO-UNDO.

sfdcREST = NEW SFDC.SFDCREST().
sfdcREST:SFDCPasswordConnect().

vURL = sfdcREST:ServerURL + "/services/data/v35.0/sobjects/Account/" + "0011100001EkcyIAAR".

httpClient = NEW System.Net.Http.HttpClient().
httpRequestMessage = NEW System.Net.Http.HttpRequestMessage().
httpRequestMessage:Method = System.Net.Http.HttpMethod:Get.
httpRequestMessage:RequestUri = NEW System.Uri(vUrl).
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
 MESSAGE 
    STRING (jsonResponse) SKIP VIEW-AS ALERT-BOX. 
objectModelParser = NEW Progress.Json.ObjectModel.ObjectModelParser().
jsonObject = CAST 
  (objectModelParser:Parse(jsonResponse),
  Progress.Json.ObjectModel.JsonObject).

MESSAGE 
  "Id: "  jsonObject:GetCharacter("Id") SKIP 
  "Name:  " jsonObject:GetCharacter("Name") SKIP              
  VIEW-AS ALERT-BOX.  

    