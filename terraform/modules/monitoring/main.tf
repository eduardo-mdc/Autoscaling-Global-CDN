# Google Cloud Monitoring Module
# Creates dashboards for load balancer metrics including request count, latency, and backend health

# Create a monitoring dashboard for load balancer metrics
resource "google_monitoring_dashboard" "lb_dashboard" {
  dashboard_json = jsonencode({
    "displayName" = var.dashboard_display_name,
    "gridLayout" = {
      "widgets" = concat(
        # Request Count Widgets
        var.enable_request_count_monitoring ? [
          {
            "title" = "Request Count by Region",
            "xyChart" = {
              "dataSets" = [
                for region in var.regions : {
                  "timeSeriesQuery" = {
                    "timeSeriesFilter" = {
                      "filter" = "metric.type=\"loadbalancing.googleapis.com/https/request_count\" resource.type=\"https_lb_rule\" resource.label.\"url_map_name\"=\"${var.load_balancer_name}\" metadata.system_labels.\"region\"=\"${region}\"",
                      "aggregation" = {
                        "alignmentPeriod" = "60s",
                        "perSeriesAligner" = "ALIGN_RATE",
                        "crossSeriesReducer" = "REDUCE_SUM",
                        "groupByFields" = ["resource.label.\"url_map_name\"", "metadata.system_labels.\"region\""]
                      }
                    },
                    "unitOverride" = "1"
                  },
                  "plotType" = "LINE",
                  "legendTemplate" = "${region} Requests"
                }
              ],
              "timeshiftDuration" = "0s",
              "yAxis" = {
                "label" = "Requests per second",
                "scale" = "LINEAR"
              }
            }
          }
        ] : [],
        
        # Latency Widgets
        var.enable_latency_monitoring ? [
          {
            "title" = "Request Latency by Region",
            "xyChart" = {
              "dataSets" = [
                for region in var.regions : {
                  "timeSeriesQuery" = {
                    "timeSeriesFilter" = {
                      "filter" = "metric.type=\"loadbalancing.googleapis.com/https/request_latencies\" resource.type=\"https_lb_rule\" resource.label.\"url_map_name\"=\"${var.load_balancer_name}\" metadata.system_labels.\"region\"=\"${region}\"",
                      "aggregation" = {
                        "alignmentPeriod" = "60s",
                        "perSeriesAligner" = "ALIGN_PERCENTILE_99",
                        "crossSeriesReducer" = "REDUCE_MEAN",
                        "groupByFields" = ["resource.label.\"url_map_name\"", "metadata.system_labels.\"region\""]
                      }
                    },
                    "unitOverride" = "ms"
                  },
                  "plotType" = "LINE",
                  "legendTemplate" = "${region} p99 Latency"
                }
              ],
              "timeshiftDuration" = "0s",
              "yAxis" = {
                "label" = "Latency (ms)",
                "scale" = "LINEAR"
              }
            }
          },
          {
            "title" = "Latency Distribution",
            "xyChart" = {
              "dataSets" = [
                {
                  "timeSeriesQuery" = {
                    "timeSeriesFilter" = {
                      "filter" = "metric.type=\"loadbalancing.googleapis.com/https/request_latencies\" resource.type=\"https_lb_rule\" resource.label.\"url_map_name\"=\"${var.load_balancer_name}\"",
                      "aggregation" = {
                        "alignmentPeriod" = "60s",
                        "perSeriesAligner" = "ALIGN_PERCENTILE_50",
                        "crossSeriesReducer" = "REDUCE_MEAN",
                        "groupByFields" = ["resource.label.\"url_map_name\""]
                      }
                    },
                    "unitOverride" = "ms"
                  },
                  "plotType" = "LINE",
                  "legendTemplate" = "p50 Latency"
                },
                {
                  "timeSeriesQuery" = {
                    "timeSeriesFilter" = {
                      "filter" = "metric.type=\"loadbalancing.googleapis.com/https/request_latencies\" resource.type=\"https_lb_rule\" resource.label.\"url_map_name\"=\"${var.load_balancer_name}\"",
                      "aggregation" = {
                        "alignmentPeriod" = "60s",
                        "perSeriesAligner" = "ALIGN_PERCENTILE_95",
                        "crossSeriesReducer" = "REDUCE_MEAN",
                        "groupByFields" = ["resource.label.\"url_map_name\""]
                      }
                    },
                    "unitOverride" = "ms"
                  },
                  "plotType" = "LINE",
                  "legendTemplate" = "p95 Latency"
                },
                {
                  "timeSeriesQuery" = {
                    "timeSeriesFilter" = {
                      "filter" = "metric.type=\"loadbalancing.googleapis.com/https/request_latencies\" resource.type=\"https_lb_rule\" resource.label.\"url_map_name\"=\"${var.load_balancer_name}\"",
                      "aggregation" = {
                        "alignmentPeriod" = "60s",
                        "perSeriesAligner" = "ALIGN_PERCENTILE_99",
                        "crossSeriesReducer" = "REDUCE_MEAN",
                        "groupByFields" = ["resource.label.\"url_map_name\""]
                      }
                    },
                    "unitOverride" = "ms"
                  },
                  "plotType" = "LINE",
                  "legendTemplate" = "p99 Latency"
                }
              ],
              "timeshiftDuration" = "0s",
              "yAxis" = {
                "label" = "Latency (ms)",
                "scale" = "LINEAR"
              }
            }
          }
        ] : [],
        
        # Backend Health Widgets
        var.enable_backend_health_monitoring && length(var.backend_service_names) > 0 ? [
          {
            "title" = "Backend Service Health",
            "xyChart" = {
              "dataSets" = flatten([
                for backend in var.backend_service_names : [
                  {
                    "timeSeriesQuery" = {
                      "timeSeriesFilter" = {
                        "filter" = "metric.type=\"loadbalancing.googleapis.com/https/backend_request_count\" resource.type=\"https_lb_rule\" resource.label.\"url_map_name\"=\"${var.load_balancer_name}\" metric.label.\"response_code_class\"=\"200\" metric.label.\"backend_name\"=\"${backend}\"",
                        "aggregation" = {
                          "alignmentPeriod" = "60s",
                          "perSeriesAligner" = "ALIGN_RATE",
                          "crossSeriesReducer" = "REDUCE_SUM",
                          "groupByFields" = ["resource.label.\"url_map_name\"", "metric.label.\"backend_name\""]
                        }
                      },
                      "unitOverride" = "1"
                    },
                    "plotType" = "LINE",
                    "legendTemplate" = "${backend} Success"
                  },
                  {
                    "timeSeriesQuery" = {
                      "timeSeriesFilter" = {
                        "filter" = "metric.type=\"loadbalancing.googleapis.com/https/backend_request_count\" resource.type=\"https_lb_rule\" resource.label.\"url_map_name\"=\"${var.load_balancer_name}\" metric.label.\"response_code_class\"!=\"200\" metric.label.\"backend_name\"=\"${backend}\"",
                        "aggregation" = {
                          "alignmentPeriod" = "60s",
                          "perSeriesAligner" = "ALIGN_RATE",
                          "crossSeriesReducer" = "REDUCE_SUM",
                          "groupByFields" = ["resource.label.\"url_map_name\"", "metric.label.\"backend_name\""]
                        }
                      },
                      "unitOverride" = "1"
                    },
                    "plotType" = "LINE",
                    "legendTemplate" = "${backend} Error"
                  }
                ]
              ]),
              "timeshiftDuration" = "0s",
              "yAxis" = {
                "label" = "Requests per second",
                "scale" = "LINEAR"
              }
            }
          }
        ] : []
      )
    },
    "refreshSettings" = {
      "refreshRate" = "${var.dashboard_refresh_rate}s"
    }
  })
}

