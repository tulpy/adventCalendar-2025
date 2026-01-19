@description('Array of virtual machine configurations')
param virtualMachines array = [
  {
    vmSize: 'Standard_D2s_v3'
    osType: 'Windows'
    imageReference: {
      publisher: 'MicrosoftWindowsServer'
      offer: 'WindowsServer'
      sku: '2019-Datacenter'
      version: 'latest'
    }
  }
]

@description('Location for the resources')
param location string = resourceGroup().location

@description('Tags to be applied to the resources')
param tags object = resourceGroup().tags

@description('Administrator username for the virtual machines')
param adminUsername string = 'adminuser'

@description('Required. Name of the secret in the Key Vault for the admin password')
@secure()
param adminPassword string

@description('Base name for the virtual machines')
param virtualMachineName string = 'vm'

@description('Name of the virtual network')
param virtualNetworkName string = 'vnet'

@description('Name of the subnet within the virtual network')
param subnetName string = 'subnet'

@description('Name of the resource group containing the virtual network')
param virtualNetworkResourceGroup string = 'vnet'

@description('Enable automatic updates on the virtual machines')
param enableAutomaticUpdates bool = true

// Module: Virtual Machine
module virtualMachine 'br/public:avm/res/compute/virtual-machine:0.21.0' = [
  for (vm, index) in virtualMachines: {
    name: take('virtualMachine-${index}-${guid(deployment().name)}', 64)
    params: {
      name: '${virtualMachineName}${index + 1}'
      location: location
      tags: tags
      adminUsername: adminUsername
      adminPassword: adminPassword
      availabilityZone: virtualMachines[index].?availabilityZone ?? 0
      plan: {
        publisher: virtualMachines[index].imageReference.publisher
        product: virtualMachines[index].imageReference.offer
        name: virtualMachines[index].imageReference.sku
      }
      vmSize: virtualMachines[index].vmSize
      osType: virtualMachines[index].osType
      imageReference: virtualMachines[index].imageReference
      enableAutomaticUpdates: enableAutomaticUpdates
      patchMode: (enableAutomaticUpdates) // If automatic updates are enabled, set the patch mode to AutomaticByPlatform else set it to ImageDefault for Linux VMs and AutomaticByOS for Windows VMs
        ? 'AutomaticByPlatform'
        : (virtualMachines[index].osType == 'Linux') ? 'ImageDefault' : 'AutomaticByOS' // Linux VMs use ImageDefault, Windows VMs use AutomaticByOS
      encryptionAtHost: true
      nicConfigurations: [
        {
          nicSuffix: '-nic01'
          deleteOption: 'Delete'
          enableAcceleratedNetworking: false
          ipConfigurations: [
            {
              name: 'ipconfig01'
              subnetResourceId: resourceId(
                virtualNetworkResourceGroup,
                'Microsoft.Network/virtualNetworks/subnets',
                virtualNetworkName,
                subnetName
              )
              privateIPAddressVersion: 'IPv4'
              privateIPAllocationMethod: virtualMachines[index].?privateIPAllocationMethod
              privateIPAddress: virtualMachines[index].?privateIPAddress
            }
          ]
        }
      ]
      osDisk: {
        caching: 'ReadWrite'
        createOption: 'FromImage'
        deleteOption: 'Delete'
        diskSizeGB: virtualMachines[index].storageProfile.osDisk.diskSizeGB
        managedDisk: {
          storageAccountType: virtualMachines[index].storageProfile.osDisk.managedDisk.storageAccountType
        }
      }
      dataDisks:virtualMachines[index].?dataDisks
      managedIdentities: {
        systemAssigned: true
      }
    }
  }
]
