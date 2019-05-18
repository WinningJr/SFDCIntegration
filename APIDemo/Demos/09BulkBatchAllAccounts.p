/* 
  Multiple batch example (retrieves one giant set of data)
  https://developer.salesforce.com/docs/atlas.en-us.api_asynch.meta/api_asynch/asynch_api_code_curl_walkthrough_pk_chunking.htm
*/

{i/sfdctt.i}

DEFINE TEMP-TABLE ttBatches NO-UNDO
  FIELD batchID     AS CHARACTER 
  FIELD batchStatus AS CHARACTER 
  INDEX idxMain batchStatus. 

DEFINE VARIABLE sfdcBULK     AS SFDC.SFDCBULK NO-UNDO.
DEFINE VARIABLE htt          AS HANDLE        NO-UNDO. 
DEFINE VARIABLE jobId        AS CHARACTER     NO-UNDO. 
DEFINE VARIABLE batchId      AS CHARACTER     NO-UNDO. 
DEFINE VARIABLE i            AS INTEGER       NO-UNDO. 
DEFINE VARIABLE batchStatus  AS CHARACTER     NO-UNDO. 
DEFINE VARIABLE jobState     AS CHARACTER     NO-UNDO. 
DEFINE VARIABLE batchIdList  AS CHARACTER     NO-UNDO. 
DEFINE VARIABLE batchIdList1 AS CHARACTER     NO-UNDO. 

ETIME (TRUE).
OUTPUT TO "Logs/bulk.txt".
htt = TEMP-TABLE ttCustomer:HANDLE. 

sfdcBULK = NEW SFDC.SFDCBULK().
sfdcBULK:contentType = "CSV".

/* enable PKChunking */ 
jobId = sfdcBULK:CreateJob("query", "Account", TRUE ). 
PUT UNFORMATTED 
  NOW " JobID: "jobId SKIP.
 
/* create a primary batch - it doesn't do any real work and is never marked processed */ 
batchId = sfdcBULK:CreateBatch(htt, jobId).

/* get back the list of batches that are automatically created that will return the results */ 
batchIDList = sfdcBULK:GetBatchIDs(jobId).
PUT UNFORMATTED 
  NOW " Batches?: " batchIDList SKIP. 

/* all processing is done in the child batches */ 
buildTT:
DO i = 1 TO NUM-ENTRIES (batchIDList):
  IF ENTRY (i, batchIDList) = batchID THEN
    NEXT buildTT.
    
  CREATE ttBatches.
  ASSIGN 
    ttBatches.batchID     = ENTRY (i, batchIDList)
    ttBatches.batchStatus = "Queued".
END.

PUT UNFORMATTED 
  "Primary BatchID: " batchId SKIP. 
PUT UNFORMATTED batchIDList SKIP. 

polloopalooza:
REPEAT:  

  FOR EACH ttBatches
    WHERE ttBatches.batchStatus = "Queued":
      
    batchStatus = sfdcBULK:CheckBatchStatus(jobId, ttBatches.batchID). 
    
    /* show status for demo */ 
    PUT UNFORMATTED NOW " BatchId: " ttBatches.batchID " status: " batchStatus SKIP. 
    
    IF batchStatus = "failed" OR batchStatus = "InvalidBatch" THEN  
    DO:
      PUT UNFORMATTED   
        "Site Batch Status = "  batchStatus SKIP . 
      RETURN.     
    END.

    IF batchStatus EQ "Completed" THEN
      ASSIGN 
        ttBatches.batchStatus = "Completed".
  END.         
  
  IF NOT CAN-FIND (FIRST ttBatches WHERE ttBatches.batchStatus = "Queued") THEN  
    LEAVE polloopalooza.
  PUT UNFORMATTED NOW " Looping" SKIP .
  System.Threading.Thread:Sleep(100).
END. /* pollLoop */

/* read the batches into the TT */ 
EMPTY TEMP-TABLE ttCustomer.
FOR EACH ttBatches:  
  PUT UNFORMATTED NOW " Loading Batch " ttBatches.batchID " into the TT" SKIP. 
  sfdcBULK:retrieveBatchToTT (htt,jobId,ttBatches.batchID, TRUE). 
END.

jobState = sfdcBULK:CloseJob(jobId).

FOR EACH ttCustomer:
  i = i + 1.
  DISPLAY ttCustomer.id ttcustomer.custName  FORMAT "x(44)".
END.
OUTPUT CLOSE. 

MESSAGE 
  "Records: " i SKIP 
  STRING (ETIME / 1000)
  VIEW-AS ALERT-BOX.

CATCH e AS Progress.Lang.Error:
  MESSAGE "An Error Occurred: " (e:GetMessage (1))
    VIEW-AS ALERT-BOX. 
END.    
  