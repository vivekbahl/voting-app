resource "google_artifact_registry_repository" "main" {
  repository_id = var.name_prefix
  location      = var.region
  format        = "DOCKER"

  depends_on = [google_project_service.apis]
}

# Dedicated identity for Cloud Build so we don't depend on project-default build permissions.
resource "google_service_account" "build" {
  account_id   = "${var.name_prefix}-build"
  display_name = "Voting app image builder"

  depends_on = [google_project_service.apis]
}

resource "google_project_iam_member" "build" {
  for_each = toset([
    "roles/artifactregistry.writer",
    "roles/logging.logWriter",
    "roles/storage.objectViewer", # read the uploaded build source
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.build.email}"
}

locals {
  registry = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.main.repository_id}"

  services = {
    vote   = "${path.module}/../vote"
    result = "${path.module}/../result"
    worker = "${path.module}/../worker"
  }

  # Tag images by a hash of their sources so code changes roll out new Cloud Run revisions.
  source_hash = {
    for name, dir in local.services : name => substr(sha1(join("", [
      for f in sort(fileset(dir, "**")) : filesha1("${dir}/${f}")
      if !startswith(f, "obj/") && !startswith(f, "bin/") && !startswith(f, "node_modules/")
    ])), 0, 12)
  }

  images = { for name in keys(local.services) : name => "${local.registry}/${name}:${local.source_hash[name]}" }
}

# Builds each image with Cloud Build (BuildKit is needed for the worker's multi-platform Dockerfile).
resource "terraform_data" "build" {
  for_each = local.services

  triggers_replace = [local.images[each.key]]

  provisioner "local-exec" {
    command = "gcloud builds submit ${each.value} --project ${var.project_id} --region ${var.region} --config ${path.module}/cloudbuild.yaml --service-account ${google_service_account.build.id} --substitutions _IMAGE=${local.images[each.key]}"
  }

  depends_on = [google_project_iam_member.build]
}
