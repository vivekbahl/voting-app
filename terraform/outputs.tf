output "vote_url" {
  description = "Where people vote."
  value       = google_cloud_run_v2_service.vote.uri
}

output "result_url" {
  description = "Live results page."
  value       = google_cloud_run_v2_service.result.uri
}

output "artifact_registry" {
  value = local.registry
}

output "cloud_sql_private_ip" {
  value = local.db_host
}

output "redis_host" {
  value = local.redis_host
}
