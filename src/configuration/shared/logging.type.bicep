// Logging User Defined Types for Azure Services https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/user-defined-data-types
import {
  lockType
  roleAssignmentType
} from 'br/public:avm/utl/types/avm-common-types:0.6.1' // Common Types including Locks, Managed Identities, Role Assignments, etc.

///////////////////////////////////////////////

// 1.0 Logging Types
// 1.1 Log Analytics Workspace Type

///////////////////////////////////////////////

// 1.0 Logging Types
// 1.1 Log Analytics Workspace Type
import {
  storageInsightsConfigType
  linkedServiceType
  linkedStorageAccountType
  savedSearchType
  dataExportType
  dataSourceType
  tableType
  gallerySolutionType
  workspaceFeaturesType
  workspaceReplicationType
} from 'br/public:avm/res/operational-insights/workspace:0.14.2'
@export()
@description('The type for Log Analytics configuration.')
type logAnalyticsType = {
  @minLength(4)
  @maxLength(63)
  @description('Optional. The name of the Log Analytics workspace.')
  name: string?

  @description('Optional. The name of the SKU.')
  skuName: (
    | 'CapacityReservation'
    | 'Free'
    | 'LACluster'
    | 'PerGB2018'
    | 'PerNode'
    | 'Premium'
    | 'Standalone'
    | 'Standard')?

  @minValue(100)
  @maxValue(5000)
  @description('Optional. The capacity reservation level in GB for this workspace, when CapacityReservation sku is selected. Must be in increments of 100 between 100 and 5000.')
  skuCapacityReservationLevel: int?

  @description('Optional. List of storage accounts to be read by the workspace.')
  storageInsightsConfigs: storageInsightsConfigType[]?

  @description('Optional. List of services to be linked.')
  linkedServices: linkedServiceType[]?

  @description('Conditional. List of Storage Accounts to be linked. Required if \'forceCmkForQuery\' is set to \'true\' and \'savedSearches\' is not empty.')
  linkedStorageAccounts: linkedStorageAccountType[]?

  @description('Optional. Kusto Query Language searches to save.')
  savedSearches: savedSearchType[]?

  @description('Optional. LAW data export instances to be deployed.')
  dataExports: dataExportType[]?

  @description('Optional. LAW data sources to configure.')
  dataSources: dataSourceType[]?

  @description('Optional. LAW custom tables to be deployed.')
  tables: tableType[]?

  @description('Optional. List of gallerySolutions to be created in the log analytics workspace.')
  gallerySolutions: gallerySolutionType[]?

  @description('Optional. Onboard the Log Analytics Workspace to Sentinel. Requires \'SecurityInsights\' solution to be in gallerySolutions.')
  onboardWorkspaceToSentinel: bool?

  @description('Optional. Number of days data will be retained for.')
  @minValue(0)
  @maxValue(730)
  dataRetention: int?

  @description('Optional. The workspace daily quota for ingestion.')
  @minValue(-1)
  dailyQuotaGb: int?

  @description('Optional. The network access type for accessing Log Analytics ingestion.')
  publicNetworkAccessForIngestion: ('Enabled' | 'Disabled')?

  @description('Optional. The network access type for accessing Log Analytics query.')
  publicNetworkAccessForQuery: ('Enabled' | 'Disabled')?

  @description('Optional. The workspace features.')
  features: workspaceFeaturesType?

  @description('Optional. The workspace replication properties.')
  replication: workspaceReplicationType?

  @description('Optional. Indicates whether customer managed storage is mandatory for query management.')
  forceCmkForQuery: bool?

  @description('Optional. Tags of the resource.')
  tags: resourceInput<'Microsoft.OperationalInsights/workspaces@2025-02-01'>.tags?

  @description('Optional. The lock settings of the service.')
  lock: lockType?

  @description('Optional. Array of role assignments to create.')
  roleAssignments: roleAssignmentType[]?
}

