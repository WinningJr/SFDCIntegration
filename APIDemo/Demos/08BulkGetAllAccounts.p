/* 
  Single batch example (retrieves one giant set of data)
*/

{i/sfdctt.i}

DEFINE VARIABLE sfdcBULK    AS SFDC.SFDCBULK NO-UNDO.
DEFINE VARIABLE htt         AS HANDLE        NO-UNDO. 
DEFINE VARIABLE jobId       AS CHARACTER     NO-UNDO. 
DEFINE VARIABLE batchId     AS CHARACTER     NO-UNDO. 
DEFINE VARIABLE i           AS INTEGER       NO-UNDO. 
DEFINE VARIABLE batchStatus AS CHARACTER     NO-UNDO. 
DEFINE VARIABLE jobState    AS CHARACTER     NO-UNDO. 

ETIME (TRUE).
OUTPUT TO "Logs/bulk.txt".
htt = TEMP-TABLE ttCustomer:HANDLE. 

sfdcBULK = NEW SFDC.SFDCBULK().
sfdcBULK:contentType = "XML".

jobId = sfdcBULK:CreateJob("query", "Account"). 
batchId = sfdcBULK:CreateBatch(htt, jobId).

pollLoopPollLoop:
REPEAT
  ON ERROR UNDO, THROW:
      
  batchStatus = sfdcBULK:CheckBatchStatus(jobId, batchId). 
  
  IF batchStatus = "failed" OR batchStatus = "InvalidBatch" THEN  
  DO:
    MESSAGE  "Site Batch Status = " + batchStatus
      VIEW-AS ALERT-BOX.
    RETURN.
  END.
  
  IF batchStatus = "Completed" THEN 
    LEAVE pollLoopPollLoop.

  PUT UNFORMATTED NOW " Batch not finished." SKIP.   
  System.Threading.Thread:Sleep(500).
END. /* pollLoop */

PUT UNFORMATTED NOW " Site Batch completed - " STRING (INTEGER (ETIME / 1000), "HH:MM:SS") SKIP.
sfdcBULK:retrieveBatchToTT (htt,jobId,batchId).

PUT UNFORMATTED NOW " Site batch loaded into TT - " STRING (INTEGER (ETIME / 1000), "HH:MM:SS") SKIP. 
jobState = sfdcBULK:CloseJob(jobId).

FOR EACH ttCustomer:
  i = i + 1.
  DISPLAY ttCustomer.id ttcustomer.custName  FORMAT "x(44)".
END.

OUTPUT CLOSE. 

MESSAGE 
  "Records: " i 
  VIEW-AS ALERT-BOX.

CATCH e AS Progress.Lang.Error:
  MESSAGE "An Error Occurred: " e:GetMessage (1) SKIP 
    VIEW-AS ALERT-BOX. 
END.    
  