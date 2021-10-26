terraform {
  required_version = ">= 0.12.6"
  required_providers {
    azurerm = {
      version = "~> 2.82.0"
    }
  }
}

#"c778c451-6f3b-48e1-86b1-e55fa7615154"

provider "azurerm" {
  subscription_id = "${var.subscription_id}"
  tenant_id       = "xxxx-xxxx-xxxx-xxx-xxxx"
  environment     = "usgovernment"
  features {}
}


resource "azurerm_resource_group" "rg" {
  name = "${var.resource_group_name}"
  location = "${var.resource_group_location}"
}

#https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cosmosdb_account#mongo_server_version
#https://dev.to/krpmuruga/terraform-with-azure-cosmosdb-mongodb-example-4931
#https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cosmosdb_mongo_database
#https://docs.microsoft.com/en-us/azure/cosmos-db/high-availability

resource "azurerm_cosmosdb_account" "acc" {
  name = "${var.cosmos_db_account_name}"
  location = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  offer_type = "Standard"
  kind = "MongoDB"
  enable_automatic_failover = true
  enable_free_tier = false
  mongo_server_version = "4.0"
  backup {
    type="Continuous"
  }
  
  capabilities {
    name = "EnableMongo"
  }

  consistency_policy {
      consistency_level = "Session"
  }

  geo_location {
      location = "${var.failover_location}"
      failover_priority = 1
  }

  geo_location {
      location = "${var.resource_group_location}"
      failover_priority = 0
  }
}

#https://docs.microsoft.com/en-us/azure/cosmos-db/mongodb/mongodb-indexing
#In the API for MongoDB, compound indexes are required if your query needs the ability to sort on multiple fields at once. 
#For queries with multiple filters that don't need to sort, create multiple single field indexes instead of a compound index to save on indexing costs.


resource "azurerm_cosmosdb_mongo_database" "mongodb" {
  name                = "cosmosmongodb"
  resource_group_name = azurerm_cosmosdb_account.acc.resource_group_name
  account_name        = azurerm_cosmosdb_account.acc.name
  throughput          = 400
}

#https://docs.microsoft.com/en-us/azure/cosmos-db/mongodb/mongodb-time-to-live
resource "azurerm_cosmosdb_mongo_collection" "coll" {
  name                = "cosmosmongodbcollection"
  resource_group_name = azurerm_cosmosdb_account.acc.resource_group_name
  account_name        = azurerm_cosmosdb_account.acc.name
  database_name       = azurerm_cosmosdb_mongo_database.mongodb.name

  default_ttl_seconds = "-1"
  shard_key           = "uniqueKey"
  throughput          = 400

  lifecycle {
    ignore_changes = [index]
  }

  depends_on = [azurerm_cosmosdb_mongo_database.mongodb]


}
