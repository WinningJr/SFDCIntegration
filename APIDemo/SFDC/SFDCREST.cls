/*------------------------------------------------------------------------
   File        : SFDCREST
   Purpose     : 
   Syntax      : 
   Description : 
   Author(s)   : gerry.winning
   Created     : Tue Jan 31 16:04:07 EST 2012
   Notes       : 
 ---------------------------------------------------------------------- */
 
USING Progress.Lang.*.
BLOCK-LEVEL ON ERROR UNDO, THROW.
 
CLASS SFDC.SFDCREST: 
  /*------------------------------------------------------------------------------
      Purpose:  																	  
      Notes:  																	  
  ------------------------------------------------------------------------------*/

  {i/SFDCTT.i}
  DEFINE VARIABLE protocolType AS System.Net.SecurityProtocolType NO-UNDO.   
      
	
  DEFINE PUBLIC PROPERTY AccessToken AS CHARACTER NO-UNDO 
    GET.
    SET. 

  DEFINE PUBLIC PROPERTY ContentType AS CHARACTER NO-UNDO 
    GET.
    SET. 

  DEFINE PUBLIC PROPERTY RestServiceURL AS CHARACTER NO-UNDO 
    GET. 
    SET. 
        
  DEFINE PUBLIC PROPERTY ServerURL AS CHARACTER NO-UNDO 
    GET.
    SET. 


  /*------------------------------------------------------------------------------
      Purpose:  																	  
      Notes:  																	  
  ------------------------------------------------------------------------------*/

  CONSTRUCTOR PUBLIC SFDCREST ():
    SUPER ().
    
    THIS-OBJECT:RestServiceURL = Utility.MiscUtil:getIniKeyValue("SFDC","RESTURL").

    /* TLS 1.2 is NOT enabled by default. The following makes DotNet TLS 1.1 and 
       1.2 enabled for the entire session.  SFDC will be TLS 1.2 ONLY late 2016.  */
    THIS-OBJECT:protocolType = CAST(
      Progress.Util.EnumHelper:Or(
      System.Net.SecurityProtocolType:Tls12, System.Net.SecurityProtocolType:Tls11),
      System.Net.SecurityProtocolType).
    THIS-OBJECT:protocolType = CAST(
      Progress.Util.EnumHelper:Or(protocolType, System.Net.SecurityProtocolType:Tls),
      System.Net.SecurityProtocolType).
    System.Net.ServicePointManager:SecurityProtocol = THIS-OBJECT:protocolType.
    
    /* From Wikipedia:
         Transport Layer Security (TLS) and its predecessor, Secure Sockets Layer (SSL), both   
         of which are frequently referred to as 'SSL', are cryptographic protocols designed to  
         provide communications security over a computer network. 
         https://en.wikipedia.org/wiki/Transport_Layer_Security         */
    
    RETURN. 
  END CONSTRUCTOR.

  /*------------------------------------------------------------------------------
   Purpose:
   Notes:
  ------------------------------------------------------------------------------*/

  METHOD PUBLIC CHARACTER DeleteRecords( htt AS HANDLE):
    DEFINE VARIABLE vURL                AS CHARACTER                           NO-UNDO. 
    DEFINE VARIABLE sfdcREST            AS SFDC.SFDCREST                       NO-UNDO.
    DEFINE VARIABLE httpClient          AS System.Net.Http.HttpClient          NO-UNDO.   
    DEFINE VARIABLE httpResponseMessage AS System.Net.Http.HttpResponseMessage NO-UNDO.
    DEFINE VARIABLE httpRequestMessage  AS System.Net.Http.HttpRequestMessage  NO-UNDO.     
    DEFINE VARIABLE jsonResponse        AS LONGCHAR                            NO-UNDO. 
    DEFINE VARIABLE i                   AS INTEGER                             NO-UNDO. 
    DEFINE VARIABLE hBuf                AS HANDLE                              NO-UNDO. 
    DEFINE VARIABLE hQuery              AS HANDLE                              NO-UNDO. 
    
    hBuf = htt:DEFAULT-BUFFER-HANDLE. 
    CREATE QUERY hQuery.
    hQuery:SET-BUFFERS(hBuf).
    hQuery:QUERY-PREPARE("FOR EACH " + htt:NAME).
    hQuery:QUERY-OPEN.

    hQuery:GET-FIRST ().
    
    DO WHILE NOT hQuery:QUERY-OFF-END:
      vURL = THIS-OBJECT:ServerURL + THIS-OBJECT:RestServiceURL + "/sobjects/" + htt:SERIALIZE-NAME + "/" + hBuf:BUFFER-FIELD ("id"):BUFFER-VALUE.        
      httpClient = NEW System.Net.Http.HttpClient().
      httpRequestMessage = NEW System.Net.Http.HttpRequestMessage().
      httpRequestMessage:Method = System.Net.Http.HttpMethod:Delete.
      httpRequestMessage:RequestUri = NEW System.Uri(vUrl).
      httpRequestMessage:Headers:Add ("Authorization", "Bearer " + THIS-OBJECT:AccessToken).

      /* Use SendAsync in a synchronous manner by directly accessing the result */
      httpResponseMessage = httpClient:SendAsync(httpRequestMessage):Result.   
      
      /* jsonResponse will have error information if there is an error returned */  
      jsonResponse = httpResponseMessage:Content:ReadAsStringAsync():RESULT NO-ERROR.

      /* 204 response means "OK" */
      /* 404 means entity already deleted - probably can ingore it */
      IF  httpResponseMessage:StatusCode:value__ NE 204 AND 
        httpResponseMessage:StatusCode:value__ NE 404 THEN 
      DO:        
        UNDO, THROW NEW Progress.Lang.AppError(
          STRING (jsonResponse),  /* I got lazy... parse this */ 
          httpResponseMessage:StatusCode:value__
          ).          
      END.         
      
      /* remove this message - for demo only */ 
      MESSAGE "Deleted " + hBuf:BUFFER-FIELD ("id"):BUFFER-VALUE 
        VIEW-AS ALERT-BOX.
        
      hQuery:GET-NEXT (). 
    END.

    RETURN "".
  END METHOD.

  /*------------------------------------------------------------------------------
   Purpose:
   Notes:
  ------------------------------------------------------------------------------*/

  METHOD PUBLIC CHARACTER InsertRecords( INPUT hTT AS HANDLE ):
    DEFINE VARIABLE jsonBody            AS LONGCHAR                                    NO-UNDO. 
    DEFINE VARIABLE ids                 AS CHARACTER                                   NO-UNDO. 
    DEFINE VARIABLE i                   AS INTEGER                                     NO-UNDO. 
    DEFINE VARIABLE vURL                AS CHARACTER                                   NO-UNDO. 
    DEFINE VARIABLE jsonResponse        AS LONGCHAR                                    NO-UNDO. 
    DEFINE VARIABLE httpClient          AS System.Net.Http.HttpClient                  NO-UNDO.   
    DEFINE VARIABLE httpResponseMessage AS System.Net.Http.HttpResponseMessage         NO-UNDO.
    DEFINE VARIABLE httpRequestMessage  AS System.Net.Http.HttpRequestMessage          NO-UNDO.   
    DEFINE VARIABLE objectModelParser   AS Progress.Json.ObjectModel.ObjectModelParser NO-UNDO.
    DEFINE VARIABLE jsonObject          AS Progress.Json.ObjectModel.JsonObject        NO-UNDO.
    DEFINE VARIABLE jsonArray           AS Progress.Json.ObjectModel.JsonArray         NO-UNDO. 
                   
    vURL = THIS-OBJECT:ServerURL + THIS-OBJECT:RestServiceURL + "/sobjects/" + htt:SERIALIZE-NAME + "/".
    httpClient = NEW System.Net.Http.HttpClient().
 
    /* use the progress write-Json method on the temp-table to get the JSON to send to SFDC - don't need the outer object
       WRITE-JSON (<TYPE>, <target>, Formatted?, <Encoding>, OmitInitialValues?, OmitOuterObject? */ 
    htt:WRITE-JSON ("LongChar", jsonBody, FALSE, "Utf-8", TRUE, TRUE).
    
    objectModelParser = NEW Progress.Json.ObjectModel.ObjectModelParser().
    jsonArray = CAST (objectModelParser:Parse(jsonBody),Progress.Json.ObjectModel.JsonArray).  

    /* insert each record one at a time - surprised SFDC didn't support the array after knowing their SOAP */ 
    DO i = 1 TO jsonArray:LENGTH: 
      jsonObject = jsonArray:GetJsonObject(i).  
      jsonObject:Write(jsonBody).
        
      /* recreating httpRequestMessage in each loop and letting garbage collection do its job because
         :content gets set in each loop, it must be set before content:headers:contentType is set,
         and you can only set contentType once (so you can't re-use the object) */  
      httpRequestMessage = NEW System.Net.Http.HttpRequestMessage().
      httpRequestMessage:Method = System.Net.Http.HttpMethod:Post.
      httpRequestMessage:RequestUri = NEW System.Uri(vUrl).
      httpRequestMessage:Content = NEW System.Net.Http.StringContent(jsonBody, System.Text.Encoding:UTF8, "application/json").
      httpRequestMessage:Headers:Add ("Authorization", "Bearer " + THIS-OBJECT:AccessToken).

      /* Use SendAsync in a synchronous manner by directly accessing the result */
      httpResponseMessage = httpClient:SendAsync(httpRequestMessage):Result. 
      jsonResponse = httpResponseMessage:Content:ReadAsStringAsync():RESULT NO-ERROR.

      /* 201 response is "Created" */ 
      IF  httpResponseMessage:StatusCode:value__ <> 201 THEN 
        UNDO, THROW NEW Progress.Lang.AppError(
          STRING (jsonResponse),
          httpResponseMessage:StatusCode:value__
          ). 

      /* Load the JSON up into a JSON object */ 
      jsonObject = CAST
        (objectModelParser:Parse(jsonResponse),
        Progress.Json.ObjectModel.JsonObject).
    
      /* CSV of IDs inserted */ 
      ids = 
        ids + 
        (IF ids = "" THEN "" ELSE ",") +
        jsonObject:GetCharacter("id").

    END. 
    RETURN ids.

  END METHOD.

  /*------------------------------------------------------------------------------
   Purpose:
   Notes:
  ------------------------------------------------------------------------------*/

  METHOD PUBLIC VOID ReadRecords(IDs AS CHARACTER, htt AS HANDLE):
    DEFINE VARIABLE vURL                AS CHARACTER                                   NO-UNDO. 
    DEFINE VARIABLE sfdcREST            AS SFDC.SFDCREST                               NO-UNDO.
    DEFINE VARIABLE httpClient          AS System.Net.Http.HttpClient                  NO-UNDO.   
    DEFINE VARIABLE httpResponseMessage AS System.Net.Http.HttpResponseMessage         NO-UNDO.
    DEFINE VARIABLE httpRequestMessage  AS System.Net.Http.HttpRequestMessage          NO-UNDO.     
    DEFINE VARIABLE jsonResponse        AS LONGCHAR                                    NO-UNDO. 
    DEFINE VARIABLE i                   AS INTEGER                                     NO-UNDO. 
    DEFINE VARIABLE objectModelParser   AS Progress.Json.ObjectModel.ObjectModelParser NO-UNDO.
    DEFINE VARIABLE jsonObject          AS Progress.Json.ObjectModel.JsonObject        NO-UNDO.
    
    DO i = 1 TO NUM-ENTRIES (IDs):
      vURL = THIS-OBJECT:ServerURL + THIS-OBJECT:RestServiceURL + "/sobjects/" + htt:SERIALIZE-NAME + "/" + ENTRY (i, IDs).
       
      httpClient = NEW System.Net.Http.HttpClient().
      httpRequestMessage = NEW System.Net.Http.HttpRequestMessage().
      httpRequestMessage:Method = System.Net.Http.HttpMethod:Get.
      httpRequestMessage:RequestUri = NEW System.Uri(vUrl).
      httpRequestMessage:Headers:Add ("Authorization", "Bearer " + THIS-OBJECT:AccessToken).

      /* Use SendAsync in a synchronous manner by directly accessing the result */
      httpResponseMessage = httpClient:SendAsync(httpRequestMessage):Result.    
      jsonResponse = httpResponseMessage:Content:ReadAsStringAsync():RESULT NO-ERROR.

      /* 200 Response means "OK" */
      IF  httpResponseMessage:StatusCode:value__ <> 200 THEN 
        UNDO, THROW NEW Progress.Lang.AppError(
          STRING (jsonResponse),
          httpResponseMessage:StatusCode:value__
          ). 

      /* We cannot read teh json directly into the TT with the READ-JSON method 
         becuase READ-JSON cannot handle an embedded object. Since we don't need
         the attributes embedded object, the easy solution is to remove it */ 
      objectModelParser = NEW Progress.Json.ObjectModel.ObjectModelParser().
      jsonObject = CAST
        (objectModelParser:Parse(jsonResponse),
        Progress.Json.ObjectModel.JsonObject).

      jsonObject:Remove("attributes").
    
      htt:READ-JSON ("JsonObject", jsonObject).
    END.
    
    RETURN.
  END METHOD.

  /*------------------------------------------------------------------------------
   Purpose: Athenticate with SFDC to get back a token to use for authorization and
            the URL to use when making REST calls.
          
   Notes:   Use OAUTH2 for better security rather than Password security
  ------------------------------------------------------------------------------*/

  METHOD PUBLIC VOID SFDCPasswordConnect(  ):
    DEFINE VARIABLE vURL                   AS CHARACTER                                   NO-UNDO.
    DEFINE VARIABLE httpClient             AS System.Net.Http.HttpClient                  NO-UNDO.   
    DEFINE VARIABLE httpResponseMessage    AS System.Net.Http.HttpResponseMessage         NO-UNDO.
    DEFINE VARIABLE httpRequestMessage     AS System.Net.Http.HttpRequestMessage          NO-UNDO. 
    DEFINE VARIABLE jsonResponse           AS LONGCHAR                                    NO-UNDO.
    DEFINE VARIABLE objectModelParser      AS Progress.Json.ObjectModel.ObjectModelParser NO-UNDO.
    DEFINE VARIABLE jsonObject             AS Progress.Json.ObjectModel.JsonObject        NO-UNDO.
    DEFINE VARIABLE proNameValueCollection AS Utility.ProNameValueCollection              NO-UNDO.

    vURL  = Utility.MiscUtil:getIniKeyValue("SFDC","loginURL").
              
    /* Sending JSON is NOT supported for the token request - it IS supported for the other REST calls */        
    /* use a proNameValueCollection to create the form data rather than manually building a string as */
    /* it is less error-prone and easier to debug typos (especially if you have hundreds of items)    */     
    proNameValueCollection = NEW Utility.ProNameValueCollection().
    proNameValueCollection:Add("grant_type", "password").
    proNameValueCollection:Add("client_id", Utility.MiscUtil:getIniKeyValue("SFDC","consumerKey")).
    proNameValueCollection:Add("client_secret", Utility.MiscUtil:getIniKeyValue("SFDC","consumerSecret")).
    proNameValueCollection:Add("username", Utility.MiscUtil:getIniKeyValue("SFDC","username")).
    proNameValueCollection:Add( 
      "password", Utility.MiscUtil:getIniKeyValue("SFDC","password") + 
      Utility.MiscUtil:getIniKeyValue("SFDC","SecurityToken") ).

    httpClient = NEW System.Net.Http.HttpClient().
    httpRequestMessage = NEW System.Net.Http.HttpRequestMessage().
    httpRequestMessage:Method = System.Net.Http.HttpMethod:Post.
    httpRequestMessage:RequestUri = NEW System.Uri(vUrl).    
    httpRequestMessage:Content = proNameValueCollection:StringContent.
    httpRequestMessage:Content:Headers:ContentType = NEW System.Net.Http.Headers.MediaTypeHeaderValue("application/x-www-form-urlencoded").

    httpResponseMessage = httpClient:SendAsync(httpRequestMessage):Result. 
    jsonResponse = httpResponseMessage:Content:ReadAsStringAsync():RESULT NO-ERROR.

    IF  httpResponseMessage:StatusCode:value__ <> 200 THEN 
      UNDO, THROW NEW Progress.Lang.AppError(
        STRING (jsonResponse),
        httpResponseMessage:StatusCode:value__
        ). 

    objectModelParser = NEW Progress.Json.ObjectModel.ObjectModelParser().
    jsonObject = CAST
      (objectModelParser:Parse(jsonResponse),
      Progress.Json.ObjectModel.JsonObject).
        
    THIS-OBJECT:AccessToken = jsonObject:GetCharacter("access_token").
    THIS-OBJECT:ServerURL = jsonObject:GetCharacter("instance_url").

  END METHOD.  

END CLASS.
