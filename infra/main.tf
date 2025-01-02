locals {
  tags        = { ProjectName = "Information Assistant", BuildNumber = var.buildNumber }
  azure_roles = jsondecode(file("${path.module}/azure_roles.json"))
  selected_roles = ["CognitiveServicesOpenAIUser",
    "CognitiveServicesUser",
    "StorageBlobDataOwner",
    "StorageQueueDataContributor",
  "SearchIndexDataContributor"]
}

data "azurerm_client_config" "current" {}

resource "random_string" "random" {
  length  = 5
  special = false
  upper   = false
  number  = false
}

module "entraObjects" {
  source                           = "./core/aad"
  isInAutomation                   = var.isInAutomation
  requireWebsiteSecurityMembership = var.requireWebsiteSecurityMembership
  randomString                     = random_string.random.result
  azure_websites_domain            = var.azure_websites_domain
  aadWebClientId                   = var.aadWebClientId
  aadMgmtClientId                  = var.aadMgmtClientId
  aadMgmtServicePrincipalId        = var.aadMgmtServicePrincipalId
  aadMgmtClientSecret              = var.aadMgmtClientSecret
  entraOwners                      = var.entraOwners
  serviceManagementReference       = var.serviceManagementReference
  password_lifetime                = var.password_lifetime
}

// Get existing VNET information
data "azurerm_virtual_network" "existing_vnet" {
  name                = var.vnet_name
  resource_group_name = var.resourceGroupName
}

data "azurerm_subnet" "service_subnet" {
  name                 = var.dns_subnet_name
  virtual_network_name = data.azurerm_virtual_network.existing_vnet.name
  resource_group_name  = var.resourceGroupName
}

module "dnsResolver" {
  source                 = "./core/network/privateDNSResolver"
  privateDNSResolverName = "infoasst-dns-${random_string.random.result}"
  location               = var.location
  resourceGroupName      = var.resources_resource_group_name
  vnetId                 = data.azurerm_virtual_network.existing_vnet.id
  subnetId               = data.azurerm_subnet.service_subnet.id
}

module "logging" {
  source                       = "./core/logging/loganalytics"
  logAnalyticsName             = var.logAnalyticsName != "" ? var.logAnalyticsName : "infoasst-la-${random_string.random.result}"
  applicationInsightsName      = var.applicationInsightsName != "" ? var.applicationInsightsName : "infoasst-ai-${random_string.random.result}"
  location                     = var.location
  tags                         = local.tags
  skuName                      = "PerGB2018"
  resourceGroupName            = var.resources_resource_group_name
  resourceGroupVNET            = var.resourceGroupName
  is_secure_mode               = true
  privateLinkScopeName         = "infoasst-ampls-${random_string.random.result}"
  privateDnsZoneNameMonitor    = null
  privateDnsZoneNameOms        = null
  privateDnSZoneNameOds        = null
  privateDnsZoneNameAutomation = null
  # privateDnsZoneNameMonitor    = "privatelink.${var.azure_monitor_domain}"
  # privateDnsZoneNameOms        = "privatelink.${var.azure_monitor_oms_domain}"
  # privateDnSZoneNameOds        = "privatelink.${var.azure_monitor_ods_domain}"
  # privateDnsZoneNameAutomation = "privatelink.${var.azure_automation_domain}"
  privateDnsZoneResourceIdBlob = null
  privateDnsZoneNameBlob       = null
  groupId                      = "azuremonitor"
  ampls_subnet_CIDR            = null
  subnet_name                  = var.subnet_service_name
  vnet_name                    = var.vnet_name
  vnet_id                      = data.azurerm_virtual_network.existing_vnet.id
  nsg_id                       = null
  nsg_name                     = null
}


data "azurerm_subnet" "integration_subnet" {
  name                 = var.web_subnet_integration_name
  virtual_network_name = data.azurerm_virtual_network.existing_vnet.name
  resource_group_name  = var.resourceGroupName
}

data "azurerm_subnet" "web_subnet" {
  name                 = var.web_subnet_name
  virtual_network_name = data.azurerm_virtual_network.existing_vnet.name
  resource_group_name  = var.resourceGroupName
}

module "storage" {
  source                       = "./core/storage"
  name                         = var.storageAccountName != "" ? var.storageAccountName : "infoasststore${random_string.random.result}"
  location                     = var.location
  tags                         = local.tags
  accessTier                   = "Hot"
  allowBlobPublicAccess        = false
  resourceGroupName            = var.resources_resource_group_name
  resourceGroupVNET            = var.resourceGroupName
  arm_template_schema_mgmt_api = var.arm_template_schema_mgmt_api
  key_vault_name               = module.kvModule.keyVaultName
  deleteRetentionPolicy = {
    days = 7
  }
  containers                      = ["content", "website", "upload", "function", "logs", "config"]
  queueNames                      = ["pdf-submit-queue", "pdf-polling-queue", "non-pdf-submit-queue", "media-submit-queue", "text-enrichment-queue", "image-enrichment-queue", "embeddings-queue"]
  is_secure_mode                  = true
  subnet_name                     = var.subnet_data
  vnet_name                       = var.vnet_name
  private_dns_zone_ids            = null
  network_rules_allowed_subnets   = [data.azurerm_subnet.integration_subnet.id, data.azurerm_subnet.web_subnet.id]
  kv_secret_expiration            = var.kv_secret_expiration
  logAnalyticsWorkspaceResourceId = module.logging.logAnalyticsId
}

