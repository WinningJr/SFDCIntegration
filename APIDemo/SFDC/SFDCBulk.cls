./*------------------------------------------------------------------------
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
 
CLASS SFDC.SFDCBulk: 
  /*------------------------------------------------------------------------------
      Purpose:  																	  
      Notes:  																	  
  ------------------------------------------------------------------------------*/

  {i/SFDCTT.i}
  DEFINE VARIABLE protocolType AS System.Net.SecurityProtocolType NO-UNDO.   
      

  DEFINE PUBLIC PROPERTY BulkServiceURL AS CHARACTER NO-UNDO 
    GET.
    SET. 

  DEFINE PUBLIC PROPERTY contentType AS CHARACTER NO-UNDO 
    GET(): 
      /* default to XML if not set by the user */ 
      IF contentType = "" THEN 
        ASSIGN contentType = "XML".
      RETURN contentType.
    END GET. 
    SET. 

  DEFINE PUBLIC PROPERTY sfdcREST AS SFDC.SFDCREST
    GET.
    SET.

  /*------------------------------------------------------------------------------
      Purpose:  																	  
      Notes:  																	  
  ------------------------------------------------------------------------------*/

  CONSTRUCTOR PUBLIC SFDCBulk ():
    SUPER ().

    THIS-OBJECT:BulkServiceURL = Utility.MiscUtil:getIniKeyValue("SFDC","BulkURL").
    THIS-OBJECT:sfdcREST = NEW SFDC.SFDCREST().
    sfdcREST:SFDCPasswordConnect().
    
    /* the following makes .Net TLS 1.1 and 1.2 enabled for the entire session  */
    /* TLS 1.2 is not enabled by default.  SFDC will be TLS 1.2 ONLY next year. */
    protocolType = CAST(
      Progress.Util.EnumHelper:Or(
      System.Net.SecurityProtocolType:Tls12, System.Net.SecurityProtocolType:Tls11),
      System.Net.SecurityProtocolType).
    protocolType = CAST(
      Progress.Util.EnumHelper:Or(protocolType, System.Net.SecurityProtocolType:Tls),
      System.Net.SecurityProtocolType).
    System.Net.ServicePointManager:SecurityProtocol = THIS-OBJECT:protocolType.
    
    RETURN. 
  END CONSTRUCTOR.

  /*------------------------------------------------------------------------------
      Purpose:                                      
      Notes:                                      
  ------------------------------------------------------------------------------*/
  
  METHOD PUBLIC CHARACTER buildFieldList( htt AS HANDLE ):
    DEFINE VARIABLE vsName AS CHARACTER NO-UNDO.
    DEFINE VARIABLE vi     AS INTEGER   NO-UNDO.
    DEFINE VARIABLE result AS CHARACTER NO-UNDO.
    
    loopy:
    DO vi = 1 TO hTT:DEFAULT-BUFFER-HANDLE:NUM-FIELDS:
      vsname = hTT:DEFAULT-BUFFER-HANDLE:BUFFER-FIELD (vi):SERIALIZE-NAME.
      IF vsname = "skipSFDC" THEN NEXT loopy.
      RESULT = 
        RESULT + 
        (IF RESULT = "" THEN "" ELSE ", ") + 
        vsname.
    END.
    
    RETURN result.

  END METHOD.

  /*------------------------------------------------------------------------------
      Purpose:  																	  
      Notes:  																	  
  ------------------------------------------------------------------------------*/

  METHOD PUBLIC CHARACTER CheckBatchStatus( pJobId AS CHARACTER, pBatchId AS CHARACTER ):
    DEFINE VARIABLE vStatus             AS CHARACTER                           NO-UNDO.
    DEFINE VARIABLE vURL                AS CHARACTER                           NO-UNDO. 
    DEFINE VARIABLE stateMessage        AS CHARACTER                           NO-UNDO. 
    DEFINE VARIABLE httpClient          AS System.Net.Http.HttpClient          NO-UNDO.
    DEFINE VARIABLE httpRequestMessage  AS System.Net.Http.HttpRequestMessage  NO-UNDO.  
    DEFINE VARIABLE httpResponseMessage AS System.Net.Http.HttpResponseMessage NO-UNDO.     
    DEFINE VARIABLE xDoc                AS System.Xml.XmlDocument              NO-UNDO.   
    DEFINE VARIABLE nsManager           AS System.Xml.XmlNamespaceManager      NO-UNDO.   
    DEFINE VARIABLE lcResult            AS LONGCHAR                            NO-UNDO.
      
    vURL = sfdcREST:ServerURL + THIS-OBJECT:BulkServiceURL + 
      "/job/" + pJobId + "/batch/" + pBatchId + "?antiCache=" + STRING (NOW).  
      
    httpClient = NEW System.Net.Http.HttpClient().
    httpRequestMessage = NEW System.Net.Http.HttpRequestMessage().
    httpRequestMessage:Method = System.Net.Http.HttpMethod:Get.
    httpRequestMessage:RequestUri = NEW System.Uri(vUrl).
    httpRequestMessage:Headers:Add ("X-SFDC-Session", sfdcREST:AccessToken).  
     
    /* Use SendAsync in a synchronous manner by directly accessing the result */
    httpResponseMessage = httpClient:SendAsync(httpRequestMessage):Result. 
    lcResult = httpResponseMessage:Content:ReadAsStringAsync():RESULT NO-ERROR.  
      
    IF httpResponseMessage:StatusCode:value__ NE 200 THEN 
      UNDO, THROW NEW Progress.Lang.AppError(
        "CheckBatchStatus - " + STRING (lcResult),  /* I got lazy... parse this */ 
        httpResponseMessage:StatusCode:value__
        ). 

    /* parse the returned xml to status (the field is "state" in the xml) */
    xDoc = NEW System.XML.XMLDocument().
    xDoc:LoadXml(lcResult).
    nsManager = NEW System.XML.XmlNamespaceManager(xDoc:NameTable).
    nsManager:AddNamespace("dataload", "http://www.force.com/2009/06/asyncapi/dataload").    
    vStatus =  xdoc:SelectSingleNode("//dataload:state", nsManager):InnerText.

    /* if the status is "failed", there will be an extra node with the error named "stateMessage" */
    IF vStatus = "Failed" THEN
    DO:
      stateMessage =  xdoc:SelectSingleNode("//dataload:stateMessage", nsManager):InnerText.      
      UNDO, THROW NEW Progress.Lang.AppError(" Batch Failed: " + stateMessage). 
    END.
 
    RETURN vStatus.

  END METHOD.

  /*------------------------------------------------------------------------------
      Purpose:  																	  
      Notes:  																	  
  ------------------------------------------------------------------------------*/

  METHOD PUBLIC CHARACTER CloseJob( pJobIds AS CHARACTER  ):
    DEFINE VARIABLE vi                  AS INTEGER                             NO-UNDO.
    DEFINE VARIABLE vURL                AS CHARACTER                           NO-UNDO.
    DEFINE VARIABLE xmlRequest          AS LONGCHAR                            NO-UNDO.
    DEFINE VARIABLE httpClient          AS System.Net.Http.HttpClient          NO-UNDO.
    DEFINE VARIABLE httpRequestMessage  AS System.Net.Http.HttpRequestMessage  NO-UNDO.  
    DEFINE VARIABLE httpResponseMessage AS System.Net.Http.HttpResponseMessage NO-UNDO. 
    DEFINE VARIABLE lcResult            AS LONGCHAR                            NO-UNDO.
    DEFINE VARIABLE xDoc                AS System.XML.XmlDocument              NO-UNDO.
    DEFINE VARIABLE nsManager           AS System.Xml.XmlNamespaceManager      NO-UNDO. 
    DEFINE VARIABLE stateValues         AS CHARACTER                           NO-UNDO. 
      
    DO vi = 1 TO NUM-ENTRIES (pJobIds):
        
      xmlRequest = '<?xml version="1.0" encoding="UTF-8"?>' +
        '<jobInfo xmlns="http://www.force.com/2009/06/asyncapi/dataload">' +
        '<state>Closed</state>' +
        '</jobInfo>'.

      vURL = sfdcREST:serverURL + THIS-OBJECT:BulkServiceURL + "/job/" + ENTRY (vi,pJobIds).
      
      httpClient = NEW System.Net.Http.HttpClient().
      httpRequestMessage = NEW System.Net.Http.HttpRequestMessage().
      httpRequestMessage:Method = System.Net.Http.HttpMethod:Post.
      httpRequestMessage:RequestUri = NEW System.Uri(vUrl).
      httpRequestMessage:Content =  NEW System.Net.Http.StringContent(xmlRequest).
      httpRequestMessage:Content:Headers:ContentType = NEW System.Net.Http.Headers.MediaTypeHeaderValue("application/xml").
      httpRequestMessage:Headers:Add ("X-SFDC-Session", sfdcREST:AccessToken).  
     
      /* Use SendAsync in a synchronous manner by directly accessing the result */
      httpResponseMessage = httpClient:SendAsync(httpRequestMessage):Result. 
      lcResult = httpResponseMessage:Content:ReadAsStringAsync():RESULT NO-ERROR.

      xDoc = NEW System.XML.XMLDocument().
      xDoc:LoadXml(lcResult).
      nsManager = NEW System.XML.XmlNamespaceManager(xDoc:NameTable).
      nsManager:AddNamespace("dataload", "http://www.force.com/2009/06/asyncapi/dataload").    
      stateValues =  
        stateValues + 
        (IF stateValues = "" THEN "" ELSE ",") +
        ENTRY (vi,pJobIds) + ":" +
        xdoc:SelectSingleNode("//dataload:state", nsManager):InnerText.
    END.
    RETURN stateValues.
  END METHOD.

  /*------------------------------------------------------------------------------
      Purpose:  																	  
      Notes:  																	  
  ------------------------------------------------------------------------------*/

  METHOD PUBLIC CHARACTER CreateBatch( hTT AS HANDLE, pJobId AS CHARACTER    ):
    DEFINE VARIABLE batchId             AS CHARACTER                           NO-UNDO.
    DEFINE VARIABLE OSQL                AS CHARACTER                           NO-UNDO.
    DEFINE VARIABLE vURL                AS CHARACTER                           NO-UNDO. 
    DEFINE VARIABLE httpClient          AS System.Net.Http.HttpClient          NO-UNDO.
    DEFINE VARIABLE httpRequestMessage  AS System.Net.Http.HttpRequestMessage  NO-UNDO.  
    DEFINE VARIABLE httpResponseMessage AS System.Net.Http.HttpResponseMessage NO-UNDO. 
    DEFINE VARIABLE xDoc                AS System.XML.XmlDocument              NO-UNDO.
    DEFINE VARIABLE nsManager           AS System.Xml.XmlNamespaceManager      NO-UNDO. 
    DEFINE VARIABLE lcResult            AS LONGCHAR                            NO-UNDO.
		

    vURL = sfdcREST:ServerURL + THIS-OBJECT:BulkServiceURL + "/job/" + pJobId + "/batch".
    OSQL = 'Select ' + buildFieldList(htt) + ' FROM ' + htt:SERIALIZE-NAME.
  
    httpClient = NEW System.Net.Http.HttpClient().
    httpRequestMessage = NEW System.Net.Http.HttpRequestMessage().
    httpRequestMessage:Method = System.Net.Http.HttpMethod:Post.
    httpRequestMessage:RequestUri = NEW System.Uri(vUrl).
    httpRequestMessage:Content =  NEW System.Net.Http.StringContent(OSQL).    
    httpRequestMessage:Content:Headers:ContentType = NEW System.Net.Http.Headers.MediaTypeHeaderValue("application/xml").
    httpRequestMessage:Headers:Add ("X-SFDC-Session", sfdcREST:AccessToken).  

    CASE THIS-OBJECT:contentType:
      WHEN "CSV" THEN
        httpRequestMessage:Content:Headers:ContentType = NEW System.Net.Http.Headers.MediaTypeHeaderValue("text/csv").
      WHEN "JSON" THEN
        httpRequestMessage:Content:Headers:ContentType = NEW System.Net.Http.Headers.MediaTypeHeaderValue("application/json").
      OTHERWISE
      httpRequestMessage:Content:Headers:ContentType = NEW System.Net.Http.Headers.MediaTypeHeaderValue("application/xml").
    END CASE.
      
    /* Use SendAsync in a synchronous manner by directly accessing the result */
    httpResponseMessage = httpClient:SendAsync(httpRequestMessage):Result. 
    lcResult = httpResponseMessage:Content:ReadAsStringAsync():RESULT NO-ERROR.
    
    IF httpResponseMessage:StatusCode:value__ NE 201 THEN 
      UNDO, THROW NEW Progress.Lang.AppError(
        STRING (lcResult),  /* I got lazy... parse this */ 
        httpResponseMessage:StatusCode:value__
        ). 
    
    xDoc = NEW System.XML.XMLDocument().
    xDoc:LoadXml(lcResult).
    nsManager = NEW System.XML.XmlNamespaceManager(xDoc:NameTable).
    nsManager:AddNamespace("dataload", "http://www.force.com/2009/06/asyncapi/dataload").    
    batchId =  xdoc:SelectSingleNode("//dataload:id", nsManager):InnerText.
      
    RETURN batchId.

  END METHOD.

  /*------------------------------------------------------------------------------
      Purpose:                                      
      Notes:                                      
  ------------------------------------------------------------------------------*/

  METHOD PUBLIC CHARACTER CreateJob(pOperation AS CHARACTER, pObject AS CHARACTER  ):
    RETURN CreateJob (pOperation, pObject, FALSE).
  END METHOD.

  METHOD PUBLIC CHARACTER CreateJob(pOperation AS CHARACTER, pObject AS CHARACTER, pPKChunking AS LOGICAL ):
    DEFINE VARIABLE JobId               AS CHARACTER                           NO-UNDO.
    DEFINE VARIABLE vURL                AS CHARACTER                           NO-UNDO.
    DEFINE VARIABLE xmlRequest          AS LONGCHAR                            NO-UNDO.
    DEFINE VARIABLE httpClient          AS System.Net.Http.HttpClient          NO-UNDO.
    DEFINE VARIABLE httpRequestMessage  AS System.Net.Http.HttpRequestMessage  NO-UNDO.  
    DEFINE VARIABLE httpResponseMessage AS System.Net.Http.HttpResponseMessage NO-UNDO. 
    DEFINE VARIABLE lcResult            AS LONGCHAR                            NO-UNDO. 
    DEFINE VARIABLE xDoc                AS System.XML.XmlDocument              NO-UNDO.
    DEFINE VARIABLE nsManager           AS System.Xml.XmlNamespaceManager      NO-UNDO. 
    
    xmlRequest = '<?xml version="1.0" encoding="UTF-8"?> ' +
      '<jobInfo xmlns="http://www.force.com/2009/06/asyncapi/dataload"> ' +
      '<operation>' + pOperation + '</operation> ' +
      '<object>' + pObject + '</object> ' +
      '<concurrencyMode>' + "Parallel" + '</concurrencyMode> ' +
      '<contentType>' + THIS-OBJECT:contentType + '</contentType> ' +
      '</jobInfo>'.

    vURL = sfdcREST:ServerURL + THIS-OBJECT:BulkServiceURL + "/job".
    
    httpClient = NEW System.Net.Http.HttpClient().
    httpRequestMessage = NEW System.Net.Http.HttpRequestMessage().
    httpRequestMessage:Method = System.Net.Http.HttpMethod:Post.
    httpRequestMessage:RequestUri = NEW System.Uri(vUrl).
    httpRequestMessage:Content =  NEW System.Net.Http.StringContent(xmlRequest).
    httpRequestMessage:Content:Headers:ContentType = NEW System.Net.Http.Headers.MediaTypeHeaderValue("application/xml").
    httpRequestMessage:Headers:Add ("X-SFDC-Session", sfdcREST:AccessToken).  
    
    /* Salesforce recommends that you enable PK chunking when querying tables with more than 10 million records or when 
       a bulk query consistently times out */
    IF pPKChunking THEN 
    DO: 
      /*      httpRequestMessage:Headers:Add ("Sforce-Enable-PKChunking", "true").*/
      httpRequestMessage:Headers:Add ("Sforce-Enable-PKChunking", "chunkSize=10000").
    END.
    
    /* Use SendAsync in a synchronous manner by directly accessing the result */
    httpResponseMessage = httpClient:SendAsync(httpRequestMessage):Result. 
    lcResult = httpResponseMessage:Content:ReadAsStringAsync():RESULT NO-ERROR.
    
    IF httpResponseMessage:StatusCode:value__ NE 201 THEN 
      UNDO, THROW NEW Progress.Lang.AppError(
        STRING (lcResult),  /* I got lazy... parse this */ 
        httpResponseMessage:StatusCode:value__
        ). 
    
    /* parse the jobID from the returned XML */ 
    xDoc = NEW System.XML.XMLDocument().
    xDoc:LoadXml(lcResult).
    nsManager = NEW System.XML.XmlNamespaceManager(xDoc:NameTable).
    nsManager:AddNamespace("dataload", "http://www.force.com/2009/06/asyncapi/dataload").    
    jobId =  xdoc:SelectSingleNode("//dataload:id", nsManager):InnerText.
    
    RETURN jobId.
     
  END METHOD.

  /*------------------------------------------------------------------------------
   Purpose:
   Notes:
  ------------------------------------------------------------------------------*/

  METHOD PUBLIC CHARACTER GetBatchIDs( pJobId AS CHARACTER  ):
    DEFINE VARIABLE batchIds            AS CHARACTER                           NO-UNDO.
    DEFINE VARIABLE vURL                AS CHARACTER                           NO-UNDO. 
    DEFINE VARIABLE httpClient          AS System.Net.Http.HttpClient          NO-UNDO.
    DEFINE VARIABLE httpRequestMessage  AS System.Net.Http.HttpRequestMessage  NO-UNDO.  
    DEFINE VARIABLE httpResponseMessage AS System.Net.Http.HttpResponseMessage NO-UNDO.    
    DEFINE VARIABLE xDoc                AS System.XML.XmlDocument              NO-UNDO.
    DEFINE VARIABLE nsManager           AS System.Xml.XmlNamespaceManager      NO-UNDO. 
    DEFINE VARIABLE xmlNodes            AS System.Xml.XmlNodeList              NO-UNDO. 
    /*    DEFINE VARIABLE xmlNode             AS                   NO-UNDO.*/
    DEFINE VARIABLE lcResult            AS LONGCHAR                            NO-UNDO.

    vURL = sfdcREST:ServerURL + THIS-OBJECT:BulkServiceURL + 
      "/job/" + pJobId + "/batch".
  
    httpClient = NEW System.Net.Http.HttpClient().
    httpRequestMessage = NEW System.Net.Http.HttpRequestMessage().
    httpRequestMessage:Method = System.Net.Http.HttpMethod:Get.
    httpRequestMessage:RequestUri = NEW System.Uri(vUrl).
    httpRequestMessage:Headers:Add ("X-SFDC-Session", sfdcREST:AccessToken).
      
    /* Use SendAsync in a synchronous manner by directly accessing the result */
    httpResponseMessage = httpClient:SendAsync(httpRequestMessage):Result. 
    lcResult = httpResponseMessage:Content:ReadAsStringAsync():RESULT NO-ERROR.     

    IF httpResponseMessage:StatusCode:value__ NE 200 THEN 
      UNDO, THROW NEW Progress.Lang.AppError(
        STRING (lcResult),  /* I got lazy... parse this */ 
        httpResponseMessage:StatusCode:value__
        ). 

    PUT UNFORMATTED STRING (lcResult) SKIP. 

    xDoc = NEW System.XML.XMLDocument().
    xDoc:LoadXml(lcResult).
    nsManager = NEW System.XML.XmlNamespaceManager(xDoc:NameTable).
    nsManager:AddNamespace("dataload", "http://www.force.com/2009/06/asyncapi/dataload").    
    xmlNodes = xDoc:SelectNodes("//dataload:id", nsmanager). 
    
    /* loop through each node in the nodes collection using "foreach.i" stolen from Mike Fechner / Consultingwerk Ltd. */ 
    {i/foreach.i System.Xml.XmlNode oxmlNode  in xmlNodes}
   
      batchIds = 
        batchIds + 
        (IF batchIds = "" THEN "" ELSE ",") + 
         oxmlNode:InnerText.
  END.

    RETURN batchIds.
  END METHOD.


  /*------------------------------------------------------------------------------
      Purpose:  																	  
      Notes:  																	  
  ------------------------------------------------------------------------------*/
  METHOD PUBLIC VOID retrieveBatchToTT( hTT AS HANDLE, pJobId AS CHARACTER, pBatchId AS CHARACTER  ):
    retrieveBatchToTT( hTT, pJobId, pBatchId, FALSE).
  END METHOD.
    
  METHOD PUBLIC VOID retrieveBatchToTT( hTT AS HANDLE, pJobId AS CHARACTER, pBatchId AS CHARACTER, pAppend AS LOGICAL ):
    DEFINE VARIABLE lcResult            AS LONGCHAR                            NO-UNDO.
    DEFINE VARIABLE vURL                AS CHARACTER                           NO-UNDO.
    DEFINE VARIABLE vName               AS CHARACTER                           NO-UNDO.
    DEFINE VARIABLE httpClient          AS System.Net.Http.HttpClient          NO-UNDO.
    DEFINE VARIABLE httpRequestMessage  AS System.Net.Http.HttpRequestMessage  NO-UNDO.  
    DEFINE VARIABLE httpResponseMessage AS System.Net.Http.HttpResponseMessage NO-UNDO.     
    DEFINE VARIABLE xDoc                AS System.XML.XmlDocument              NO-UNDO.
    DEFINE VARIABLE nsManager           AS System.Xml.XmlNamespaceManager      NO-UNDO. 
    DEFINE VARIABLE xmlNodes            AS System.Xml.XmlNodeList              NO-UNDO. 
    DEFINE VARIABLE resultID            AS CHARACTER                           NO-UNDO. 
    DEFINE VARIABLE delimitedFile       AS Utility.DelimitedFile               NO-UNDO.
 
    /* two part call.  first, get the resultId for the file, then download the file using the resultID */ 
    vURL = sfdcREST:serverURL + THIS-OBJECT:BulkServiceURL + "/job/" + pJobId + "/batch/" + pBatchId + "/result/".
 
    httpClient = NEW System.Net.Http.HttpClient().
    httpRequestMessage = NEW System.Net.Http.HttpRequestMessage().
    httpRequestMessage:Method = System.Net.Http.HttpMethod:Get.
    httpRequestMessage:RequestUri = NEW System.Uri(vUrl).
    httpRequestMessage:Headers:Add ("X-SFDC-Session", sfdcREST:AccessToken).  
     
    /* Use SendAsync in a synchronous manner by directly accessing the result */
    httpResponseMessage = httpClient:SendAsync(httpRequestMessage):Result. 
    lcResult = httpResponseMessage:Content:ReadAsStringAsync():RESULT NO-ERROR.     

    IF httpResponseMessage:StatusCode:value__ NE 200 THEN 
      UNDO, THROW NEW Progress.Lang.AppError(
        "retrieveBatchToTT1 - " + STRING (lcResult),  /* I got lazy... parse this */ 
        httpResponseMessage:StatusCode:value__
        ). 

    xDoc = NEW System.XML.XMLDocument().
    xDoc:LoadXml(lcResult).
    nsManager = NEW System.XML.XmlNamespaceManager(xDoc:NameTable).
    nsManager:AddNamespace("dataload", "http://www.force.com/2009/06/asyncapi/dataload").    
    resultID =  xdoc:SelectSingleNode("//dataload:result", nsManager):InnerText.

    vURL =  sfdcREST:serverURL + THIS-OBJECT:BulkServiceURL + 
      "/job/" + pJobId + "/batch/" + pBatchId + "/result/" + resultId. 
            
    httpRequestMessage = NEW System.Net.Http.HttpRequestMessage().
    httpRequestMessage:Method = System.Net.Http.HttpMethod:Get.
    httpRequestMessage:RequestUri = NEW System.Uri(vUrl).
    httpRequestMessage:Headers:Add ("X-SFDC-Session", sfdcREST:AccessToken).  
     
    /* Use SendAsync in a synchronous manner by directly accessing the result */
    httpResponseMessage = httpClient:SendAsync(httpRequestMessage):Result. 
    lcResult = httpResponseMessage:Content:ReadAsStringAsync():RESULT NO-ERROR.     

    IF httpResponseMessage:StatusCode:value__ NE 200 THEN 
      UNDO, THROW NEW Progress.Lang.AppError(
        "retrieveBatchToTT2 - " + STRING (lcResult),  /* I got lazy... parse this */ 
        httpResponseMessage:StatusCode:value__
        ). 
    /* get the delited date into the TT */ 
    CASE THIS-OBJECT:contentType:
      WHEN "CSV" THEN 
        DO: 
          delimitedFile = NEW Utility.DelimitedFile(lcResult). 
          delimitedFile:copyToTT(TABLE-HANDLE hTT BY-REFERENCE ) .  
        END.
      WHEN "JSON" THEN 
        DO:
        END.
      OTHERWISE 
      DO: 
        vName = hTT:SERIALIZE-NAME .
        hTT:SERIALIZE-NAME = "Records".
        hTT:READ-XML (
        "LongChar", 
        lcResult, 
        (IF pAppend THEN "APPEND" ELSE "EMPTY"), 
        ?, 
        ?)  .
        hTT:SERIALIZE-NAME = vName.
      END.
    END CASE. 
    
    RETURN.

  END METHOD.

END CLASS.
