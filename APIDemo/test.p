 

DEFINE VARIABLE sfdcSOAP AS SFDC.SFDCSOAP.

sfdcSOAP = NEW SFDC.SFDCSOAP().

sfdcSOAP:SFDCLogin().

MESSAGE sfdcSOAP:AccessToken SKIP 
  sfdcSOAP:ServerURL
  VIEW-AS ALERT-BOX.