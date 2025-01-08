# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.

#!/bin/bash


# Variables
resourceGroup="rg-spoke"
vnetName="vnet-ai-spoke"
vnetAddressPrefix="10.1.0.0/16"
subnet1Name="snet-web"
subnet1AddressPrefix="10.1.0.0/27"
subnet2Name="snet-web-integration"
subnet2AddressPrefix="10.1.0.32/27"
subnet3Name="snet-service"
subnet3AddressPrefix="10.1.0.64/27"
subnet4Name="snet-data"
subnet4AddressPrefix="10.1.0.96/27"
subnet5Name="snet-openai"
subnet5AddressPrefix="10.1.0.128/27"

# Create resource group
#az group create --name $resourceGroup --location eastus

# Create virtual network
az network vnet create --name $vnetName --resource-group $resourceGroup --address-prefix $vnetAddressPrefix

# Create subnets
az network vnet subnet create --name $subnet1Name --resource-group $resourceGroup --vnet-name $vnetName --address-prefix $subnet1AddressPrefix --service-endpoints Microsoft.KeyVault Microsoft.Storage
az network vnet subnet create --name $subnet2Name --resource-group $resourceGroup --vnet-name $vnetName --address-prefix $subnet2AddressPrefix --delegations Microsoft.Web/serverFarms --service-endpoints Microsoft.Storage Microsoft.KeyVault
az network vnet subnet create --name $subnet3Name --resource-group $resourceGroup --vnet-name $vnetName --address-prefix $subnet3AddressPrefix --service-endpoints Microsoft.KeyVault
az network vnet subnet create --name $subnet4Name --resource-group $resourceGroup --vnet-name $vnetName --address-prefix $subnet4AddressPrefix
az network vnet subnet create --name $subnet5Name --resource-group $resourceGroup --vnet-name $vnetName --address-prefix $subnet5AddressPrefix --service-endpoints Microsoft.CognitiveServices

# Create NSGs
az network nsg create --resource-group $resourceGroup --name NSG-$subnet1Name
az network nsg create --resource-group $resourceGroup --name NSG-$subnet2Name
az network nsg create --resource-group $resourceGroup --name NSG-$subnet3Name
az network nsg create --resource-group $resourceGroup --name NSG-$subnet4Name
az network nsg create --resource-group $resourceGroup --name NSG-$subnet5Name

# Associate NSGs with subnets
az network vnet subnet update --name $subnet1Name --resource-group $resourceGroup --vnet-name $vnetName --network-security-group NSG-$subnet1Name
az network vnet subnet update --name $subnet2Name --resource-group $resourceGroup --vnet-name $vnetName --network-security-group NSG-$subnet2Name
az network vnet subnet update --name $subnet3Name --resource-group $resourceGroup --vnet-name $vnetName --network-security-group NSG-$subnet3Name
az network vnet subnet update --name $subnet4Name --resource-group $resourceGroup --vnet-name $vnetName --network-security-group NSG-$subnet4Name
az network vnet subnet update --name $subnet5Name --resource-group $resourceGroup --vnet-name $vnetName --network-security-group NSG-$subnet5Name

# List all private DNS zones in the resource group rg-hub
dnsZones=$(az network private-dns zone list --resource-group rg-hub --query "[].name" --output tsv)

# Loop through each DNS zone and create a link to the virtual network
for dnsZone in $dnsZones; do
  az network private-dns link vnet create \
    --resource-group rg-hub \
    --zone-name $dnsZone \
    --name LinkToVnetAiSpoke \
    --virtual-network /subscriptions/6e37307e-394c-478a-8404-4e441b3dfc1d/resourceGroups/rg-spoke/providers/Microsoft.Network/virtualNetworks/vnet-ai-spoke \
    --registration-enabled false
done
