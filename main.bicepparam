using './main.bicep'

param workloadName = 'sandbox'
param location_hub = 'westus'
param location_sandbox = 'westus'
param location_ai_primary = 'westus'
param location_ai_secondary = 'eastus'

param virtualNetworkAddressPrefix = '192.168.0.0/22'
param vmSize = 'Standard_DC8_v2'
param vmStorageAccountType = 'Premium_LRS'

param adminUsername = 'sandboxadmin'
@secure()
param adminPassword = 'P@ssw0rd!@#!'
@secure()
param notificationEmail = 'joeking@microsoft.com'

param logAnalyticsWorkspaceId = '/subscriptions/ID/resourceGroups/Observability/providers/Microsoft.OperationalInsights/workspaces/fdpoworkspace'
