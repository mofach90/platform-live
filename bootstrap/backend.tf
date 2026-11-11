terraform {
  backend "gcs" {
    bucket = "platform-project-dev-514319-tfstate"
    prefix = "bootstrap"
  }
}