data "azurerm_subnet" "kv_subnet" {
  name                 = var.subnet_service_name
  virtual_network_name = data.azurerm_virtual_network.existing_vnet.name
  resource_group_name  = var.resourceGroupName
}

module "kvModule" {
  source               = "./core/security/keyvault"
  name                 = "infoasst-kv-${random_string.random.result}"
  location             = var.location
  kvAccessObjectId     = data.azurerm_client_config.current.object_id
  resourceGroupName    = var.resources_resource_group_name
  resourceGroupVNET    = var.resourceGroupName
  tags                 = local.tags
  is_secure_mode       = true
  subnet_name          = data.azurerm_subnet.kv_subnet.name
  vnet_name            = data.azurerm_virtual_network.existing_vnet.name
  subnet_id            = data.azurerm_subnet.kv_subnet.id
  private_dns_zone_ids = null
  # private_dns_zone_ids         = var.is_secure_mode ? [module.privateDnsZoneApp[0].privateDnsZoneResourceId] : null
  azure_keyvault_domain        = var.azure_keyvault_domain
  arm_template_schema_mgmt_api = var.arm_template_schema_mgmt_api
}

module "enrichmentApp" {
  source    = "./core/host/enrichmentapp"
  name      = var.enrichmentServiceName != "" ? var.enrichmentServiceName : "infoasst-enrichmentweb-${random_string.random.result}"
  plan_name = var.enrichmentAppServicePlanName != "" ? var.enrichmentAppServicePlanName : "infoasst-enrichmentasp-${random_string.random.result}"
  location  = var.location
  tags      = local.tags
  sku = {
    size     = var.enrichmentAppServiceSkuSize
    tier     = var.enrichmentAppServiceSkuTier
    capacity = 3
  }
  kind                                = "linux"
  reserved                            = true
  resourceGroupName                   = var.resources_resource_group_name
  resourceGroupVNET                   = var.resourceGroupName
  storageAccountId                    = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resourceGroupName}/providers/Microsoft.Storage/storageAccounts/${module.storage.name}/services/queue/queues/${var.embeddingsQueue}"
  scmDoBuildDuringDeployment          = false
  enableOryxBuild                     = false
  managedIdentity                     = true
  logAnalyticsWorkspaceResourceId     = module.logging.logAnalyticsId
  applicationInsightsConnectionString = module.logging.applicationInsightsConnectionString
  alwaysOn                            = true
  healthCheckPath                     = "/health"
  appCommandLine                      = ""
  keyVaultUri                         = module.kvModule.keyVaultUri
  keyVaultName                        = module.kvModule.keyVaultName
  container_registry                  = module.acr.login_server
  container_registry_admin_username   = module.acr.admin_username
  container_registry_admin_password   = module.acr.admin_password
  container_registry_id               = module.acr.acr_id
  is_secure_mode                      = true
  subnetIntegration_id                = data.azurerm_subnet.integration_subnet.id
  subnet_name                         = var.web_subnet_name
  vnet_name                           = var.vnet_name
  private_dns_zone_ids                = null
  azure_environment                   = var.azure_environment

  appSettings = {
    EMBEDDINGS_QUEUE                       = var.embeddingsQueue
    LOG_LEVEL                              = "DEBUG"
    DEQUEUE_MESSAGE_BATCH_SIZE             = 1
    AZURE_BLOB_STORAGE_ACCOUNT             = module.storage.name
    AZURE_BLOB_STORAGE_CONTAINER           = var.contentContainerName
    AZURE_BLOB_STORAGE_UPLOAD_CONTAINER    = var.uploadContainerName
    AZURE_BLOB_STORAGE_ENDPOINT            = module.storage.primary_blob_endpoint
    AZURE_QUEUE_STORAGE_ENDPOINT           = module.storage.primary_queue_endpoint
    COSMOSDB_URL                           = module.cosmosdb.CosmosDBEndpointURL
    COSMOSDB_LOG_DATABASE_NAME             = module.cosmosdb.CosmosDBLogDatabaseName
    COSMOSDB_LOG_CONTAINER_NAME            = module.cosmosdb.CosmosDBLogContainerName
    MAX_EMBEDDING_REQUEUE_COUNT            = 5
    EMBEDDING_REQUEUE_BACKOFF              = 60
    AZURE_OPENAI_SERVICE                   = var.useExistingAOAIService ? var.azureOpenAIServiceName : module.openaiServices.name
    AZURE_OPENAI_ENDPOINT                  = var.useExistingAOAIService ? "https://${var.azureOpenAIServiceName}.${var.azure_openai_domain}/" : module.openaiServices.endpoint
    AZURE_OPENAI_EMBEDDING_DEPLOYMENT_NAME = var.azureOpenAIEmbeddingDeploymentName
    AZURE_SEARCH_INDEX                     = var.searchIndexName
    AZURE_SEARCH_SERVICE_ENDPOINT          = module.searchServices.endpoint
    AZURE_SEARCH_AUDIENCE                  = var.azure_search_scope
    TARGET_EMBEDDINGS_MODEL                = var.useAzureOpenAIEmbeddings ? "azure-openai_${var.azureOpenAIEmbeddingDeploymentName}" : var.sentenceTransformersModelName
    EMBEDDING_VECTOR_SIZE                  = var.useAzureOpenAIEmbeddings ? 1536 : var.sentenceTransformerEmbeddingVectorSize
    AZURE_AI_CREDENTIAL_DOMAIN             = var.azure_ai_private_link_domain
    AZURE_OPENAI_AUTHORITY_HOST            = var.azure_openai_authority_host
  }
}

