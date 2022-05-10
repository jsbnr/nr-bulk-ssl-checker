variable "jobs" {
    type = map(object({
        name = string
        data = string
  }))
}
variable insertAPIKey { description = "New Relic Metrics API insert key" }
variable locations { description = "New Relic Locations to run from"}
variable nameSpace { 
    description = "Namespace for the app, usually SSLCHKR, provide a different one if deploying this app more than once to an account" 
    default="SSLCHKR"
}
variable frequency { 
    description = "Monitor runtime frequency"  
    default=60
}

module "SSLminion" {
    source = "./modules/sslminion"
    for_each = var.jobs
    name = each.value.name
    nameSpace = var.nameSpace
    targetDataJS = each.value.data
    frequency = var.frequency
    insertKeyName = "${var.nameSpace}_MetricInsertKey"
    insertKeyValue = var.insertAPIKey
    locations = var.locations
}


resource "newrelic_one_dashboard" "dashboard" {
  name = "SSL Certificate Posture (${var.nameSpace})"

  page {
    name = "SSL Certificate Posture (${var.nameSpace})"

    widget_pie {
      title = "Certificate States"
      row = 1
      column = 1
      width = 3
      height = 3

      nrql_query {
        query = "select count(*) from (From Metric select latest(${var.nameSpace}.state) as state where tool='${var.nameSpace}' facet ${var.nameSpace}.name as name  limit max) since 1 hour ago facet state"
      }
    }

    widget_pie {
      title = "Certificate Issuers"
      row = 1
      column = 4
      width = 3
      height = 3

      nrql_query {
        query = "SELECT count(*) as 'Issuers' from Metric where  tool='${var.nameSpace}'  since 1 hour ago limit max  facet ${var.nameSpace}.issuer "
      }
    }

    widget_line {
      title = "Error breakdown by day"
      row = 4
      column = 1
      width = 6
      height = 3

      nrql_query {
        query = "select count(*) from (From Metric select latest(${var.nameSpace}.state) as state facet SSLCHKR.name as name where ${var.nameSpace}.state!='OK' and tool='${var.nameSpace}' timeseries 1 day limit max) since 3 months ago facet state timeseries 1 day"
      }
    }

    widget_table {
      title = "Certificate Data"
      row = 1
      column = 7
      width = 6
      height = 6

      nrql_query {
        query = "SELECT 0-latest(${var.nameSpace}.days) as 'Days until expire', latest(${var.nameSpace}.state) as 'State', latest(${var.nameSpace}.expirationDateUnix) as 'Expiration', latest(${var.nameSpace}.issuer) as 'Issuer' from Metric where tool='${var.nameSpace}' since 1 hour ago limit max facet ${var.nameSpace}.host as 'Host', ${var.nameSpace}.domain as 'Domain'"
      }
    }

    
    widget_table {
      title = "Monitor Summary"
      row = 7
      column = 1
      width = 6
      height = 2

      nrql_query {
        query = "SELECT latest(result), latest(custom.expectedTargets) as 'Targets',  latest(custom.criticalErrors) as 'Critical', latest(custom.warningErrors) as 'Warning', latest(custom.scriptErrors) as 'Error' from SyntheticCheck where monitorName like '${var.nameSpace}-%' facet monitorName "
      }
    }
  }
  
}