
DEFINE VARIABLE imageNumber AS INTEGER NO-UNDO. 
DEFINE VARIABLE icol        AS INTEGER NO-UNDO. 
DEFINE VARIABLE irow        AS INTEGER NO-UNDO. 


DO imageNumber = 1 TO 9:
  
  icol = (imageNumber - 1) MOD 3.  
  iRow = (TRUNCATE ((imageNumber + 2) / 3, 0)) - 1.

  DISPLAY imageNumber  icol irow WITH FRAME a.
  DOWN WITH FRAME a. 

END.