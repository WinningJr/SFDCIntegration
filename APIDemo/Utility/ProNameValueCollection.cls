/*------------------------------------------------------------------------
   File        : ProNameValueCollection
   Purpose     : 
   Syntax      : 
   Description : 
   Author(s)   : Tom.Bergman
   Created     : Fri Mar 18 12:13:49 EDT 2016
   Notes       : 
 ----------------------------------------------------------------------*/

USING Progress.Lang.*.
USING System.Collections.Specialized.NameValueCollection.
USING System.Net.Http.*.

BLOCK-LEVEL ON ERROR UNDO, THROW.

CLASS Utility.ProNameValueCollection INHERITS NameValueCollection:  

  DEFINE PUBLIC PROPERTY QueryString AS CHARACTER NO-UNDO 
    GET():
      DEFINE VARIABLE i             AS INTEGER.
      DEFINE VARIABLE contentString AS CHARACTER.
      DO i = 0 TO THIS-OBJECT:Count - 1:

        contentString =  contentString + THIS-OBJECT:getKey(i) + "=" +
          System.Web.HttpUtility:UrlEncode(THIS-OBJECT:Item[i]) + "&" .
    
      END.  
      RETURN TRIM(contentString,"&").
    END GET.
    PRIVATE SET. 

  DEFINE PUBLIC PROPERTY StringContent AS StringContent NO-UNDO 
    GET():
      RETURN NEW StringContent(QueryString).
    END GET.
    PRIVATE SET. 

END CLASS.
