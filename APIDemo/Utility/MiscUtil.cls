 
/*------------------------------------------------------------------------
   File        : MiscUtil
   Purpose     : 
   Syntax      : 
   Description : 
   Author(s)   : WinningJr
   Created     : Mon Mar 21 17:02:17 EDT 2016
   Notes       : 
 ----------------------------------------------------------------------*/

USING Progress.Lang.*.

BLOCK-LEVEL ON ERROR UNDO, THROW.

CLASS Utility.MiscUtil: 



  /*------------------------------------------------------------------------------
   Purpose:
   Notes:
  ------------------------------------------------------------------------------*/
		
  CONSTRUCTOR STATIC MiscUtil (  ):
    FILE-INFO:FILE-NAME = SEARCH("SFDCAPI.ini").
    IF FILE-INFO:FILE-NAME NE ? THEN 
      LOAD "SFDCAPI"
        DIR SUBSTRING(FILE-INFO:FULL-PATHNAME,1,R-INDEX(FILE-INFO:FULL-PATHNAME,"\") - 1)
        BASE-KEY "ini".
		
  END CONSTRUCTOR.


  /*------------------------------------------------------------------------------
   Purpose:
   Notes:
  ------------------------------------------------------------------------------*/

  METHOD PUBLIC STATIC CHARACTER  getIniKeyValue(pSection AS CHARACTER, pKey AS CHARACTER ):
    DEFINE VARIABLE keyvalue AS CHARACTER NO-UNDO.

    USE "SFDCAPI".
    GET-KEY-VALUE SECTION pSection KEY pKey VALUE keyvalue.
    RETURN keyValue.

  END METHOD.

END CLASS.