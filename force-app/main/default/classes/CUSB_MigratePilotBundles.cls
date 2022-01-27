public with sharing class CUSB_MigratePilotBundles implements Database.Batchable<SObject>, Database.Stateful {
    private final static Id BUNDLE_RECORD_TYPE = SObjectType.copado__Artifact__c.getRecordTypeInfosByDeveloperName()
        .get('User_Story_Bundle')
        .getRecordTypeId();
    private final static Id UTILITY_RECORD_TYPE = SObjectType.copado__User_Story__c.getRecordTypeInfosByDeveloperName()
        .get('Utility')
        .getRecordTypeId();
    private String errorMessages;
    private Map<String, Id> parentsByName = new Map<String, Id>();
    private Map<String, copado__Artifact_Version__c> alreadyMigrated = new Map<String, copado__Artifact_Version__c>();

    // PUBLIC

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(
            [
                SELECT Id
                FROM copado__User_Story__c
                WHERE Bundle_User_Story__r.Is_Bundle__c = true AND Bundle_User_Story__r.copado__Status__c != 'Cancelled'
                ORDER BY Bundle_User_Story__c
            ]
        );
    }

    public void execute(Database.BatchableContext bc, List<copado__User_Story__c> scope) {
        try {
            execute(scope);
        } catch (Exception ex) {
            errorMessages += '\r\n ' + ex.getMessage();

            // Note: rethrow as we otherwise would not see error in Job Logs
            throw ex;
        }
    }

    public void finish(Database.BatchableContext bc) {
        if (String.isNotBlank(errorMessages)) {
            CUSB_EmailError.sendErrorEmail(
                'User Story Bundle Migration Error',
                errorMessages,
                'Error during USB migration process',
                UserInfo.getUserId()
            );
        }
    }

    // PRIVATE

    private void execute(List<copado__User_Story__c> children) {
        children = requery();

        Map<String, Id> parents = groupByName(children);
        parentsByName.putAll(parents);

        insertPackages(parents);
        insertBundles(parents);
        insertJunctions(children, parents);

        markAsMigrated(children, parents);
    }

    private List<copado__User_Story__c> requery() {
        return [
            SELECT Id, Bundle_User_Story__c, Bundle_User_Story__r.Name
            FROM copado__User_Story__c
            WHERE Bundle_User_Story__r.Is_Bundle__c = true AND Bundle_User_Story__r.copado__Status__c != 'Cancelled'
        ];
    }

    private Map<String, Id> groupByName(List<copado__User_Story__c> stories) {
        Map<String, Id> result = new Map<String, Id>();

        for (copado__User_Story__c story : stories) {
            String parentName = story.Bundle_User_Story__r.Name;

            if (!parentsByName.containsKey(parentName)) {
                result.put(parentName, story.Bundle_User_Story__c);
            }
        }

        return result;
    }

    private void insertPackages(Map<String, Id> parentNames) {
        List<copado__Artifact__c> result = new List<copado__Artifact__c>();

        for (String name : parentNames.keySet()) {
            result.add(new copado__Artifact__c(Name = name, RecordTypeId = BUNDLE_RECORD_TYPE));
        }

        insert result;
    }

    private void insertBundles(Map<String, Id> parentNames) {
        List<copado__Artifact_Version__c> result = new List<copado__Artifact_Version__c>();

        for (copado__Artifact__c pkg : [SELECT Id, Name FROM copado__Artifact__c WHERE Name IN :parentNames.keySet()]) {
            // Note: Parent Name = Bundle Name = Package Name
            String key = pkg.Name;
            if (parentNames.containsKey(key)) {
                result.add(
                    new copado__Artifact_Version__c(
                        Name = pkg.Name,
                        copado__Artifact__c = pkg.Id,
                        copado__User_Story__c = parentNames.get(key),
                        copado__Status__c = 'Locked'
                    )
                );
            }
        }

        insert result;

        // Note: Remember as already migrated for susequent batch jobs
        groupAlreadyMigrated(parentNames);
    }

    private void groupAlreadyMigrated(Map<String, Id> parentNames) {
        for (copado__Artifact_Version__c bundle : [SELECT Id, Name FROM copado__Artifact_Version__c WHERE Name IN :parentNames.keySet()]) {
            alreadyMigrated.put(bundle.Name, bundle);
        }
    }

    private void insertJunctions(List<copado__User_Story__c> stories, Map<String, Id> parentNames) {
        List<copado__Bundled_Story__c> result = new List<copado__Bundled_Story__c>();

        for (copado__User_Story__c story : stories) {
            String bundleName = story.Bundle_User_Story__r.Name;

            if (alreadyMigrated.containsKey(bundleName)) {
                result.add(
                    new copado__Bundled_Story__c(copado__Package_Version__c = alreadyMigrated.get(bundleName).Id, copado__User_Story__c = story.Id)
                );
            }
        }

        insert result;
    }

    private void markAsMigrated(List<copado__User_Story__c> children, Map<String, Id> parentNames) {
        List<copado__User_Story__c> parents = [
            SELECT Id, Is_Bundle__c, copado__Is_Bundle__c, RecordTypeId, Bundle_User_Story__c
            FROM copado__User_Story__c
            WHERE Id = :parentNames.values()
        ];
        for (copado__User_Story__c parent : parents) {
            parent.Is_Bundle__c = false;
            parent.copado__Is_Bundle__c = true;
            parent.RecordTypeId = UTILITY_RECORD_TYPE;
            parent.Bundle_User_Story__c = null;
        }

        update parents;

        for (copado__User_Story__c child : children) {
            child.Bundle_User_Story__c = null;
        }

        update children;
    }
}