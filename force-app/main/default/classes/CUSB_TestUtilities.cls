@IsTest
public with sharing class CUSB_TestUtilities {
    public static void makeData() {
        User runAsUser = createUser();
        assignPermissionSet(runAsUser.Id);
        System.runAs(runAsUser) {
            assignLicense(runAsUser.Id);
            List<copado__Org__c> orgCreds = new List<copado__Org__c>();
            copado__Org__c devOrgCredential = new copado__Org__c(
                Name = 'Dev 1',
                copado__Org_Type__c = 'Production/Developer',
                copado__SFDC_Org_ID__c = '00D1i00000095bEEAQ_0050X000007h8hTQAQ_6'
            );
            orgCreds.add(devOrgCredential);
            copado__Org__c stagingOrgCredential = new copado__Org__c(
                Name = 'Staging',
                copado__Org_Type__c = 'Production/Developer',
                copado__SFDC_Org_ID__c = '00D1i00000095cEEAQ_0050X000007h8cTQAQ_3'
            );
            copado__Org__c prodOrgCredential = new copado__Org__c(
                Name = 'Production',
                copado__Org_Type__c = 'Production/Developer',
                copado__SFDC_Org_ID__c = '00D1i00000095dEEAQ_0050X000007h8cTQAQ_5'
            );
            orgCreds.add(stagingOrgCredential);
            insert orgCreds;
            // This update is to create Environments from OrgCredentials.
            // copado__SFDC_Org_ID__c is populated after creation. In this case, I populated the field in the very beginning so data creation code is smoother.
            update orgCreds;

            copado__Git_Repository__c gitRepo = new copado__Git_Repository__c(Name = 'My Repo');
            insert gitRepo;

            copado__Git_Backup__c gitSnapshot = new copado__Git_Backup__c(
                copado__Git_Repository__c = gitRepo.Id,
                copado__Org__c = devOrgCredential.Id
            );
            insert gitSnapshot;

            copado__Git_Org_Commit__c gitOrgCommit1 = new copado__Git_Org_Commit__c(
                copado__Git_Backup__c = gitSnapshot.Id,
                copado__Org__c = devOrgCredential.Id,
                copado__Commit_Id__c = 'b7adccf3937495e8928d1023c5a5c644198b8974',
                copado__Commit_Date__c = Date.today(),
                copado__Commit_Message__c = 'test message',
                copado__Status__c = 'Complete'
            );
            copado__Git_Org_Commit__c gitOrgCommit2 = new copado__Git_Org_Commit__c(
                copado__Git_Backup__c = gitSnapshot.Id,
                copado__Org__c = devOrgCredential.Id,
                copado__Commit_Id__c = 'b7adccf3937495e8928d1023c5a5c644198b8975',
                copado__Commit_Date__c = Date.today(),
                copado__Commit_Message__c = 'test message 2',
                copado__Status__c = 'Complete'
            );
            insert new List<copado__Git_Org_Commit__c>{ gitOrgCommit1, gitOrgCommit2 };

            copado__User_Story__c userStory1 = new copado__User_Story__c(copado__User_Story_Title__c = 'User Story 1');
            copado__User_Story__c userStory2 = new copado__User_Story__c(copado__User_Story_Title__c = 'User Story 2');
            copado__User_Story__c userStory3 = new copado__User_Story__c(copado__User_Story_Title__c = 'User Story 3');
            copado__User_Story__c userStory4 = new copado__User_Story__c(copado__User_Story_Title__c = 'User Story 4');
            copado__User_Story__c userStory5 = new copado__User_Story__c(copado__User_Story_Title__c = 'User Story 5');
            copado__User_Story__c userStory6 = new copado__User_Story__c(copado__User_Story_Title__c = 'User Story 6');
            insert new List<copado__User_Story__c>{ userStory1, userStory2, userStory3, userStory4, userStory5, userStory6 };

            copado__User_Story_Commit__c userStoryCommit1 = new copado__User_Story_Commit__c(
                copado__User_Story__c = userStory1.Id,
                copado__Snapshot_Commit__c = gitOrgCommit1.Id
            );
            copado__User_Story_Commit__c userStoryCommit2 = new copado__User_Story_Commit__c(
                copado__User_Story__c = userStory2.Id,
                copado__Snapshot_Commit__c = gitOrgCommit2.Id
            );
            insert new List<copado__User_Story_Commit__c>{ userStoryCommit1, userStoryCommit2 };

            copado__Deployment_Task__c deploymentTaskManual = new copado__Deployment_Task__c(
                copado__User_Story__c = userStory1.Id,
                copado__Task_Description__c = 'Deployment Task Description',
                copado__Type__c = 'Manual Task'
            );
            copado__Deployment_Task__c deploymentTaskApex = new copado__Deployment_Task__c(
                copado__User_Story__c = userStory2.Id,
                copado__Task_Description__c = 'Deployment Task Apex',
                copado__Type__c = 'Apex'
            );
            insert new List<copado__Deployment_Task__c>{ deploymentTaskManual, deploymentTaskApex };

            // Metadata selections via the grid
            Attachment att1 = new Attachment(
                ParentId = gitOrgCommit1.Id,
                Name = 'Metadata',
                Body = Blob.valueOf('[{"t":"EmailTemplate","n":"Template1","s":true,"r":true}, {"t":"EmailTemplate","n":"Template2","s":false}]')
            );

            Attachment att2 = new Attachment(
                ParentId = gitOrgCommit2.Id,
                Name = 'Metadata',
                Body = Blob.valueOf('[{"t":"EmailTemplate","n":"Template1","s":true,"r":false}, {"t":"EmailTemplate","n":"a_Template","s":true}]')
            );
            // Test only Attachment.
            Attachment testOnlyAttachment = new Attachment(
                ParentId = userStory1.Id,
                Name = 'Test Classes',
                Body = Blob.valueOf('[{"n":"test_class","s":true,"r":false,"ns":""}]')
            );
            // Apex Deployment Task
            Attachment testApexDeploymentTask = new Attachment(
                ParentId = deploymentTaskApex.Id,
                Name = 'Apex',
                Body = Blob.valueOf('System.debug(\'debug\')')
            );

            insert new List<Attachment>{ att1, att2, testOnlyAttachment, testApexDeploymentTask };
        }
    }

    /**
     * Run as User
     */
    public static User createUser() {
        User runAsUser = new User(
            LastName = 'UserLastName',
            Username = 'username@myemail.com',
            Email = 'username@myemail.com',
            Alias = 'MyAlias',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = UserInfo.getProfileId(),
            LanguageLocaleKey = 'en_US'
        );
        insert runAsUser;
        return runAsUser;
    }

    /**
     * Retrieve Run as User
     */
    public static User getRunAsUser() {
        List<User> runAsUsers = [SELECT Id FROM User WHERE Username = 'username@myemail.com'];
        return runAsUsers[0];
    }

    /**
     * Assign user licenses
     */
    public static void assignLicense(Id userId) {
        copado.GlobalAPI copadoGlobalAPI = new copado.GlobalAPI();
        copado.GlobalAPI.UserLicense userLicense = new copado.GlobalAPI.UserLicense();
        userLicense.isCCMEnabled = true;
        userLicense.isCopadoEnabled = true;
        userLicense.userId = userId;
        copadoGlobalAPI.upsertCopadoLicense(userLicense);
    }

    /**
     * Assign PermissionSet
     */
    public static void assignPermissionSet(Id userId) {
        PermissionSetAssignment cusb = new PermissionSetAssignment();
        cusb.PermissionSetId = [SELECT Id, Name FROM PermissionSet WHERE Name = 'Copado_User_Story_Bundle' LIMIT 1].Id;
        cusb.AssigneeId = userId;

        PermissionSetAssignment copado = new PermissionSetAssignment();
        copado.PermissionSetId = [SELECT Id, Name FROM PermissionSet WHERE Name = 'Copado_User' LIMIT 1].Id;
        copado.AssigneeId = userId;

        insert new List<PermissionSetAssignment>{cusb, copado};
    }
    
}