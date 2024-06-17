
[CmdletBinding()]
param (
    $SubscriptionId,
    $location,
    $name
)

if (-not $SubscriptionId) {
    $SubscriptionId = (Get-AzContext).Subscription.Id
}

$uri = 'https://management.azure.com/subscriptions/{0}/providers/Microsoft.ApiManagement/locations/{1}/deletedservices/{2}?api-version=2020-06-01-preview' -f $SubscriptionId, $location, $name, $name

Invoke-AzRestMethod -Uri $uri -Method Delete