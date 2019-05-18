 
/*------------------------------------------------------------------------
   File        : SFDCSOAP
   Purpose     : 
   Syntax      : 
   Description : 
   Author(s)   : WinningJr
   Created     : Thu Mar 10 12:13:29 EST 2016
   Notes       : 
 ----------------------------------------------------------------------*/

USING Progress.Lang.*.

BLOCK-LEVEL ON ERROR UNDO, THROW.

CLASS SFDC.SFDCSOAP: 

    DEFINE PUBLIC PROPERTY AccessToken AS CHARACTER NO-UNDO 
        GET.
        SET. 

    DEFINE PUBLIC PROPERTY ServerURL AS CHARACTER NO-UNDO 
        GET.
        SET. 

    /*------------------------------------------------------------------------------
     Purpose:
     Notes:
    ------------------------------------------------------------------------------*/

    METHOD PUBLIC VOID SFDCLogin(  ):		
        DEFINE VARIABLE hSoap         AS HANDLE                         NO-UNDO.
        DEFINE VARIABLE hWebService   AS HANDLE                         NO-UNDO.
        DEFINE VARIABLE wsdl          AS CHARACTER                      NO-UNDO. 
        DEFINE VARIABLE username      AS CHARACTER                      NO-UNDO.
        DEFINE VARIABLE password      AS CHARACTER                      NO-UNDO.  
        DEFINE VARIABLE securityToken AS CHARACTER                      NO-UNDO.
        DEFINE VARIABLE lcResult      AS LONGCHAR                       NO-UNDO. 
        DEFINE VARIABLE xDoc          AS System.Xml.XmlDocument         NO-UNDO.
        DEFINE VARIABLE nsManager     AS System.Xml.XmlNamespaceManager NO-UNDO.  
        
  
        wsdl = SEARCH ("SFDCEnterprise.WSDL").
        IF wsdl = ? THEN
        DO:
            MESSAGE   " Could not find WSDL File" 
                VIEW-AS ALERT-BOX .
            RETURN. 
        END.

        ASSIGN 
            userName      = "appdev@ovid.com.hlrp"
            password      = "Wilder15"
            securityToken = "7Ke7TiKekgYyXahBvyg0b59K".
            
        CREATE SERVER hWebService.
        hWebService:CONNECT("-WSDL '" + wsdl + "'").
        RUN Soap SET hSoap ON hWebService.
        
        /* passowrd is password and securityToken concatinated!!! */
        RUN login IN hSoap(INPUT username, INPUT password + securityToken, OUTPUT lcResult).
        
        /* parse the xml returned and set vcSFDCSession variable from the xml */
        hWebService:DISCONNECT( ).
        DELETE OBJECT hWebService NO-ERROR.

        xDoc = NEW System.XML.XMLDocument().
        xDoc:LoadXml(lcResult).
        nsManager = NEW System.XML.XmlNamespaceManager(xDoc:NameTable).     
        nsManager:AddNamespace("result", "urn:enterprise.soap.sforce.com").

        THIS-OBJECT:AccessToken = xdoc:SelectSingleNode("//result:result/result:sessionId", nsManager):InnerText. 
        THIS-OBJECT:ServerURL = xdoc:SelectSingleNode("//result:result/result:serverUrl", nsManager):InnerText.
  
        RETURN.

    END METHOD.

END CLASS.