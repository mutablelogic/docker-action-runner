
/*
    Nomad job file for github action runners. Change
    the variables, and don't include your secrets (access_token)
    in this file.
*/

variable "access_token" {
  type = string
}

variable "github_username" {
  type = string
}

variable "organization" {
  type = string
  default = "mutablelogic"
}

variable "datacenters" {
  type = list(string)
  default = [ "10707" ]
}

variable "image" {
  type = string
  default = "ghcr.io/mutablelogic/runner-image"
}


job "action-runner" {
  type         = "system"
  datacenters  = var.datacenters

  task "runner" {
    driver = "docker"

    env {
      ORGANIZATION = var.organization
      NAME         = node.unique.name
      LABELS       = node.datacenter
      ACCESS_TOKEN = var.access_token
    }

    config {
      image       = var.image
      auth {
        username  = var.github_username
        password  = var.access_token
      }
      privileged  = true
      userns_mode = "host"
      volumes = [
        "/var/run/docker.sock:/var/run/docker.sock",
      ]
    }
  }
}