# // The application frontend
module "webapp" {
  source    = "./core/host/webapp"
  name      = var.backendServiceName != "" ? var.backendServiceName : "infoasst-web-${random_string.random.result}"
  plan_name = var.appServicePlanName != "" ? var.appServicePlanName : "infoasst-asp-${random_string.random.result}"
  sku = {
    tier     = var.appServiceSkuTier
    size     = var.appServiceSkuSize
    capacity = 1
  }
  kind                                = "linux"
  resourceGroupName                   = var.resources_resource_group_name
  resourceGroupVNET                   = var.resourceGroupName
  location                            = var.location
  tags                                = merge(local.tags, { "azd-service-name" = "backend" })
  runtimeVersion                      = "3.12"
  scmDoBuildDuringDeployment          = false
  managedIdentity                     = true
  alwaysOn                            = true
  appCommandLine                      = ""
  healthCheckPath                     = "/health"
  logAnalyticsWorkspaceResourceId     = module.logging.logAnalyticsId
  azure_portal_domain                 = var.azure_portal_domain
  enableOryxBuild                     = false
  applicationInsightsConnectionString = module.logging.applicationInsightsConnectionString
  keyVaultUri                         = module.kvModule.keyVaultUri
  keyVaultName                        = module.kvModule.keyVaultName
  tenantId                            = data.azurerm_client_config.current.tenant_id
  is_secure_mode                      = true
  subnet_name                         = var.web_subnet_name
  vnet_name                           = var.vnet_name
  snetIntegration_id                  = data.azurerm_subnet.integration_subnet.id
  private_dns_zone_ids                = null
  private_dns_zone_name               = null

  container_registry                = module.acr.login_server
  container_registry_admin_username = module.acr.admin_username
  container_registry_admin_password = module.acr.admin_password
  container_registry_id             = module.acr.acr_id
  randomString                      = random_string.random.result
  azure_environment                 = var.azure_environment

  appSettings = {
    APPLICATIONINSIGHTS_CONNECTION_STRING = module.logging.applicationInsightsConnectionString
    AZURE_BLOB_STORAGE_ACCOUNT            = module.storage.name
    AZURE_BLOB_STORAGE_ENDPOINT           = module.storage.primary_blob_endpoint
    AZURE_BLOB_STORAGE_CONTAINER          = var.contentContainerName
    AZURE_BLOB_STORAGE_UPLOAD_CONTAINER   = var.uploadContainerName
    AZURE_OPENAI_SERVICE                  = var.useExistingAOAIService ? var.azureOpenAIServiceName : module.openaiServices.name
    AZURE_OPENAI_RESOURCE_GROUP           = var.useExistingAOAIService ? var.azureOpenAIResourceGroup : var.resourceGroupName
    AZURE_OPENAI_ENDPOINT                 = var.useExistingAOAIService ? "https://${var.azureOpenAIServiceName}.${var.azure_openai_domain}/" : module.openaiServices.endpoint
    AZURE_OPENAI_AUTHORITY_HOST           = var.azure_openai_authority_host
    AZURE_ARM_MANAGEMENT_API              = var.azure_arm_management_api
    AZURE_SEARCH_INDEX                    = var.searchIndexName
    AZURE_SEARCH_SERVICE                  = module.searchServices.name
    AZURE_SEARCH_SERVICE_ENDPOINT         = module.searchServices.endpoint
    AZURE_SEARCH_AUDIENCE                 = var.azure_search_scope
    AZURE_OPENAI_CHATGPT_DEPLOYMENT       = var.chatGptDeploymentName != "" ? var.chatGptDeploymentName : (var.chatGptModelName != "" ? var.chatGptModelName : "gpt-35-turbo-16k")
    AZURE_OPENAI_CHATGPT_MODEL_NAME       = var.chatGptModelName
    AZURE_OPENAI_CHATGPT_MODEL_VERSION    = var.chatGptModelVersion
    USE_AZURE_OPENAI_EMBEDDINGS           = var.useAzureOpenAIEmbeddings
    EMBEDDING_DEPLOYMENT_NAME             = var.useAzureOpenAIEmbeddings ? var.azureOpenAIEmbeddingDeploymentName : var.sentenceTransformersModelName
    AZURE_OPENAI_EMBEDDINGS_MODEL_NAME    = var.azureOpenAIEmbeddingsModelName
    AZURE_OPENAI_EMBEDDINGS_MODEL_VERSION = var.azureOpenAIEmbeddingsModelVersion
    APPINSIGHTS_INSTRUMENTATIONKEY        = module.logging.applicationInsightsInstrumentationKey
    COSMOSDB_URL                          = module.cosmosdb.CosmosDBEndpointURL
    COSMOSDB_LOG_DATABASE_NAME            = module.cosmosdb.CosmosDBLogDatabaseName
    COSMOSDB_LOG_CONTAINER_NAME           = module.cosmosdb.CosmosDBLogContainerName
    QUERY_TERM_LANGUAGE                   = var.queryTermLanguage
    AZURE_SUBSCRIPTION_ID                 = data.azurerm_client_config.current.subscription_id
    CHAT_WARNING_BANNER_TEXT              = var.chatWarningBannerText
    TARGET_EMBEDDINGS_MODEL               = var.useAzureOpenAIEmbeddings ? "azure-openai_${var.azureOpenAIEmbeddingDeploymentName}" : var.sentenceTransformersModelName
    ENRICHMENT_APPSERVICE_URL             = module.enrichmentApp.uri
    AZURE_AI_ENDPOINT                     = module.cognitiveServices.cognitiveServiceEndpoint
    AZURE_AI_LOCATION                     = var.location
    APPLICATION_TITLE                     = var.applicationtitle == "" ? "Information Assistant, built with Azure OpenAI" : var.applicationtitle
    USE_SEMANTIC_RERANKER                 = var.use_semantic_reranker
    BING_SEARCH_ENDPOINT                  = ""
    #BING_SEARCH_ENDPOINT                  = var.enableWebChat ? module.bingSearch[0].endpoint : ""
    ENABLE_WEB_CHAT               = var.enableWebChat
    ENABLE_BING_SAFE_SEARCH       = var.enableBingSafeSearch
    ENABLE_UNGROUNDED_CHAT        = var.enableUngroundedChat
    ENABLE_MATH_ASSISTANT         = var.enableMathAssitant
    ENABLE_TABULAR_DATA_ASSISTANT = var.enableTabularDataAssistant
    MAX_CSV_FILE_SIZE             = var.maxCsvFileSize
    AZURE_AI_CREDENTIAL_DOMAIN    = var.azure_ai_private_link_domain
  }

