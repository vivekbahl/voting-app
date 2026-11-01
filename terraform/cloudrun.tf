resource "google_service_account" "app" {
  account_id   = "${var.name_prefix}-run"
  display_name = "Voting app runtime"

  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_iam_member" "app_db_password" {
  secret_id = google_secret_manager_secret.db_password.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.app.email}"
}

locals {
  db_host    = google_sql_database_instance.main.private_ip_address
  redis_host = google_redis_instance.main.host
}

resource "google_cloud_run_v2_service" "vote" {
  name                = "${var.name_prefix}-vote"
  location            = var.region
  ingress             = "INGRESS_TRAFFIC_ALL"
  deletion_protection = false

  template {
    service_account = google_service_account.app.email

    scaling {
      min_instance_count = 0
      max_instance_count = var.web_max_instances
    }

    vpc_access {
      egress = "PRIVATE_RANGES_ONLY"
      network_interfaces {
        network    = google_compute_network.main.id
        subnetwork = google_compute_subnetwork.main.id
      }
    }

    containers {
      image = local.images["vote"]

      ports {
        container_port = 80
      }

      env {
        name  = "REDIS_HOST"
        value = local.redis_host
      }
      env {
        name  = "OPTION_A"
        value = var.option_a
      }
      env {
        name  = "OPTION_B"
        value = var.option_b
      }
    }
  }

  depends_on = [terraform_data.build, google_redis_instance.main]
}

resource "google_cloud_run_v2_service" "result" {
  name                = "${var.name_prefix}-result"
  location            = var.region
  ingress             = "INGRESS_TRAFFIC_ALL"
  deletion_protection = false

  template {
    service_account = google_service_account.app.email
    # Socket.IO connections are long-lived; keep them pinned to one instance.
    session_affinity = true
    timeout          = "3600s"

    scaling {
      min_instance_count = 0
      max_instance_count = var.web_max_instances
    }

    vpc_access {
      egress = "PRIVATE_RANGES_ONLY"
      network_interfaces {
        network    = google_compute_network.main.id
        subnetwork = google_compute_subnetwork.main.id
      }
    }

    containers {
      image = local.images["result"]

      ports {
        container_port = 80
      }

      env {
        name  = "DB_HOST"
        value = local.db_host
      }
      env {
        name = "DB_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.db_password.secret_id
            version = "latest"
          }
        }
      }
    }
  }

  depends_on = [
    terraform_data.build,
    google_sql_user.postgres,
    google_secret_manager_secret_version.db_password,
    google_secret_manager_secret_iam_member.app_db_password,
  ]
}

# The worker has no HTTP port, so it runs as a Cloud Run worker pool (always-on background process).
resource "google_cloud_run_v2_worker_pool" "worker" {
  name                = "${var.name_prefix}-worker"
  location            = var.region
  deletion_protection = false

  scaling {
    scaling_mode          = "MANUAL"
    manual_instance_count = 1
  }

  template {
    service_account = google_service_account.app.email

    vpc_access {
      egress = "PRIVATE_RANGES_ONLY"
      network_interfaces {
        network    = google_compute_network.main.id
        subnetwork = google_compute_subnetwork.main.id
      }
    }

    containers {
      image = local.images["worker"]

      env {
        name  = "REDIS_HOST"
        value = local.redis_host
      }
      env {
        name  = "DB_HOST"
        value = local.db_host
      }
      env {
        name = "DB_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.db_password.secret_id
            version = "latest"
          }
        }
      }
    }
  }

  depends_on = [
    terraform_data.build,
    google_redis_instance.main,
    google_sql_user.postgres,
    google_secret_manager_secret_version.db_password,
    google_secret_manager_secret_iam_member.app_db_password,
  ]
}

resource "google_cloud_run_v2_service_iam_member" "public" {
  for_each = var.allow_public_access ? {
    vote   = google_cloud_run_v2_service.vote.name
    result = google_cloud_run_v2_service.result.name
  } : {}

  location = var.region
  name     = each.value
  role     = "roles/run.invoker"
  member   = "allUsers"
}
