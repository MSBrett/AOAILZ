param zoneName string

@description('The name of the DNS record to be created.  The name is relative to the zone, not the FQDN.')
param recordName string = 'www'

@allowed([
  'A'
  'CNAME'
])
param recordType string = 'A'

param properties object = {
  TTL: 3600
  ARecords: [
    {
      ipv4Address: '1.2.3.4'
    }
    {
      ipv4Address: '1.2.3.5'
    }
  ]
}

resource zone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: zoneName
}

resource a 'Microsoft.Network/privateDnsZones/A@2020-06-01' = if (recordType == 'A') {
  parent: zone
  name: recordName
  properties: properties
}

resource cname 'Microsoft.Network/privateDnsZones/CNAME@2020-06-01' = if (recordType == 'CNAME') {
  parent: zone
  name: recordName
  properties: properties
}
