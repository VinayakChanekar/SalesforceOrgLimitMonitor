/***************************************************************************************************************************
*   Name        : ClsAforceMonitor 
*   Date        : 06 March 2023
*   Author      : Vinayak Chanekar 
*   Description : This class contains methods for Org health and limit monitoring as a part of DASHQUOTE-393

Modification Log : 
--------------------------------------------------------------------------------
* Developer               Date                  Description
* -------------------     ------------          -----------------------
* Vinayak Chanekar        06/03/2023            Added methods snapshotOrgLimits, deleteExpiredSnapshots, snapshotFailedApexJobs   
**************************************************************************************************************************/
public class ClsAforceMonitor {
    //public static Integer BUFFER_TIME_MINUTES = 5; //to be added to custom setting
    public static final Integer MONITOR_PERIOD_HOURS_FAILED_APEX = 3; //to be added to custom setting
    public static final String SNAPSHOT_RECORDTYPE_DEVNAME_APEX_JOB = 'Apex_Job_Snapshot';
    public static final String SNAPSHOT_RECORDTYPE_DEVNAME_ORG_LIMIT = 'Org_Limit_Snapshot';
    //Adding script to populate data into OrgLimitType object - to be added as post deployment step
    private static void dataSetup(){
        List<OrgLimitType__c> lstOrgLimitTypes = new List<OrgLimitType__c>(); 
        Set<String> existingOrgLimits = new Set<string>();
        for(OrgLimitType__c orgLimitType : [SELECT Id, OrgLimitName__c FROM OrgLimitType__c 
                                            LIMIT 100])
        {
            existingOrgLimits.add(orgLimitType.OrgLimitName__c);            
        }
        Map<String,System.OrgLimit> limitsMap = OrgLimits.getMap();
        for(String orgLimitName : limitsMap.keySet()){
            if(!existingOrgLimits.contains(orgLimitName)){
                OrgLimitType__c oLT = new OrgLimitType__c(OrgLimitName__c = orgLimitName);
                lstOrgLimitTypes.add(oLT);
            }
            
        }
        if(!lstOrgLimitTypes.isEmpty()){
            insert lstOrgLimitTypes;
        }
    }
    
    //Method to take Snapshot of Org Limits based on Active Org Limit Monitoring and Retreival Frequency.
    public static void snapshotOrgLimits(){
        List<Snapshot__c> lstSnapshots = new List<Snapshot__c>();
        List<OrgLimitType__c> updateOrgLimitType = new List<OrgLimitType__c>();
        Map<String,System.OrgLimit> limitsMap = OrgLimits.getMap();
        for(OrgLimitType__c orgLimitType : [SELECT Id, OrgLimitName__c, RetrievalFrequency__c, LastRetrievalDate__c FROM OrgLimitType__c 
                                            WHERE IsActive__c = true 
                                            LIMIT 100])
        {
            
            //To check if lastRetrivalData + Retrieval Frequency is less than current time with a buffer of 5 minutes.
            if(orgLimitType.LastRetrievalDate__c == null || 
               (orgLimitType.LastRetrievalDate__c != null && 
                orgLimitType.RetrievalFrequency__c != null &&
                (DateTime.Now() >= orgLimitType.LastRetrievalDate__c.addHours(Integer.valueOf(orgLimitType.RetrievalFrequency__c)))
               )
              ){
                  System.OrgLimit currentOrgLimit = limitsMap.get(orgLimitType.OrgLimitName__c);
                  Snapshot__c ss = new Snapshot__c();
                  ss.RecordTypeId = Schema.SObjectType.Snapshot__c.getRecordTypeInfosByDeveloperName().get(SNAPSHOT_RECORDTYPE_DEVNAME_ORG_LIMIT).getRecordTypeId();
                  ss.OrgLimitType__c = orgLimitType.Id;
                  ss.Usage__c = currentOrgLimit.getValue();
                  ss.MaxLimit__c = currentOrgLimit.getLimit();
                  lstSnapshots.add(ss);
                  
                  orgLimitType.LastRetrievalDate__c = System.Now();
                  updateOrgLimitType.add(orgLimitType);
              } 
        }
        if(!lstSnapshots.isEmpty()){
            insert lstSnapshots;
        }
        if(!updateOrgLimitType.isEmpty()){
            update updateOrgLimitType;
        }
    }
    
    public static void deleteExpiredSnapshots(){
        List<Snapshot__c> lstDeleteSnapshots = new List<Snapshot__c>();
        lstDeleteSnapshots = [SELECT Id from Snapshot__c WHERE IsExpired__c = true LIMIT 10000];
        if (!lstDeleteSnapshots.isEmpty()){
            Delete lstDeleteSnapshots;
        }
    }
    
    /* Method to log failed apex jobs */
    public static void snapshotFailedApexJobs(){
        List<Snapshot__c> lstFailedApexJobs = new List<Snapshot__c>();
        Datetime monitorDt = Datetime.now().addHours(-1 * MONITOR_PERIOD_HOURS_FAILED_APEX);
        for(AsyncApexJob failedJob : [SELECT id,ApexClass.Name,ExtendedStatus, Status 
                                      FROM AsyncApexJob where CreatedDate > :MonitorDt
                                      AND ExtendedStatus LIKE '%failed%'
                                      LIMIT 10000 ])
        {
            Snapshot__c ss = new Snapshot__c();
            ss.RecordTypeId = Schema.SObjectType.Snapshot__c.getRecordTypeInfosByDeveloperName().get(SNAPSHOT_RECORDTYPE_DEVNAME_APEX_JOB).getRecordTypeId();
            ss.AsyncApexJobId__c = failedJob.Id;
            ss.ApexJobName__c = failedJob.ApexClass.Name;
            ss.Description__c = failedJob.ExtendedStatus;
            lstFailedApexJobs.add(ss);
        }
        if(!lstFailedApexJobs.isEmpty()){
            insert lstFailedApexJobs;
        }
    }
}