
{i/SFDCTT.i}

DEFINE VARIABLE sfdcREST AS SFDC.SFDCREST NO-UNDO.
DEFINE VARIABLE htt      AS HANDLE        NO-UNDO. 
DEFINE VARIABLE sfdcIDs  AS CHARACTER     NO-UNDO.

htt = TEMP-TABLE ttCustomer:HANDLE. 
 
/* create records in the TT */ 
CREATE ttCustomer.
ASSIGN 
  ttCustomer.custName = "Bob Loblaw's Law Blog Pogs"
  ttCustomer.custType = "Legal". 
CREATE ttCustomer.
ASSIGN 
  ttCustomer.custName = "Benjamin's Buttons"
  ttCustomer.custType = "Manufacturing".
  
sfdcREST = NEW SFDC.SFDCREST().
       
/* connect to SFDC */
sfdcREST:SFDCPasswordConnect().   
 
/* insert the TT records in SFDC */  
sfdcIDs = sfdcREST:InsertRecords(htt).
MESSAGE
  "Inserted IDS: " sfdcIDs
  VIEW-AS ALERT-BOX.
  
/* empty the TT and prove that we are reading new records into it */  
EMPTY TEMP-TABLE ttCustomer.
MESSAGE
  "CAN-FIND (FIRST ttCustomer)? - "
  CAN-FIND (FIRST ttCustomer)
  VIEW-AS ALERT-BOX.

/* read two records into the TT */ 
sfdcREST:readRecords (sfdcIDs, htt).   

FOR EACH ttCustomer:
  MESSAGE 
    "Name: " ttCustomer.custName SKIP 
    "Type: " ttCustomer.custType
    VIEW-AS ALERT-BOX.   
END.    

/* Delete the two from SFDC */ 
sfdcREST:DeleteRecords(htt).

CATCH e AS Progress.Lang.Error:
  MESSAGE 
    "I Caught an Error: " SKIP 
    e:GetMessage (1)
    VIEW-AS ALERT-BOX. 
END.      
  