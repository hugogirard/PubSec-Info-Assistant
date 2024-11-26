# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.

#!/bin/bash

ENV_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

export ARM_ENVIRONMENT=public

#setting up necessary permissions to access the Docker daemon socket
sudo chmod 666 /var/run/docker.sock

#Ensure hw time sync is enabled to avoid time drift when the host OS sleeps. 
#Time sync is required else Azure authentication tokens will be invalid
source "${ENV_DIR}/time-sync.sh"

# Default values - you can override these in your environment.env
# -------------------------------------------------------------------------------------------------------
# subscription name passed in from pipeline - if not, use 'local'
if [ -z "$ENVIRONMENT_NAME" ]; then
    export ENVIRONMENT_NAME="local"
fi

echo "Environment set: $ENVIRONMENT_NAME."

if [[ -n $IN_AUTOMATION ]]; then

    if [[ -z $BUILD_BUILDID ]]; then
        echo "Require BUILD_BUILDID to be set for CI builds"
        exit 1        
    fi    
    export TF_VAR_build_number=$BUILD_BUILDNUMBER
fi

# Override in local.env if you want to disable cleaning functional test data
export DISABLE_TEST_CLEANUP=false
export IGNORE_TEST_PIPELINE_QUERY=false

export NOTEBOOK_CONFIG_OVERRIDE_FOLDER="default"

# Pull in variables dependent on the environment we are deploying to.
if [ -f "$ENV_DIR/environments/$ENVIRONMENT_NAME.env" ]; then
    echo "Loading environment variables for $ENVIRONMENT_NAME."
    source "$ENV_DIR/environments/$ENVIRONMENT_NAME.env"
fi

# Pull in variables dependent on the Language being targeted
if [ -f "$ENV_DIR/environments/languages/$DEFAULT_LANGUAGE.env" ]; then
    echo "Loading environment variables for Language: $DEFAULT_LANGUAGE."
    source "$ENV_DIR/environments/languages/$DEFAULT_LANGUAGE.env"
else
    echo "No Language set, please check local.env.example for DEFAULT_LANGUAGE"
    exit 1
fi

# Pull in variables dependent on the Azure Environment being targeted
if [ -f "$ENV_DIR/environments/AzureEnvironments/$AZURE_ENVIRONMENT.env" ]; then
    echo "Loading environment variables for Azure Environment: $AZURE_ENVIRONMENT."
    source "$ENV_DIR/environments/AzureEnvironments/$AZURE_ENVIRONMENT.env"
else
    echo -e "\n"
    echo "\e[31mNo Azure Environment set, please check local.env.example for AZURE_ENVIRONMENT\e[0m\n"
    exit 1
fi

# Fail if the following feature flag combinations are set
if [[ $ENABLE_WEB_CHAT == true ]] && [[ $AZURE_ENVIRONMENT == "AzureUSGovernment" ]]; then
    echo -e "\n"
    echo -e "\e[31mWeb Chat is not available on AzureUSGovernment deployments. Check your values for ENABLE_WEB_CHAT and AZURE_ENVIRONMENT.\e[0m\n"
    exit 1
fi

# Validate if you deploy in secure mode and bring your own vnet
# next we validate all the subnet are provided
if [[ $SECURE_MODE == true && $BRING_YOUR_OWN_VNET == true ]]; then
    if [[ -z "$VNET_NAME" ]]; then
        echo -e "\n"
        echo -e "\e[31mVNET_NAME is not set. Please provide a value for VNET_NAME when SECURE_MODE and BRING_YOUR_OWN_VNET are enabled.\e[0m\n"
        exit 1
    fi
    if [[ -z "$WEB_SUBNET_NAME" ]]; then
        echo -e "\n"
        echo -e "\e[31mWEB_SUBNET_NAME is not set. Please provide a value for WEB_SUBNET_NAME.\e[0m\n"
        exit 1
    fi
    if [[ -z "$WEB_SUBNET_INTEGRATION_NAME" ]]; then
        echo -e "\n"
        echo -e "\e[31mWEB_SUBNET_INTEGRATION_NAME is not set. Please provide a value for WEB_SUBNET_INTEGRATION_NAME.\e[0m\n"
        exit 1
    fi
    if [[ -z "$SUBNET_SERVICE_NAME" ]]; then
        echo -e "\n"
        echo -e "\e[31mSUBNET_SERVICE_NAME is not set. Please provide a value for SUBNET_SERVICE_NAME.\e[0m\n"
        exit 1
    fi
    if [[ -z "$SUBNET_DATA" ]]; then
        echo -e "\n"
        echo -e "\e[31mSUBNET_DATA is not set. Please provide a value for SUBNET_DATA.\e[0m\n"
        exit 1
    fi
    if [[ -z "$SUBNET_OPENAI" ]]; then
        echo -e "\n"
        echo -e "\e[31mSUBNET_OPENAI is not set. Please provide a value for SUBNET_OPENAI.\e[0m\n"
        exit 1
    fi
fi

if [[ $SECURE_MODE == true && $USE_EXISTING_AOAI == true ]]; then
    echo -e "\n"
    echo -e "\e[31mSecure Mode and Use Existing AOAI cannot be enabled at the same time. We do not want to alter the security of an existing AOAI instance to avoid disruption of other services dependent on the shared instance. Check your values for SECURE_MODE and USE_EXISTING_AOAI.\e[0m\n"
    exit 1
fi

#SharePoint
if [[ $SECURE_MODE == true && $ENABLE_SHAREPOINT_CONNECTOR == true ]]; then
    echo -e "\n"
    echo -e "SharePoint feature is not available in secure mode. Check your values for SECURE_MODE and ENABLE_SHAREPOINT_CONNECTOR. \e[0m\n"
    exit 1
fi

if [[ $SECURE_MODE == false && $ENABLE_DDOS_PROTECTION_PLAN == true ]]; then
    echo -e "\n"
    echo -e "DDOS protection is not available outside of secure mode. Check your values for SECURE_MODE and ENABLE_DDOS_PROTECTION_PLAN. \e[0m\n"
    exit 1
fi


# Fail if the following environment variables are not set
if [[ -z $WORKSPACE ]]; then
    echo "\e[31mWORKSPACE must be set.\e[0m\n"
    exit 1
elif [[ "${WORKSPACE}" =~ [[:upper:]] ]]; then
    echo "\e[33mPlease use a lowercase workspace environment variable between 1-15 characters. Please check 'local.env.example'\e[0m\n"
    exit 1
fi

# Set the name of the resource group
export TF_VAR_resource_group_name="infoasst-$WORKSPACE"

# The default key that is used in the remote state
export TF_BACKEND_STATE_KEY="shared.infoasst.tfstate"

# Subscription ID mandatory for Terraform AzureRM provider 4.x.x https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/4.0-upgrade-guide#specifying-subscription-id-is-now-mandatory
export ARM_SUBSCRIPTION_ID="$SUBSCRIPTION_ID"

echo -e "\n\e[32m🎯 Target Resource Group: \e[33m$TF_VAR_resource_group_name\e[0m\n"