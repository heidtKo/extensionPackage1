@IsTest
private class CUSB_MigratePilotBundlesTest {
    @TestSetup
    private static void makeData() {
        CUSB_TestUtilities.makeData();
        createData();
    }

    @IsTest
    private static void testMigrationProcess() {
        User runAsUser = CUSB_TestUtilities.getRunAsUser();
        System.runAs(runAsUser) {
            CUSB_TestUtilities.assignLicense(runAsUser.Id);

            // Exercise
            Test.startTest();

            CUSB_MigratePilotBundles migrate = new CUSB_MigratePilotBundles();
            Database.executeBatch(migrate);

            Test.stopTest();

            // Verify
            List<copado__User_Story__c> oldStories = [SELECT Id FROM copado__User_Story__c WHERE Is_Bundle__c = true];
            System.assertEquals(0, oldStories.size(), 'Stories with old Is_Bundle__c field filled should be 0');

            List<copado__User_Story__c> newBundles = [SELECT Id, Name FROM copado__User_Story__c WHERE copado__Is_Bundle__c = true];
            System.assertEquals(1, newBundles.size(), 'Stories with copado__Is_Bundle__c field filled should be 1');

            String bundleStory = newBundles[0].Name;

            List<copado__User_Story__c> childrenStories = [SELECT Id FROM copado__User_Story__c WHERE Bundle_User_Story__c != ''];
            System.assertEquals(0, childrenStories.size(), 'Stories with Bundle_User_Story__c field filled should be 0');

            List<copado__Artifact__c> parentBundle = [SELECT Id, Name, RecordTypeId FROM copado__Artifact__c WHERE Name = :bundleStory];
            System.assertEquals(bundleStory, parentBundle[0].Name, 'Record names does not match');
            System.assertEquals(
                SObjectType.copado__Artifact__c.getRecordTypeInfosByDeveloperName().get('User_Story_Bundle').getRecordTypeId(),
                parentBundle[0].RecordTypeId,
                'RecordType is not correct'
            );

            List<copado__Artifact_Version__c> bundle = [
                SELECT Id, Name, copado__Status__c, copado__User_Story__r.Name
                FROM copado__Artifact_Version__c
                WHERE Name = :bundleStory
            ];
            System.assertEquals(bundleStory, bundle[0].Name, 'Record names does not match');
            System.assertEquals('Locked', bundle[0].copado__Status__c, 'Status value is not correct');
            System.assertEquals(bundleStory, bundle[0].copado__User_Story__r.Name, 'User Story value is not correct');

            List<copado__Bundled_Story__c> junctions = [
                SELECT Id, copado__Package_Version__c, copado__User_Story__r.Name
                FROM copado__Bundled_Story__c
                WHERE copado__Package_Version__c = :bundle[0].Id
            ];

            System.assertEquals(bundle[0].Id, junctions[0].copado__Package_Version__c, 'Package version value is not correct');
            System.assertEquals(bundleStory, junctions[0].copado__User_Story__r.Name, 'User Story value is not correct');
        }
    }

    private static void createData() {
        User runAsUser = CUSB_TestUtilities.getRunAsUser();
        System.runAs(runAsUser) {
            CUSB_TestUtilities.assignLicense(runAsUser.Id);
            copado__Org__c stagingCredential = [SELECT Id, Name FROM copado__Org__c WHERE Name = 'Staging'];
            List<copado__User_Story__c> selectedUserStories = [
                SELECT
                    Id,
                    Name,
                    copado__Stop_Indexing_Metadata__c,
                    copado__Exclude_From_CBM__c,
                    Bundle_User_Story__c,
                    copado__Org_Credential__c,
                    copado__Environment__c
                FROM copado__User_Story__c
                WHERE copado__User_Story_Title__c IN ('User Story 1', 'User Story 2')
            ];

            ApexPages.StandardSetController bundleUserStoryStandardSetController = new ApexPages.StandardSetController(selectedUserStories);
            bundleUserStoryStandardSetController.setSelected(selectedUserStories);
            CUSB_UserStoryBundleController bundleController = new CUSB_UserStoryBundleController(bundleUserStoryStandardSetController);
            bundleController.getAllMetadata();

            bundleController.bundleUs.copado__User_Story_Title__c = 'Bundled User Story';
            bundleController.bundleUs.copado__Org_Credential__c = stagingCredential.Id;

            bundleController.assign();
        }
    }
}