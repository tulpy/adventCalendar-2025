# Spoke Networking - Azure Extended Zone Module

## Description

Spoke Networking - Azure Extended Zone deployment.

## Usage

Here is a basic example of how to use this Bicep module:

```bicep
module reference_name 'path_to_module | container_registry_reference' = {
  name: 'deployment_name'
  params: {
    // Required parameters
    extendedLocation:
    nsgId:
    virtualNetworkConfiguration:
    vntId:

    // Optional parameters
    location: '[resourceGroup().location]'
    tags: null
    udrId: ''
  }
}
```

> Note: In the default values, strings enclosed in square brackets (e.g. '[resourceGroup().location]' or '[__bicep.function_name(args...)']) represent function calls or references.

## Modules

| Symbolic Name | Source | Description |
| --- | --- | --- |
| networkSecurityGroup | br/public:avm/res/network/network-security-group:0.5.2 | Module: Network Security Group - https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/network/network-security-group |
| routeTable | br/public:avm/res/network/route-table:0.5.0 | Module: Route Table - https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/network/route-table |

## Resources

| Symbolic Name | Type | Description |
| --- | --- | --- |
| virtualNetwork | [Microsoft.Network/virtualNetworks](https://learn.microsoft.com/en-us/azure/templates/microsoft.network/virtualnetworks) | Resource: Virtual Network |

## Parameters

| Name | Status | Type | Description | Default |
| --- | --- | --- | --- | --- |
| extendedLocation | Required | object | Required. Extended location for the resource. |  |
| location | Optional | string | Optional. Location for all resources. | "[resourceGroup().location]" |
| nsgId | Required | string | Required. Network Security Group Id. |  |
| tags | Optional | tagsType (uddt) | Optional. Tags of the resource. | null |
| udrId | Optional | string | Optional. User Defined Route Id. | "" |
| virtualNetworkConfiguration | Required | virtualNetworkType (uddt) | Required. Configuration for Azure Virtual Network. |  |
| vntId | Required | string | Required. Virtual Network Id. |  |

## User Defined Data Types (UDDTs)

| Name | Type | Description | Properties |
| --- | --- | --- | --- |
| _1.peeringType | object | The type for peering configuration. | [View Properties](#_1.peeringtype) |
| _1.routes | object[] | The type for Route Table routes. |  |
| _1.securityRules | object[] | The type for NSG security Rules. |  |
| _1.subnetType | object[] | The type for subnets within a virtual network. |  |
| _3.lockType | object | An AVM-aligned type for a lock. | [View Properties](#_3.locktype) |
| _3.roleAssignmentType | object | An AVM-aligned type for a role assignment. | [View Properties](#_3.roleassignmenttype) |
| tagsType | object | The type for Azure Resource tags. | [View Properties](#tagstype) |
| virtualNetworkType | object | The type for Azure Virtual Network configuration. | [View Properties](#virtualnetworktype) |

### _1.peeringType

| Name | Type | Description |
| --- | --- | --- |
| allowForwardedTraffic | bool | Optional. Whether the forwarded traffic from the VMs in the local virtual network will be allowed/disallowed in remote virtual network. Default is true. |
| allowGatewayTransit | bool | Optional. If gateway links can be used in remote virtual networking to link to this virtual network. Default is false. |
| allowVirtualNetworkAccess | bool | Optional. Whether the VMs in the local virtual network space would be able to access the VMs in remote virtual network space. Default is true. |
| doNotVerifyRemoteGateways | bool | Optional. Do not verify the provisioning state of the remote gateway. Default is true. |
| name | string | Optional. The Name of VNET Peering resource. If not provided, default value will be peer-localVnetName-remoteVnetName. |
| remotePeeringAllowForwardedTraffic | bool | Optional. Whether the forwarded traffic from the VMs in the local virtual network will be allowed/disallowed in remote virtual network. Default is true. |
| remotePeeringAllowGatewayTransit | bool | Optional. If gateway links can be used in remote virtual networking to link to this virtual network. Default is false. |
| remotePeeringAllowVirtualNetworkAccess | bool | Optional. Whether the VMs in the local virtual network space would be able to access the VMs in remote virtual network space. Default is true. |
| remotePeeringDoNotVerifyRemoteGateways | bool | Optional. Do not verify the provisioning state of the remote gateway. Default is true. |
| remotePeeringEnabled | bool | Optional. Deploy the outbound and the inbound peering. |
| remotePeeringName | string | Optional. The name of the VNET Peering resource in the remove Virtual Network. If not provided, default value will be peer-remoteVnetName-localVnetName. |
| remotePeeringUseRemoteGateways | bool | Optional. If remote gateways can be used on this virtual network. If the flag is set to true, and allowGatewayTransit on remote peering is also true, virtual network will use gateways of remote virtual network for transit. Only one peering can have this flag set to true. This flag cannot be set if virtual network already has a gateway. Default is false. |
| useRemoteGateways | bool | Optional. If remote gateways can be used on this virtual network. If the flag is set to true, and allowGatewayTransit on remote peering is also true, virtual network will use gateways of remote virtual network for transit. Only one peering can have this flag set to true. This flag cannot be set if virtual network already has a gateway. Default is false. |

### _3.lockType

| Name | Type | Description |
| --- | --- | --- |
| kind | string | Optional. Specify the type of lock. |
| name | string | Optional. Specify the name of lock. |
| notes | string | Optional. Specify the notes of the lock. |

### _3.roleAssignmentType

| Name | Type | Description |
| --- | --- | --- |
| condition | string | Optional. The conditions on the role assignment. This limits the resources it can be assigned to. e.g.: @Resource[Microsoft.Storage/storageAccounts/blobServices/containers:ContainerName] StringEqualsIgnoreCase "foo_storage_container". |
| conditionVersion | string | Optional. Version of the condition. |
| delegatedManagedIdentityResourceId | string | Optional. The Resource Id of the delegated managed identity resource. |
| description | string | Optional. The description of the role assignment. |
| name | string | Optional. The name (as GUID) of the role assignment. If not provided, a GUID will be generated. |
| principalId | string | Required. The principal ID of the principal (user/group/identity) to assign the role to. |
| principalType | string | Optional. The principal type of the assigned principal ID. |
| roleDefinitionIdOrName | string | Required. The role to assign. You can provide either the display name of the role definition, the role definition GUID, or its fully qualified ID in the following format: '/providers/Microsoft.Authorization/roleDefinitions/c2f4ef07-c644-48eb-af81-4b1b4947fb11'. |

### tagsType

| Name | Type | Description |
| --- | --- | --- |
| applicationName | string |  |
| contactEmail | string |  |
| costCenter | string |  |
| criticality | string |  |
| dataClassification | string |  |
| environment | string |  |
| iac | string |  |
| owner | string |  |

### virtualNetworkType

| Name | Type | Description |
| --- | --- | --- |
| addressPrefixes | array | Required. The address prefix of the virtual network to create. |
| ddosProtectionPlanId | string | Optional. The DDoS protection plan ID to associate with the virtual network. |
| disableBgpRoutePropagation | bool | Optional. A value indicating whether this route overrides overlapping BGP routes regardless of LPM. |
| dnsServers | string[] | Optional. DNS Servers associated to the Virtual Network. |
| ipamPoolNumberOfIpAddresses | string | Optional. Number of IP addresses allocated from the pool. To be used only when the addressPrefix param is defined with a resource ID of an IPAM pool. |
| lock | _3.lockType (uddt) | Optional. The lock settings of the service. |
| name | string | Optional. The name of the virtual network resource. |
| peerings | _1.peeringType[] (uddt) | Optional. Virtual Network Peering configurations. |
| roleAssignments | _3.roleAssignmentType[] (uddt) | Optional. Array of role assignments to create. |
| subnets | _1.subnetType (uddt) | Required. The subnet type. |

## Variables

| Name | Description |
| --- | --- |
| _2.backupPolicies |  |
| _2.commonResourceGroupNames |  |
| _2.delimiter |  |
| _2.locIds |  |
| _2.resIds |  |
| _2.serviceHealthAlerts |  |
| _2.sharedNSGrulesInbound |  |
| _2.sharedNSGrulesOutbound |  |
| _2.sharedRoutes |  |
| addressPrefix |  |
| subnetMap |  |
| subnetProperties |  |
| vNetAddressSpace |  |

## Outputs

| Name | Type | Description |
| --- | --- | --- |
| networkSecurityGroup | array | An array of Network Security Groups. |
| routeTable | array | An array of Route Tables. |
| subnetNames | array | The names of the deployed subnets. |
| virtualNetworkId | string | The Virtual Network Resource Id. |
| virtualNetworkName | string | The Virtual Network Name. |