  aadClientId = module.entraObjects.azure_ad_web_app_client_id
  depends_on  = [module.kvModule]
}

# // Function App 
module "functions" {
  source = "./core/host/functions"

  name         = var.functionsAppName != "" ? var.functionsAppName : "infoasst-func-${random_string.random.result}"
  location     = var.location
  tags         = local.tags
  keyVaultUri  = module.kvModule.keyVaultUri
  keyVaultName = module.kvModule.keyVaultName
  plan_name    = var.appServicePlanName != "" ? var.appServicePlanName : "infoasst-func-asp-${random_string.random.result}"
  sku = {
    size     = var.functionsAppSkuSize
    tier     = var.functionsAppSkuTier
    capacity = 2
  }
  kind                                  = "linux"
  runtime                               = "python"
  resourceGroupName                     = var.resources_resource_group_name
  resourceGroupVNET                     = var.resourceGroupName
  azure_portal_domain                   = var.azure_portal_domain
  appInsightsConnectionString           = module.logging.applicationInsightsConnectionString
  appInsightsInstrumentationKey         = module.logging.applicationInsightsInstrumentationKey
  blobStorageAccountName                = module.storage.name
  blobStorageAccountEndpoint            = module.storage.primary_blob_endpoint
  blobStorageAccountOutputContainerName = var.contentContainerName
  blobStorageAccountUploadContainerName = var.uploadContainerName
  blobStorageAccountLogContainerName    = var.functionLogsContainerName
  queueStorageAccountEndpoint           = module.storage.primary_queue_endpoint
  formRecognizerEndpoint                = module.aiDocIntelligence.formRecognizerAccountEndpoint
  CosmosDBEndpointURL                   = module.cosmosdb.CosmosDBEndpointURL
  CosmosDBLogDatabaseName               = module.cosmosdb.CosmosDBLogDatabaseName
  CosmosDBLogContainerName              = module.cosmosdb.CosmosDBLogContainerName
  chunkTargetSize                       = var.chunkTargetSize
  targetPages                           = var.targetPages
  formRecognizerApiVersion              = var.formRecognizerApiVersion
  pdfSubmitQueue                        = var.pdfSubmitQueue
  pdfPollingQueue                       = var.pdfPollingQueue
  nonPdfSubmitQueue                     = var.nonPdfSubmitQueue
  mediaSubmitQueue                      = var.mediaSubmitQueue
  maxSecondsHideOnUpload                = var.maxSecondsHideOnUpload
  maxSubmitRequeueCount                 = var.maxSubmitRequeueCount
  pollQueueSubmitBackoff                = var.pollQueueSubmitBackoff
  pdfSubmitQueueBackoff                 = var.pdfSubmitQueueBackoff
  textEnrichmentQueue                   = var.textEnrichmentQueue
  imageEnrichmentQueue                  = var.imageEnrichmentQueue
  maxPollingRequeueCount                = var.maxPollingRequeueCount
  submitRequeueHideSeconds              = var.submitRequeueHideSeconds
  pollingBackoff                        = var.pollingBackoff
  maxReadAttempts                       = var.maxReadAttempts
  enrichmentEndpoint                    = module.cognitiveServices.cognitiveServiceEndpoint
  enrichmentName                        = module.cognitiveServices.cognitiveServicerAccountName
  enrichmentLocation                    = var.location
  targetTranslationLanguage             = var.targetTranslationLanguage
  maxEnrichmentRequeueCount             = var.maxEnrichmentRequeueCount
  enrichmentBackoff                     = var.enrichmentBackoff
  enableDevCode                         = var.enableDevCode
  EMBEDDINGS_QUEUE                      = var.embeddingsQueue
  azureSearchIndex                      = var.searchIndexName
  azureSearchServiceEndpoint            = module.searchServices.endpoint
  endpointSuffix                        = var.azure_storage_domain
  logAnalyticsWorkspaceResourceId       = module.logging.logAnalyticsId
  is_secure_mode                        = true
  vnet_name                             = var.vnet_name
  subnet_name                           = var.web_subnet_name
  subnetIntegration_id                  = data.azurerm_subnet.integration_subnet.id
  private_dns_zone_ids                  = null
  container_registry                    = module.acr.login_server
  container_registry_admin_username     = module.acr.admin_username
  container_registry_admin_password     = module.acr.admin_password
  container_registry_id                 = module.acr.acr_id
  azure_environment                     = var.azure_environment
  azure_ai_credential_domain            = var.azure_ai_private_link_domain
}

