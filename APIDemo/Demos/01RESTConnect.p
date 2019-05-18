 
DEFINE VARIABLE vURL                AS CHARACTER                                   NO-UNDO.
DEFINE VARIABLE jsonResponse        AS LONGCHAR                                    NO-UNDO.
DEFINE VARIABLE vBody               AS CHARACTER                                   NO-UNDO. 
DEFINE VARIABLE objectModelParser   AS Progress.Json.ObjectModel.ObjectModelParser NO-UNDO.
DEFINE VARIABLE jsonObject          AS Progress.Json.ObjectModel.JsonObject        NO-UNDO.
DEFINE VARIABLE httpClient          AS System.Net.Http.HttpClient                  NO-UNDO.   
DEFINE VARIABLE httpResponseMessage AS System.Net.Http.HttpResponseMessage         NO-UNDO.
DEFINE VARIABLE httpRequestMessage  AS System.Net.Http.HttpRequestMessage          NO-UNDO. 
 
ASSIGN 
  vURL = Utility.MiscUtil:getIniKeyValue("SFDC","loginURL").
            
/* JSON is NOT supported for the token request - JSON IS supported for the other REST calls */             
vBody = 
  "grant_type=password" +
  "&client_id="     + Utility.MiscUtil:getIniKeyValue("SFDC","consumerKey") +
  "&client_secret=" + Utility.MiscUtil:getIniKeyValue("SFDC","consumerSecret") +
  "&username="      + Utility.MiscUtil:getIniKeyValue("SFDC","userName") +
  "&password="      + Utility.MiscUtil:getIniKeyValue("SFDC","password") + Utility.MiscUtil:getIniKeyValue("SFDC","securityToken").

httpClient = NEW System.Net.Http.HttpClient().
httpRequestMessage = NEW System.Net.Http.HttpRequestMessage().
httpRequestMessage:Method = System.Net.Http.HttpMethod:Post.
httpRequestMessage:RequestUri = NEW System.Uri(vUrl).
httpRequestMessage:Content =  NEW System.Net.Http.StringContent(vBody).
httpRequestMessage:Content:Headers:ContentType = NEW System.Net.Http.Headers.MediaTypeHeaderValue("application/x-www-form-urlencoded").

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

objectModelParser = NEW Progress.Json.ObjectModel.ObjectModelParser().
jsonObject = CAST
  (objectModelParser:Parse(jsonResponse),
  Progress.Json.ObjectModel.JsonObject).

MESSAGE 
  "ServerURL: " SKIP 
  jsonObject:GetCharacter("instance_url") SKIP 
  "-------------------" SKIP 
  "AccessToken:  " SKIP 
  jsonObject:GetCharacter("access_token") SKIP              
  VIEW-AS ALERT-BOX.
    
