
# Scaleway provider configuration
provider "scaleway" {
  access_key      = var.scw_access_key
  secret_key      = var.scw_secret_key
  organization_id = var.scw_organization_id
  project_id      = var.scw_project_id
  zone            = var.main_zone
  region          = var.main_region
}

# Providers for each region
provider "scaleway" {
  alias           = "par"
  access_key      = var.scw_access_key
  secret_key      = var.scw_secret_key
  organization_id = var.scw_organization_id
  project_id      = var.scw_project_id
  zone            = "fr-par-1"
  region          = "fr-par"
}

provider "scaleway" {
  alias           = "ams"
  access_key      = var.scw_access_key
  secret_key      = var.scw_secret_key
  organization_id = var.scw_organization_id
  project_id      = var.scw_project_id
  zone            = "nl-ams-1"
  region          = "nl-ams"
}

provider "scaleway" {
  alias           = "waw"
  access_key      = var.scw_access_key
  secret_key      = var.scw_secret_key
  organization_id = var.scw_organization_id
  project_id      = var.scw_project_id
  zone            = "pl-waw-1"
  region          = "pl-waw"
}
