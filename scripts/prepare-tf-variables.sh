# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.

#!/bin/bash

ENV_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# To maintain backward compatibility, we need to convert some of the variables to TF_VAR_ format
export TF_VAR_environmentName=$WORKSPACE
export TF_VAR_location=$LOCATION
export TF_VAR_useExistingAOAIService=$USE_EXISTING_AOAI
export TF_VAR_azureOpenAIResourceGroup=$AZURE_OPENAI_RESOURCE_GROUP
export TF_VAR_azureOpenAIServiceName=$AZURE_OPENAI_SERVICE_NAME
export TF_VAR_chatGptDeploymentName=$AZURE_OPENAI_CHATGPT_DEPLOYMENT
export TF_VAR_chatGptModelName=$AZURE_OPENAI_CHATGPT_MODEL_NAME
export TF_VAR_chatGptModelVersion=$AZURE_OPENAI_CHATGPT_MODEL_VERSION
export TF_VAR_chatGptDeploymentCapacity=$AZURE_OPENAI_CHATGPT_MODEL_CAPACITY
export TF_VAR_embeddingsDeploymentCapacity=$AZURE_OPENAI_EMBEDDINGS_MODEL_CAPACITY
export TF_VAR_azureOpenAIEmbeddingDeploymentName=$AZURE_OPENAI_EMBEDDING_DEPLOYMENT_NAME
export TF_VAR_useAzureOpenAIEmbeddings=$USE_AZURE_OPENAI_EMBEDDINGS
export TF_VAR_azureOpenAIEmbeddingsModelName=$AZURE_OPENAI_EMBEDDINGS_MODEL_NAME
export TF_VAR_azureOpenAIEmbeddingsModelVersion=$AZURE_OPENAI_EMBEDDINGS_MODEL_VERSION
export TF_VAR_sentenceTransformersModelName=$OPEN_SOURCE_EMBEDDING_MODEL
export TF_VAR_sentenceTransformerEmbeddingVectorSize=$OPEN_SOURCE_EMBEDDING_MODEL_VECTOR_SIZE
export TF_VAR_requireWebsiteSecurityMembership=$REQUIRE_WEBSITE_SECURITY_MEMBERSHIP
export TF_VAR_queryTermLanguage=$PROMPT_QUERYTERM_LANGUAGE
export TF_VAR_targetTranslationLanguage=$TARGET_TRANSLATION_LANGUAGE
export TF_VAR_applicationtitle=$APPLICATION_TITLE
export TF_VAR_chatWarningBannerText=$CHAT_WARNING_BANNER_TEXT
export TF_VAR_cuaEnabled=$ENABLE_CUSTOMER_USAGE_ATTRIBUTION
export TF_VAR_cuaId=$CUSTOMER_USAGE_ATTRIBUTION_ID
export TF_VAR_enableDevCode=$ENABLE_DEV_CODE
export TF_VAR_video_indexer_api_version=$VIDEO_INDEXER_API_VERSION
export TF_VAR_enableBingSafeSearch=$ENABLE_BING_SAFE_SEARCH
export TF_VAR_azure_environment=$AZURE_ENVIRONMENT
export TF_VAR_is_secure_mode=$SECURE_MODE
export TF_VAR_enableWebChat=$ENABLE_WEB_CHAT
export TF_VAR_enableUngroundedChat=$ENABLE_UNGROUNDED_CHAT
export TF_VAR_enableMathAssitant=$ENABLE_MATH_ASSISTANT
export TF_VAR_enableTabularDataAssistant=$ENABLE_TABULAR_DATA_ASSISTANT
export TF_VAR_enableSharePointConnector=$ENABLE_SHAREPOINT_CONNECTOR
export TF_VAR_maxCsvFileSize=$MAX_CSV_FILE_SIZE
export TF_VAR_serviceManagementReference=$SERVICE_MANAGEMENT_REFERENCE
export TF_VAR_password_lifetime=$PASSWORD_LIFETIME
export TF_VAR_enabledDDOSProtectionPlan=$ENABLE_DDOS_PROTECTION_PLAN
if [[ -n $AZURE_OPENAI_CHATGPT_SKU ]]; then
    export TF_VAR_chatGptModelSkuName=$AZURE_OPENAI_CHATGPT_SKU
fi
if [[ -n $AZURE_OPENAI_EMBEDDINGS_SKU ]]; then
    export TF_VAR_azureOpenAIEmbeddingsModelSku=$AZURE_OPENAI_EMBEDDINGS_SKU
fi

# Add section for bring your own vnet
export TF_VAR_openai_region=$OPENAI_REGION
export TF_VAR_bring_your_own_vnet=$BRING_YOUR_OWN_VNET
export TF_VAR_vnet_name=$VNET_NAME
export TF_VAR_web_subnet_name=$WEB_SUBNET_NAME
export TF_VAR_web_subnet_integration_name=$WEB_SUBNET_INTEGRATION_NAME
export TF_VAR_subnet_service_name=$SUBNET_SERVICE_NAME
export TF_VAR_subnet_data=$SUBNET_DATA
export TF_VAR_subnet_openai=$SUBNET_OPENAI
export TF_VAR_dns_subnet_name=$DNS_SUBNET_NAME

# If we bring our own spoke vnet, we need to set the resource group
if [[ -n $BRING_YOUR_OWN_VNET ]]; then
    export TF_VAR_resourceGroupName=$SPOKE_RESOURCE_GROUP_NAME
    export TF_VAR_createPrivateDnsZone=$CREATE_PRIVATE_DNS_ZONE
    export TF_VAR_privateDnsZoneResourceIdBlob=$PRIVATE_ZONE_BLOB_RESOURCE_ID
    export TF_VAR_privateDnsZoneNameBlob=$PRIVATE_ZONE_BLOB_NAME
    export TF_VAR_nsgSubnetLoggingName=$NSG_SUBNET_LOGGING_NAME
    export TF_VAR_nsgSubnetLoggingId=$NSG_SUBNET_LOGGING_ID    
    export TF_VAR_resources_resource_group_name=$RESOURCES_RESOURCE_GROUP_NAME
fi