data "azurerm_subnet" "openai_subnet" {
  name                 = var.subnet_openai
  virtual_network_name = data.azurerm_virtual_network.existing_vnet.name
  resource_group_name  = var.resourceGroupName
}

module "openaiServices" {
  source                          = "./core/ai/openaiservices"
  name                            = var.openAIServiceName != "" ? var.openAIServiceName : "infoasst-aoai-${random_string.random.result}"
  location                        = var.openai_region
  vnetLocation                    = var.location
  tags                            = local.tags
  resourceGroupName               = var.resources_resource_group_name
  resourceGroupVNET               = var.resourceGroupName
  useExistingAOAIService          = false
  is_secure_mode                  = true
  subnet_name                     = var.subnet_openai
  vnet_name                       = data.azurerm_virtual_network.existing_vnet.name
  subnet_id                       = data.azurerm_subnet.openai_subnet.id
  private_dns_zone_ids            = null
  arm_template_schema_mgmt_api    = var.arm_template_schema_mgmt_api
  key_vault_name                  = module.kvModule.keyVaultName
  logAnalyticsWorkspaceResourceId = module.logging.logAnalyticsId

  deployments = [
    {
      name = var.chatGptDeploymentName != "" ? var.chatGptDeploymentName : (var.chatGptModelName != "" ? var.chatGptModelName : "gpt-35-turbo-16k")
      model = {
        format  = "OpenAI"
        name    = var.chatGptModelName != "" ? var.chatGptModelName : "gpt-35-turbo-16k"
        version = var.chatGptModelVersion != "" ? var.chatGptModelVersion : "0613"
      }
      sku = {
        name     = var.chatGptModelSkuName
        capacity = var.chatGptDeploymentCapacity
      }
      rai_policy_name = "Microsoft.Default"
    },
    {
      name = var.azureOpenAIEmbeddingDeploymentName != "" ? var.azureOpenAIEmbeddingDeploymentName : "text-embedding-ada-002"
      model = {
        format  = "OpenAI"
        name    = var.azureOpenAIEmbeddingsModelName != "" ? var.azureOpenAIEmbeddingsModelName : "text-embedding-ada-002"
        version = "2"
      }
      sku = {
        name     = var.azureOpenAIEmbeddingsModelSku
        capacity = var.embeddingsDeploymentCapacity
      }
      rai_policy_name = "Microsoft.Default"
    }
  ]
}

module "aiDocIntelligence" {
  source                       = "./core/ai/docintelligence"
  name                         = "infoasst-docint-${random_string.random.result}"
  location                     = var.location
  tags                         = local.tags
  customSubDomainName          = "infoasst-docint-${random_string.random.result}"
  resourceGroupName            = var.resources_resource_group_name
  resourceGroupVNET            = var.resourceGroupName
  key_vault_name               = module.kvModule.keyVaultName
  is_secure_mode               = var.is_secure_mode
  subnet_name                  = var.subnet_openai
  vnet_name                    = var.vnet_name
  private_dns_zone_ids         = null
  arm_template_schema_mgmt_api = var.arm_template_schema_mgmt_api
}

module "cognitiveServices" {
  source                       = "./core/ai/cogServices"
  name                         = "infoasst-aisvc-${random_string.random.result}"
  location                     = var.location
  tags                         = local.tags
  resourceGroupName            = var.resources_resource_group_name
  resourceGroupVNET            = var.resourceGroupName
  is_secure_mode               = true
  subnetResourceId             = null
  private_dns_zone_ids         = null
  arm_template_schema_mgmt_api = var.arm_template_schema_mgmt_api
  key_vault_name               = module.kvModule.keyVaultName
  kv_secret_expiration         = var.kv_secret_expiration
  subnet_name                  = var.subnet_openai
  vnet_name                    = var.vnet_name
}

