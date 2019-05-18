 
/*------------------------------------------------------------------------
   File        : DelimitedFile
   Purpose     : Deal with a file of delimited data (such as load it into a TT).  
                 It can read it in from a file or it will accept a longchar that 
                 already has the data loaded.  
   Syntax      : 
   Description : 
   Author(s)   : gerry.winning
   Created     : Thu Feb 11 12:53:38 CST 2016
   Notes       : 
 ----------------------------------------------------------------------*/

USING Progress.Lang.*.

BLOCK-LEVEL ON ERROR UNDO, THROW.

CLASS Utility.DelimitedFile: 
  
  DEFINE TEMP-TABLE ttNameLookup NO-UNDO
    FIELD FieldName     AS CHARACTER 
    FIELD SerializeName AS CHARACTER
    INDEX idxMain serializeName. 
  
  DEFINE PUBLIC PROPERTY fieldsMustExist AS LOGICAL NO-UNDO 
    GET.
    SET. 

  DEFINE PUBLIC PROPERTY fileContents AS LONGCHAR NO-UNDO 
    GET.
    SET. 
    
  DEFINE PUBLIC PROPERTY fileFullPathName AS CHARACTER NO-UNDO 
    GET.
    SET. 
    
  DEFINE PUBLIC PROPERTY fileDelimiter AS CHARACTER NO-UNDO 
    GET(): 
      IF fileDelimiter = "" OR fileDelimiter = ? THEN 
        fileDelimiter = ",".
      RETURN fileDelimiter.
    END GET. 
    SET. 

  DEFINE PUBLIC PROPERTY fileSize AS INTEGER NO-UNDO 
    GET():
      RETURN LENGTH (THIS-OBJECT:fileContents).
    END GET. 
    SET.     

  /*------------------------------------------------------------------------------
   Purpose:
   Notes:
  ------------------------------------------------------------------------------*/
    
  CONSTRUCTOR PUBLIC DelimitedFile ( pFileName AS CHARACTER  ):
    SUPER ().

    THIS-OBJECT:fileFullPathName = SEARCH (pFileName) NO-ERROR. 
    IF THIS-OBJECT:fileFullPathName = ? THEN 
      RETURN.       
      
    COPY-LOB  FILE THIS-OBJECT:fileFullPathName TO THIS-OBJECT:fileContents NO-CONVERT.
        
  END CONSTRUCTOR.
  
  CONSTRUCTOR PUBLIC DelimitedFile ( PFileContents AS LONGCHAR  ):
    SUPER ().
    
    COPY-LOB pFileContents TO THIS-OBJECT:fileContents. 
    
  END CONSTRUCTOR.

  /*------------------------------------------------------------------------------
   Purpose:  Load a delimited file into a pre-defined TT 
   Notes:    
  ------------------------------------------------------------------------------*/

  METHOD PUBLIC CHARACTER copyToTT( TABLE-HANDLE hTT  ):
    DEFINE VARIABLE SR              AS System.IO.StringReader                       NO-UNDO. 
    DEFINE VARIABLE textFieldParser AS Microsoft.VisualBasic.FileIO.TextFieldParser NO-UNDO.    
    DEFINE VARIABLE vDelims         AS CHARACTER                                    EXTENT 1.
    DEFINE VARIABLE CurrentRow      AS CHARACTER                                    EXTENT.
    DEFINE VARIABLE vLong           AS LONGCHAR                                     NO-UNDO.
    DEFINE VARIABLE FieldList       AS CHARACTER                                    EXTENT.
    DEFINE VARIABLE i               AS INTEGER                                      NO-UNDO.
    DEFINE VARIABLE hbuff           AS HANDLE                                       NO-UNDO.
    DEFINE VARIABLE hField          AS HANDLE                                       NO-UNDO.
       
    IF THIS-OBJECT:fileSize = 0 THEN 
      RETURN "0 Length File". 
    /* use whatever delimiter was set in this object.  It default to CSV if none was specified */    
    vDelims[1] = THIS-OBJECT:fileDelimiter.
    hBuff = hTT:DEFAULT-BUFFER-HANDLE.
    SR = NEW System.IO.StringReader(fileContents).
    textFieldParser = NEW Microsoft.VisualBasic.FileIO.TextFieldParser(SR).
    textFieldParser:TextFieldType = Microsoft.VisualBasic.FileIO.FieldType:Delimited.
    textFieldParser:Delimiters = vDelims.

    /* use the header row to create an array of field names for mapping the position of data in each row with a fieldname */ 
    FieldList = textFieldParser:ReadFields().
    
    /* build the serialize name to name lookup table */ 
    EMPTY TEMP-TABLE ttNameLookup.
    DO i = 1 TO hBuff:NUM-FIELDS:
      CREATE ttNameLookup.
      ASSIGN 
        ttNameLookup.FieldName     = hBuff:BUFFER-FIELD (i):NAME
        ttNameLookup.SerializeName = hBuff:BUFFER-FIELD (i):SERIALIZE-NAME.
    END.

    /* Loop through the file */ 
    DO WHILE NOT textFieldParser:EndOfData:
      /* create a row in the temp-table */
      hBuff:BUFFER-CREATE ().
      
      /* read a row from the text file into an array */ 
      currentRow = textFieldParser:ReadFields().
        
      /* read a value from the line in the delimited file into each TT field with a matching name from the header row */  
      fieldLoop:
      DO i = 1 TO EXTENT (fieldList):

        /* find the field name for the current column based on its serialize-name */ 
        FIND ttNameLookup
          WHERE ttNameLookup.SerializeName = fieldList[i]
          NO-ERROR. 
          
        /* if the field from the csv is not in the TT, ingore it unless you have 
           set the fieldsMustExist property to true */
        IF NOT AVAILABLE ttNameLookup THEN 
        DO: 
          /* only bomb out if we require all fields exist */
          IF THIS-OBJECT:fieldsMustExist THEN 
            RETURN fieldList[i] + " is not in the temp-table".
          
          /* we got here, it is ok that the field doesn't exist, move on to the next field */ 
          NEXT fieldLoop.
        END.
        
        /* find the field in the TT with the same name as this array element in the field list from the header row */
        hField = hBuff:BUFFER-FIELD(ttNameLookup.FieldName).
        
        IF hField:DATA-TYPE BEGINS "Date"
          THEN hField:BUFFER-VALUE = System.DateTime:Parse(currentRow[i]).
        ELSE 
          hField:BUFFER-VALUE = currentRow[i].
      END. /* fieldLoop */
    END.  /*  DO WHILE NOT textFieldParser:EndOfData: */ 
    
    textFieldParser:Close().
    SR:Close().

    RETURN "". 

  END METHOD.

END CLASS.