# Create alert policies for monitoring
resource "google_monitoring_alert_policy" "latency_alert" {
  count = var.enable_latency_monitoring ? 1 : 0
  
  display_name = "Load Balancer High Latency Alert"
  combiner     = "OR"
  
  conditions {
    display_name = "High p99 latency"
    condition_threshold {
      filter          = "metric.type=\"loadbalancing.googleapis.com/https/request_latencies\" resource.type=\"https_lb_rule\" resource.label.\"url_map_name\"=\"${var.load_balancer_name}\""
      duration        = "60s"
      comparison      = "COMPARISON_GT"
      threshold_value = var.latency_threshold_ms
      
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_PERCENTILE_99"
        cross_series_reducer = "REDUCE_MEAN"
        group_by_fields      = ["resource.label.url_map_name"]
      }
      
      trigger {
        count = 1
      }
    }
  }
  
  notification_channels = var.alert_notification_channels
  
  documentation {
    content   = "The load balancer ${var.load_balancer_name} is experiencing high latency (p99 > ${var.latency_threshold_ms}ms)."
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "error_rate_alert" {
  count = var.enable_request_count_monitoring ? 1 : 0
  
  display_name = "Load Balancer High Error Rate Alert"
  combiner     = "OR"
  
  conditions {
    display_name = "High error rate"
    condition_threshold {
      filter          = "metric.type=\"loadbalancing.googleapis.com/https/request_count\" resource.type=\"https_lb_rule\" resource.label.\"url_map_name\"=\"${var.load_balancer_name}\" metric.label.\"response_code_class\"!=\"200\""
      duration        = "60s"
      comparison      = "COMPARISON_GT"
      threshold_value = var.error_rate_threshold_percent / 100.0
      
      denominator_filter = "metric.type=\"loadbalancing.googleapis.com/https/request_count\" resource.type=\"https_lb_rule\" resource.label.\"url_map_name\"=\"${var.load_balancer_name}\""
      
      denominator_aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["resource.label.url_map_name"]
      }
      
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["resource.label.url_map_name"]
      }
      
      trigger {
        count = 1
      }
    }
  }
  
  notification_channels = var.alert_notification_channels
  
  documentation {
    content   = "The load balancer ${var.load_balancer_name} is experiencing a high error rate (> ${var.error_rate_threshold_percent}%)."
    mime_type = "text/markdown"
  }
}

# Create Managed Prometheus configuration for backend health monitoring
resource "google_monitoring_metric_descriptor" "backend_health" {
  count = var.enable_backend_health_monitoring ? 1 : 0
  
  description   = "Backend service health percentage"
  display_name  = "Backend Service Health"
  type          = "custom.googleapis.com/loadbalancer/backend_health"
  metric_kind   = "GAUGE"
  value_type    = "DOUBLE"
  unit          = "%"
  
  labels {
    key         = "backend_name"
    value_type  = "STRING"
    description = "Name of the backend service"
  }
  
  labels {
    key         = "region"
    value_type  = "STRING"
    description = "Region of the backend service"
  }
}