module "searchServices" {
  source                       = "./core/search"
  name                         = var.searchServicesName != "" ? var.searchServicesName : "infoasst-search-${random_string.random.result}"
  location                     = var.location
  tags                         = local.tags
  semanticSearch               = var.use_semantic_reranker ? "free" : null
  resourceGroupName            = var.resources_resource_group_name
  resourceGroupVNET            = var.resourceGroupName
  azure_search_domain          = var.azure_search_domain
  is_secure_mode               = true
  subnet_name                  = var.subnet_openai
  vnet_name                    = var.vnet_name
  private_dns_zone_ids         = null
  arm_template_schema_mgmt_api = var.arm_template_schema_mgmt_api
  key_vault_name               = module.kvModule.keyVaultName
}

module "cosmosdb" {
  source                       = "./core/db"
  name                         = "infoasst-cosmos-${random_string.random.result}"
  location                     = var.location
  tags                         = local.tags
  logDatabaseName              = "statusdb"
  logContainerName             = "statuscontainer"
  resourceGroupName            = var.resources_resource_group_name
  key_vault_name               = module.kvModule.keyVaultName
  is_secure_mode               = true
  resourceGroupVNET            = var.resourceGroupName
  subnet_name                  = var.subnet_data
  vnet_name                    = var.vnet_name
  private_dns_zone_ids         = null
  arm_template_schema_mgmt_api = var.arm_template_schema_mgmt_api
}

module "acr" {
  source                = "./core/container_registry"
  name                  = "infoasstacr${random_string.random.result}"
  location              = var.location
  resourceGroupName     = var.resources_resource_group_name
  resourceGroupVNET     = var.resourceGroupName
  is_secure_mode        = true
  subnet_name           = var.subnet_service_name
  vnet_name             = var.vnet_name
  private_dns_zone_name = null
  private_dns_zone_ids  = null
}

# // SharePoint Connector is not supported in secure mode
# module "sharepoint" {
#   count                = var.is_secure_mode ? 0 : var.enableSharePointConnector ? 1 : 0
#   source               = "./core/sharepoint"
#   location             = azurerm_resource_group.rg.location
#   resource_group_name  = azurerm_resource_group.rg.name
#   resource_group_id    = azurerm_resource_group.rg.id
#   subscription_id      = data.azurerm_client_config.current.subscription_id
#   storage_account_name = module.storage.name
#   storage_access_key   = module.storage.storage_account_access_key
#   random_string        = random_string.random.result
#   tags                 = local.tags

#   depends_on = [
#     module.storage
#   ]
# }

module "azMonitor" {
  source            = "./core/logging/monitor"
  logAnalyticsName  = module.logging.logAnalyticsName
  location          = var.location
  logWorkbookName   = "infoasst-lw-${random_string.random.result}"
  resourceGroupName = var.resources_resource_group_name
  componentResource = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resourceGroupName}/providers/Microsoft.OperationalInsights/workspaces/${module.logging.logAnalyticsName}"
}

# // Bing Search is not supported in US Government or Secure Mode
# module "bingSearch" {
#   count                        = var.azure_environment == "AzureUSGovernment" ? 0 : var.is_secure_mode ? 0 : var.enableWebChat ? 1 : 0
#   source                       = "./core/ai/bingSearch"
#   name                         = "infoasst-bing-${random_string.random.result}"
#   resourceGroupName            = azurerm_resource_group.rg.name
#   tags                         = local.tags
#   sku                          = "S1" //supported SKUs can be found at https://www.microsoft.com/en-us/bing/apis/pricing
#   arm_template_schema_mgmt_api = var.arm_template_schema_mgmt_api
#   key_vault_name               = module.kvModule.keyVaultName
#   kv_secret_expiration         = var.kv_secret_expiration
# }

data "azurerm_resource_group" "rg" {
  name = var.resources_resource_group_name
}

# // USER ROLES
module "userRoles" {
  source   = "./core/security/role"
  for_each = { for role in local.selected_roles : role => { role_definition_id = local.azure_roles[role] } }

  scope            = data.azurerm_resource_group.rg.id
  principalId      = data.azurerm_client_config.current.object_id
  roleDefinitionId = each.value.role_definition_id
  principalType    = var.isInAutomation ? "ServicePrincipal" : "User"
  subscriptionId   = data.azurerm_client_config.current.subscription_id
  resourceGroupId  = data.azurerm_resource_group.rg.id
}

resource "azurerm_cosmosdb_sql_role_assignment" "user_cosmosdb_data_contributor" {
  resource_group_name = var.resources_resource_group_name
  account_name        = module.cosmosdb.name
  role_definition_id  = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resourceGroupName}/providers/Microsoft.DocumentDB/databaseAccounts/${module.cosmosdb.name}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002" #Cosmos DB Built-in Data Contributor
  principal_id        = data.azurerm_client_config.current.object_id
  scope               = module.cosmosdb.id
}

