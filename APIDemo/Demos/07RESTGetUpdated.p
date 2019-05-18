DEFINE VARIABLE vURL                AS CHARACTER                                   NO-UNDO. 
DEFINE VARIABLE sfdcREST            AS SFDC.SFDCREST                               NO-UNDO.
DEFINE VARIABLE httpClient          AS System.Net.Http.HttpClient                  NO-UNDO.   
DEFINE VARIABLE httpResponseMessage AS System.Net.Http.HttpResponseMessage         NO-UNDO.
DEFINE VARIABLE httpRequestMessage  AS System.Net.Http.HttpRequestMessage          NO-UNDO. 
DEFINE VARIABLE jsonResponse        AS LONGCHAR                                    NO-UNDO. 
DEFINE VARIABLE objectModelParser   AS Progress.Json.ObjectModel.ObjectModelParser NO-UNDO.
DEFINE VARIABLE jsonObject          AS Progress.Json.ObjectModel.JsonObject        NO-UNDO.
DEFINE VARIABLE startDateTime       AS CHARACTER                                   NO-UNDO. 
DEFINE VARIABLE endDateTime         AS CHARACTER                                   NO-UNDO. 
DEFINE VARIABLE updatedDateTime     AS DATETIME                                    NO-UNDO. 
DEFINE VARIABLE lastUpdatedDateTime AS DATETIME                                    NO-UNDO. 

sfdcREST = NEW SFDC.SFDCREST().
sfdcREST:SFDCPasswordConnect().

/* We need a start and end time, URL encoded, in ISO format.  In your applicaiton, you 
   would go from the last time you got updates until Now. From the REST API Docs:
     
   Date/time (Coordinated Universal Time (UTC) time zone—not local— timezone) of the 
   timespan for which to retrieve the data. The API ignores the seconds portion of the specified 
   dateTime value (for example, 12:30:15 is interpreted as 12:30:00 UTC). The date and time should 
   be provided in ISO 8601 format: YYYY-MM-DDThh:mm:ss+hh:mm. The date/time value for start must 
   chronologically precede end. This parameter should be URL-encoded     */
 
updatedDateTime = NOW. 
lastUpdatedDateTime = ADD-INTERVAL (updatedDateTime, -1, 'days').
endDatetime = ISO-DATE (updatedDatetime).
startDateTime = ISO-DATE (lastUpdatedDateTime).

endDateTime = ENTRY (1,endDateTime,".") + "Z".
startDateTime = ENTRY (1,startDateTime,".") + "Z".

endDateTime = System.Web.HttpUtility:UrlEncode(endDateTime).
startDateTime = System.Web.HttpUtility:UrlEncode(startDateTime).

vURL = sfdcREST:ServerURL + "/services/data/v35.0/sobjects/account/updated/?start=" + startDateTime + "&end=" + endDateTime.

MESSAGE vURL
  VIEW-AS ALERT-BOX.
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
  
/*objectModelParser = NEW Progress.Json.ObjectModel.ObjectModelParser().*/
/*jsonObject = CAST                                                     */
/*  (objectModelParser:Parse(jsonResponse),                             */
/*  Progress.Json.ObjectModel.JsonObject).                              */



    