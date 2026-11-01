resource "random_id" "db_suffix" {
  byte_length = 3
}

resource "random_password" "db" {
  length  = 32
  special = false
}

resource "google_sql_database_instance" "main" {
  # Instance names can't be reused for ~a week after deletion, hence the suffix.
  name                = "${var.name_prefix}-pg-${random_id.db_suffix.hex}"
  region              = var.region
  database_version    = "POSTGRES_15"
  deletion_protection = var.deletion_protection

  settings {
    tier    = var.db_tier
    edition = "ENTERPRISE"

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.main.id
    }
  }

  depends_on = [google_service_networking_connection.private_services]
}

# The app uses the default "postgres" database and user; the worker creates the votes table.
resource "google_sql_user" "postgres" {
  name     = "postgres"
  instance = google_sql_database_instance.main.name
  password = random_password.db.result
}

resource "google_redis_instance" "main" {
  name               = "${var.name_prefix}-redis"
  region             = var.region
  tier               = "BASIC"
  memory_size_gb     = var.redis_memory_size_gb
  redis_version      = "REDIS_7_0"
  authorized_network = google_compute_network.main.id
  connect_mode       = "PRIVATE_SERVICE_ACCESS"

  depends_on = [google_service_networking_connection.private_services]
}

resource "google_secret_manager_secret" "db_password" {
  secret_id = "${var.name_prefix}-db-password"

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = random_password.db.result
}
