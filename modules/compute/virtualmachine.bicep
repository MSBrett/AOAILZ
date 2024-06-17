param subnetId string
param vmName string
param vmSize string
param location string = resourceGroup().location
param adminUsername string
@secure()
param adminPassword string

param timeZoneId string = 'Pacific Standard Time'
param shutdownTime string = '20:00'
param emailRecipient string = ''

@allowed(['Standard_LRS', 'Premium_LRS'])
param vmStorageAccountType string = 'Standard_LRS'

param imageReference object = {
  publisher: 'Canonical'
  offer: '0001-com-ubuntu-server-focal'
  sku: '20_04-lts-gen2'
  version: 'latest'
}

resource nic 'Microsoft.Network/networkInterfaces@2021-02-01' = {
  name: '${vmName}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

resource virtualmachine 'Microsoft.Compute/virtualMachines@2021-03-01' = {
  name: vmName
  location: location
  properties: {
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        caching: 'ReadWrite'
        managedDisk: {
          storageAccountType: vmStorageAccountType
        }
      }
      imageReference: imageReference
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
    securityProfile: {
      securityType: 'TrustedLaunch'
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
    }
  }
}

resource autoShutdownConfig 'Microsoft.DevTestLab/schedules@2018-09-15' = {
  name: 'shutdown-computevm-${vmName}'
  location: location
  properties: {
    status: 'Enabled'
    notificationSettings: {
      status: 'Enabled'
      timeInMinutes: 30
      notificationLocale: 'en'
      emailRecipient: emailRecipient
    }
    dailyRecurrence: {
       time: shutdownTime
    }
     timeZoneId: timeZoneId
     taskType: 'ComputeVmShutdownTask'
     targetResourceId: virtualmachine.id
  }
}

