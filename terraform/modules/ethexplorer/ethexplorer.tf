variable "docker_host" {
}

variable "docker_cert_path" {
}

variable "link_node" {
}

provider "docker" {
    host = "${var.docker_host}"
    cert_path = "${var.docker_cert_path}"
}

data "docker_registry_image" "consent_ethexplorer" {
    name = "settlemint/ethexplorer:latest"
}

resource "docker_image" "consent_ethexplorer" {
    name = "${data.docker_registry_image.consent_ethexplorer.name}"
    pull_trigger = "${data.docker_registry_image.consent_ethexplorer.sha256_digest}"
}

resource "docker_container" "consent_ethexplorer" {
    image = "${docker_image.consent_ethexplorer.latest}"
    name = "consent-ethexplorer"
    ports {
        internal = 8000
        external = 8000
    }
    env = [
        "WEB3_RPC=http://node0:8545",
    ]
    links = [
        "${var.link_node}:node0",
    ]
    must_run = true
    restart = "always"
}