data "azurerm_resource_group" "existing" {
  count = var.useExistingAOAIService ? 1 : 0
  name  = var.azureOpenAIResourceGroup
}

# # # // SYSTEM IDENTITY ROLES


module "webApp_OpenAiRole" {
  source = "./core/security/role"

  scope            = var.useExistingAOAIService ? data.azurerm_resource_group.existing[0].id : data.azurerm_resource_group.rg.id
  principalId      = module.webapp.identityPrincipalId
  roleDefinitionId = local.azure_roles.CognitiveServicesOpenAIUser
  principalType    = "ServicePrincipal"
  subscriptionId   = data.azurerm_client_config.current.subscription_id
  resourceGroupId  = data.azurerm_resource_group.rg.id
}

module "enrichmentApp_OpenAiRole" {
  source = "./core/security/role"

  scope            = var.useExistingAOAIService ? data.azurerm_resource_group.existing[0].id : data.azurerm_resource_group.rg.id
  principalId      = module.enrichmentApp.identityPrincipalId
  roleDefinitionId = local.azure_roles.CognitiveServicesOpenAIUser
  principalType    = "ServicePrincipal"
  subscriptionId   = data.azurerm_client_config.current.subscription_id
  resourceGroupId  = data.azurerm_resource_group.rg.id
}

module "webApp_CognitiveServicesUser" {
  source = "./core/security/role"

  scope            = data.azurerm_resource_group.rg.id
  principalId      = module.webapp.identityPrincipalId
  roleDefinitionId = local.azure_roles.CognitiveServicesUser
  principalType    = "ServicePrincipal"
  subscriptionId   = data.azurerm_client_config.current.subscription_id
  resourceGroupId  = data.azurerm_resource_group.rg.id
}

module "functionApp_CognitiveServicesUser" {
  source = "./core/security/role"

  scope            = data.azurerm_resource_group.rg.id
  principalId      = module.functions.identityPrincipalId
  roleDefinitionId = local.azure_roles.CognitiveServicesUser
  principalType    = "ServicePrincipal"
  subscriptionId   = data.azurerm_client_config.current.subscription_id
  resourceGroupId  = data.azurerm_resource_group.rg.id
}

module "enrichmentApp_CognitiveServicesUser" {
  source = "./core/security/role"

  scope            = data.azurerm_resource_group.rg.id
  principalId      = module.enrichmentApp.identityPrincipalId
  roleDefinitionId = local.azure_roles.CognitiveServicesUser
  principalType    = "ServicePrincipal"
  subscriptionId   = data.azurerm_client_config.current.subscription_id
  resourceGroupId  = data.azurerm_resource_group.rg.id
}

module "enrichmentApp_StorageQueueDataContributor" {
  source = "./core/security/role"

  scope            = data.azurerm_resource_group.rg.id
  principalId      = module.enrichmentApp.identityPrincipalId
  roleDefinitionId = local.azure_roles.StorageQueueDataContributor
  principalType    = "ServicePrincipal"
  subscriptionId   = data.azurerm_client_config.current.subscription_id
  resourceGroupId  = data.azurerm_resource_group.rg.id
}

module "functionApp_StorageQueueDataContributor" {
  source = "./core/security/role"

  scope            = data.azurerm_resource_group.rg.id
  principalId      = module.functions.identityPrincipalId
  roleDefinitionId = local.azure_roles.StorageQueueDataContributor
  principalType    = "ServicePrincipal"
  subscriptionId   = data.azurerm_client_config.current.subscription_id
  resourceGroupId  = data.azurerm_resource_group.rg.id
}

module "webApp_StorageBlobDataContributor" {
  source = "./core/security/role"

  scope            = data.azurerm_resource_group.rg.id
  principalId      = module.webapp.identityPrincipalId
  roleDefinitionId = local.azure_roles.StorageBlobDataContributor
  principalType    = "ServicePrincipal"
  subscriptionId   = data.azurerm_client_config.current.subscription_id
  resourceGroupId  = data.azurerm_resource_group.rg.id
}

module "webApp_SearchIndexDataReader" {
  source = "./core/security/role"

  scope            = data.azurerm_resource_group.rg.id
  principalId      = module.webapp.identityPrincipalId
  roleDefinitionId = local.azure_roles.SearchIndexDataReader
  principalType    = "ServicePrincipal"
  subscriptionId   = data.azurerm_client_config.current.subscription_id
  resourceGroupId  = data.azurerm_resource_group.rg.id
}

module "functionApp_SearchIndexDataContributor" {
  source = "./core/security/role"

  scope            = data.azurerm_resource_group.rg.id
  principalId      = module.functions.identityPrincipalId
  roleDefinitionId = local.azure_roles.SearchIndexDataContributor
  principalType    = "ServicePrincipal"
  subscriptionId   = data.azurerm_client_config.current.subscription_id
  resourceGroupId  = data.azurerm_resource_group.rg.id
}

module "encrichmentApp_SearchIndexDataContributor" {
  source = "./core/security/role"

