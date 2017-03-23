terragrunt = {
  lock {
    backend = "dynamodb"
    config {
      state_file_id = "${path_relative_to_include()}"
    }
  }

  remote_state {
    backend = "s3"
    config = {
      encrypt = "true"
      bucket = "cc-terraform-state"
      key = "${path_relative_to_include()}/terraform.tfstate"
      region = "us-east-1"
    }
  }
}
