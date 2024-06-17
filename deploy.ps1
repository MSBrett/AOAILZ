
$location = "westus"
$subscriptionId = "ID"

Set-AzContext -SubscriptionId $subscriptionId 
New-AzSubscriptionDeployment -Location $location -TemplateFile main.bicep -TemplateParameterFile main.bicepparam