  scope            = data.azurerm_resource_group.rg.id
  principalId      = module.enrichmentApp.identityPrincipalId
  roleDefinitionId = local.azure_roles.SearchIndexDataContributor
  principalType    = "ServicePrincipal"
  subscriptionId   = data.azurerm_client_config.current.subscription_id
  resourceGroupId  = data.azurerm_resource_group.rg.id
}

module "fuctionApp_StorageBlobDataOwner" {
  source = "./core/security/role"

  scope            = data.azurerm_resource_group.rg.id
  principalId      = module.functions.identityPrincipalId
  roleDefinitionId = local.azure_roles.StorageBlobDataOwner
  principalType    = "ServicePrincipal"
  subscriptionId   = data.azurerm_client_config.current.subscription_id
  resourceGroupId  = data.azurerm_resource_group.rg.id
}

module "enrichmentApp_StorageBlobDataOwner" {
  source = "./core/security/role"

  scope            = data.azurerm_resource_group.rg.id
  principalId      = module.enrichmentApp.identityPrincipalId
  roleDefinitionId = local.azure_roles.StorageBlobDataOwner
  principalType    = "ServicePrincipal"
  subscriptionId   = data.azurerm_client_config.current.subscription_id
  resourceGroupId  = data.azurerm_resource_group.rg.id
}

module "fuctionApp_StorageAccountContributor" {
  source = "./core/security/role"

  scope            = data.azurerm_resource_group.rg.id
  principalId      = module.functions.identityPrincipalId
  roleDefinitionId = local.azure_roles.StorageAccountContributor
  principalType    = "ServicePrincipal"
  subscriptionId   = data.azurerm_client_config.current.subscription_id
  resourceGroupId  = data.azurerm_resource_group.rg.id
}

resource "azurerm_cosmosdb_sql_role_assignment" "webApp_cosmosdb_data_contributor" {
  resource_group_name = data.azurerm_resource_group.rg.name
  account_name        = module.cosmosdb.name
  role_definition_id  = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${data.azurerm_resource_group.rg.name}/providers/Microsoft.DocumentDB/databaseAccounts/${module.cosmosdb.name}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002" #Cosmos DB Built-in Data Contributor
  principal_id        = module.webapp.identityPrincipalId
  scope               = module.cosmosdb.id
}

resource "azurerm_cosmosdb_sql_role_assignment" "functionApp_cosmosdb_data_contributor" {
  resource_group_name = var.resources_resource_group_name
  account_name        = module.cosmosdb.name
  role_definition_id  = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resourceGroupName}/providers/Microsoft.DocumentDB/databaseAccounts/${module.cosmosdb.name}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002" #Cosmos DB Built-in Data Contributor
  principal_id        = module.functions.identityPrincipalId
  scope               = module.cosmosdb.id
}

resource "azurerm_cosmosdb_sql_role_assignment" "enrichmentApp_cosmosdb_data_contributor" {
  resource_group_name = data.azurerm_resource_group.rg.name
  account_name        = module.cosmosdb.name
  role_definition_id  = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${data.azurerm_resource_group.rg.name}/providers/Microsoft.DocumentDB/databaseAccounts/${module.cosmosdb.name}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002" #Cosmos DB Built-in Data Contributor
  principal_id        = module.enrichmentApp.identityPrincipalId
  scope               = module.cosmosdb.id
}

module "docIntel_StorageBlobDataReader" {
  source           = "./core/security/role"
  scope            = data.azurerm_resource_group.rg.id
  principalId      = module.aiDocIntelligence.docIntelligenceIdentity
  roleDefinitionId = local.azure_roles.StorageBlobDataReader
  principalType    = "ServicePrincipal"
  subscriptionId   = data.azurerm_client_config.current.subscription_id
  resourceGroupId  = data.azurerm_resource_group.rg.id
}

# # // MANAGEMENT SERVICE PRINCIPAL ROLES
module "openAiRoleMgmt" {
  source = "./core/security/role"
  # If leveraging an existing Azure OpenAI service, only make this assignment if not under automation.
  # When under automation and using an existing Azure OpenAI service, this will result in a duplicate assignment error.
  count            = var.useExistingAOAIService ? var.isInAutomation ? 0 : 1 : 1
  scope            = var.useExistingAOAIService ? data.azurerm_resource_group.existing[0].id : data.azurerm_resource_group.rg.id
  principalId      = module.entraObjects.azure_ad_mgmt_sp_id
  roleDefinitionId = local.azure_roles.CognitiveServicesOpenAIUser
  principalType    = "ServicePrincipal"
  subscriptionId   = data.azurerm_client_config.current.subscription_id
  resourceGroupId  = data.azurerm_resource_group.rg.id
}

# // DEPLOYMENT OF AZURE CUSTOMER ATTRIBUTION TAG
resource "azurerm_resource_group_template_deployment" "customer_attribution" {
  count               = var.cuaEnabled ? 1 : 0
  name                = "pid-${var.cuaId}"
  resource_group_name = data.azurerm_resource_group.rg.name
  deployment_mode     = "Incremental"
  template_content    = <<TEMPLATE
{
  "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "resources": []
}
TEMPLATE
}
