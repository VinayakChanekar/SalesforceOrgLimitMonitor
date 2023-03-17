public class ClsMyDashOrgMonitorScheduler implements Schedulable {
    /*
        Script to Schedule this apex job 
        ClsMyDashOrgMonitorScheduler scheduledClass = new ClsMyDashOrgMonitorScheduler();
        String cronExp = '0 0 0/3 * * ? *'; //Needs to be added to custom setting
        String jobID = System.schedule('MyDashOrgMonitor', cronExp, scheduledClass);
	*/
    public void execute(SchedulableContext SC){
        try{
            ClsAforceMonitor.deleteExpiredSnapshots();
            ClsAforceMonitor.snapshotOrgLimits();
            ClsAforceMonitor.snapshotFailedApexJobs();
        }
        catch(Exception e){
            system.debug(LoggingLevel.ERROR, e.getMessage());
            system.debug(LoggingLevel.ERROR, e.getStackTraceString());
			
            throw e;
        }
    }
}