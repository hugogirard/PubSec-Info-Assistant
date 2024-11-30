#!/bin/bash

# Variables
RESOURCE_GROUP="rg-spoke"
LOCATION="canadaeast"
VNET_NAME="vnet-ai-spoke"
ADDRESS_PREFIX="11.0.0.0/16"
HUB_RESOURCE_GROUP="rg-hub"

# Subnet configurations
declare -A SUBNETS
SUBNETS["snet-web"]="11.0.0.0/28"
SUBNETS["snet-web-integration"]="11.0.0.16/28"
SUBNETS["snet-service"]="11.0.0.32/28"
SUBNETS["snet-data"]="11.0.0.48/27"
SUBNETS["snet-openai"]="11.0.0.80/28"

# Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create virtual network
az network vnet create --resource-group $RESOURCE_GROUP --name $VNET_NAME --address-prefix $ADDRESS_PREFIX --location $LOCATION

# Create subnets and NSGs
for SUBNET_NAME in "${!SUBNETS[@]}"; do
  CIDR=${SUBNETS[$SUBNET_NAME]}
  NSG_NAME="nsg-${SUBNET_NAME#snet-}"

  # Create subnet
  az network vnet subnet create --resource-group $RESOURCE_GROUP --vnet-name $VNET_NAME --name $SUBNET_NAME --address-prefix $CIDR

  # Create NSG
  az network nsg create --resource-group $RESOURCE_GROUP --name $NSG_NAME --location $LOCATION

  # Associate NSG with subnet
  az network vnet subnet update --resource-group $RESOURCE_GROUP --vnet-name $VNET_NAME --name $SUBNET_NAME --network-security-group $NSG_NAME
done

# Get all private DNS zones in the hub resource group
# DNS_ZONES=$(az network private-dns zone list --resource-group $HUB_RESOURCE_GROUP --query "[].name" -o tsv)

# # Link the VNet to each private DNS zone
# for DNS_ZONE in $DNS_ZONES; do
#   az network private-dns link vnet create --resource-group $HUB_RESOURCE_GROUP --zone-name $DNS_ZONE --name "${VNET_NAME}-link" --virtual-network $VNET_NAME --registration-enabled false
# done

# echo "VNet and subnets with NSGs created successfully, and VNet linked to all private DNS zones in $HUB_RESOURCE_GROUP."