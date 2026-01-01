terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.57.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "fd0adf6a-200d-4cd8-99eb-c9be0c10f5ac"
}

resource "azurerm_resource_group" "k8_project" {
  name     = "k8_project"
  location = "East US"
}

resource "azurerm_virtual_network" "k8_project" {
  name                = "k8-project-vnet"
  location            = azurerm_resource_group.k8_project.location
  resource_group_name = azurerm_resource_group.k8_project.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "k8_project" {
  name                 = "aks-subnet"
  resource_group_name  = azurerm_resource_group.k8_project.name
  virtual_network_name = azurerm_virtual_network.k8_project.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_kubernetes_cluster" "k8_project" {
  name                = "aks1"
  location            = azurerm_resource_group.k8_project.location
  resource_group_name = azurerm_resource_group.k8_project.name
  dns_prefix          = "aks-dns"

  default_node_pool {
    name           = "default"
    node_count     = 2
    vm_size        = "Standard_D2_v2"
    vnet_subnet_id = azurerm_subnet.k8_project.id
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "calico"
    service_cidr   = "172.16.0.0/16"
    dns_service_ip = "172.16.0.10"
  }
  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = "Production"
  }
}

output "client_certificate" {
  value     = azurerm_kubernetes_cluster.k8_project.kube_config[0].client_certificate
  sensitive = true
}

output "kube_config" {
  value     = azurerm_kubernetes_cluster.k8_project.kube_config_raw
  sensitive = true
}

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "sentinel" {
  name                = "law-k8project"
  location            = azurerm_resource_group.k8_project.location
  resource_group_name = azurerm_resource_group.k8_project.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# Enable Sentinel on the workspace
resource "azurerm_sentinel_log_analytics_workspace_onboarding" "sentinel" {
  workspace_id = azurerm_log_analytics_workspace.sentinel.id
}

# Event Hub Namespace
resource "azurerm_eventhub_namespace" "falco" {
  name                = "evhns-k8project"
  location            = azurerm_resource_group.k8_project.location
  resource_group_name = azurerm_resource_group.k8_project.name
  sku                 = "Standard"
  capacity            = 1
}

# Event Hub for Falco alerts
resource "azurerm_eventhub" "falco" {
  name                = "falco-alerts"
  namespace_name      = azurerm_eventhub_namespace.falco.name
  resource_group_name = azurerm_resource_group.k8_project.name
  partition_count     = 2
  message_retention   = 1
}

# Authorization rule for Falco to send
resource "azurerm_eventhub_authorization_rule" "falco_send" {
  name                = "falco-send"
  namespace_name      = azurerm_eventhub_namespace.falco.name
  eventhub_name       = azurerm_eventhub.falco.name
  resource_group_name = azurerm_resource_group.k8_project.name
  listen              = false
  send                = true
  manage              = false
}

# Authorization rule for Sentinel to listen
resource "azurerm_eventhub_authorization_rule" "sentinel_listen" {
  name                = "sentinel-listen"
  namespace_name      = azurerm_eventhub_namespace.falco.name
  eventhub_name       = azurerm_eventhub.falco.name
  resource_group_name = azurerm_resource_group.k8_project.name
  listen              = true
  send                = false
  manage              = false
}

output "eventhub_connection_string" {
  value     = azurerm_eventhub_authorization_rule.falco_send.primary_connection_string
  sensitive = true
}

output "eventhub_namespace" {
  value = azurerm_eventhub_namespace.falco.name
}

output "eventhub_name" {
  value = azurerm_eventhub.falco.name
}

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.sentinel.workspace_id
}

output "log_analytics_primary_key" {
  value     = azurerm_log_analytics_workspace.sentinel.primary_shared_key
  sensitive = true
}

# Logic App to forward Event Hub to Log Analytics
resource "azurerm_logic_app_workflow" "falco_to_sentinel" {
  name                = "logic-falco-to-sentinel"
  location            = azurerm_resource_group.k8_project.location
  resource_group_name = azurerm_resource_group.k8_project.name
}

output "logic_app_name" {
  value = azurerm_logic_app_workflow.falco_to_sentinel.name
}