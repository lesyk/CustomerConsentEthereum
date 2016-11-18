variable "netstat_secret" {
    default = "fc3790e391e058a04d6a81aac40e1e51adb675f85a2e0d5c9c95477b22836185ffe5761c4c21f049cdb2b579ff615935"
}

variable "bootnode_enode" {
    default = "53216148b33a67390c2c76a41e5b59af74f5842d2f983d17af66874d007f1d2b62efe6f73872a77a7799ab5b0a6fb4318416c2b8d3b6e7f665676629e2e45da0"
}

variable "miner_etherbase" {
    default = "0x0000000000000000000000000000000000000001"
}

variable "volume_path" {
    default = "/var/lib/enettet-ethereum"
}

variable "docker_host" {
}

provider "docker" {
    host = "tcp://${var.docker_host}:2376"
    cert_path = "docker_0"
}

data "docker_registry_image" "ethereum_node" {
    name = "enettet/ethereum-node:latest"
}

data "docker_registry_image" "ethereum_bootnode" {
    name = "enettet/ethereum-bootnode:latest"
}

data "docker_registry_image" "ethereum_netstats" {
    name = "enettet/ethereum-netstats:latest"
}

data "docker_registry_image" "ethereum_netstats_api" {
    name = "enettet/ethereum-netstats-api:latest"
}

resource "docker_image" "ethereum_node" {
    name = "${data.docker_registry_image.ethereum_node.name}"
    pull_trigger = "${data.docker_registry_image.ethereum_node.sha256_digest}"
}

resource "docker_image" "ethereum_bootnode" {
    name = "${data.docker_registry_image.ethereum_bootnode.name}"
    pull_trigger = "${data.docker_registry_image.ethereum_bootnode.sha256_digest}"
}

resource "docker_image" "ethereum_netstats" {
    name = "${data.docker_registry_image.ethereum_netstats.name}"
    pull_trigger = "${data.docker_registry_image.ethereum_netstats.sha256_digest}"
}

resource "docker_image" "ethereum_netstats_api" {
    name = "${data.docker_registry_image.ethereum_netstats_api.name}"
    pull_trigger = "${data.docker_registry_image.ethereum_netstats_api.sha256_digest}"
}

resource "docker_container" "ethereum_node" {
    count = 2
    image = "${docker_image.ethereum_node.latest}"
    name = "ethereum-node${count.index}"
    hostname = "node${count.index}"
    depends_on = [
        "docker_container.ethereum_bootnode"
    ]
    volumes {
        container_path = "/root/.ethereum"
        host_path = "${var.volume_path}/node${count.index}/ethereum"
    }
    volumes {
        container_path = "/root/.ethash"
        host_path = "${var.volume_path}/node${count.index}/ethash"
    }
    ports {
        internal = "8545"
        external = "${8545 + (10 * count.index)}"
    }
    ports {
        internal = "8546"
        external = "${8546 + (10 * count.index)}"
    }
    links = [
        "${docker_container.ethereum_bootnode.name}:bootnode"
    ]
    command = [
        "--bootnodes=enode://${var.bootnode_enode}@${docker_container.ethereum_bootnode.ip_address}:30301",
        "--lightkdf",
        "--rpc",
        "--rpccorsdomain",
        "'*'",
        "--rpcapi",
        "db,eth,net,web3,personal",
        "--rpcaddr",
        "node${count.index}",
        "--rpcport",
        "8545",
        "--ws",
        "--wsorigins",
        "'*'",
        "--wsaddr",
        "node${count.index}",
        "--wsport",
        "8546",
        "--autodag"
    ]
    must_run = true
    restart = "no"
}

resource "docker_container" "ethereum_miner" {
    count = 0
    image = "${docker_image.ethereum_node.latest}"
    name = "ethereum-miner${count.index}"
    hostname = "miner${count.index}"
    depends_on = [
        "docker_container.ethereum_bootnode"
    ]
    links = [
        "${docker_container.ethereum_bootnode.name}:bootnode"
    ]
    volumes {
        container_path = "/root/.ethereum"
        host_path = "${var.volume_path}/miner${count.index}/ethereum"
    }
    volumes {
        container_path = "/root/.ethash"
        host_path = "${var.volume_path}/miner${count.index}/ethash"
    }
    command = [
        "--bootnodes=enode://${var.bootnode_enode}@${docker_container.ethereum_bootnode.ip_address}:30301",
        "--lightkdf",
        "--mine",
        "--minerthreads=1",
        "--etherbase=${var.miner_etherbase}",
        "--rpc",
        "--rpccorsdomain",
        "'*'",
        "--rpcapi",
        "db,eth,net,web3",
        "--rpcaddr",
        "miner${count.index}",
        "--rpcport",
        "8545"
    ]
    must_run = true
    restart = "no"
}

resource "docker_container" "ethereum_bootnode" {
    image = "${docker_image.ethereum_bootnode.latest}"
    name = "ethereum-bootnode"
    volumes {
        container_path = "/root/.ethereum"
        host_path = "${var.volume_path}/bootnode/ethereum"
    }
    ports {
        internal = 30301
        external = 30301
    }
    command = [
        "-nodekey",
        "/etc/ethereum/boot.key"
    ]
    must_run = true
    restart = "no"
}

resource "docker_container" "ethereum_netstats" {
    image = "${docker_image.ethereum_netstats.latest}"
    name = "ethereum-netstats"
    ports {
        internal = 3000
        external = 3000
    }
    env = [
        "WS_SECRET=${var.netstat_secret}"
    ]
}

resource "docker_container" "ethereum_netstats_api" {
    image = "${docker_image.ethereum_netstats_api.latest}"
    name = "ethereum-netstats-api"
    env = [
        "WS_SECRET=${var.netstat_secret}",
        "WS_SERVER=http://netstats:3000"
    ]
    links = [
        "${docker_container.ethereum_netstats.name}:netstats",
        "${docker_container.ethereum_node.0.name}:node0",
        "${docker_container.ethereum_node.1.name}:node1",
        "${docker_container.ethereum_bootnode.name}:bootnode"
        // "${docker_container.ethereum_miner.0.name}:minernode0",
        // "${docker_container.ethereum_miner.1.name}:minernode1"
    ]
}