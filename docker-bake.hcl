variable "TAG"  {
  default = "wolfy"
}

variable "DOCKER_REGISTRY" {
  default = "localhost:5000"
}

variable "BUILD_CONFIGURATION" {
  default = "Release"
}

variable "DOTNET_9_BASE" {
  default = "mcr.microsoft.com/dotnet/aspnet:9.0"
}

variable "DONET_9_WOLFY" {
  default = "cgr.dev/chainguard/aspnet-runtime:latest@sha256:408222a69d6369710188788c4282949ac52154a36454f5ae9e8552170aeecba1"
}

target "_eshop_base" {
  args = {
    BUILD_CONFIGURATION = "${BUILD_CONFIGURATION}"
  }
  contexts = {
    dotnetassets = "."
    servicedefaults = "./src/eShop.ServiceDefaults/"
    shared = "./src/Shared/"
    rabbit = "./src/EventBusRabbitMQ/"
    eventbus = "./src/EventBus/"
    "${DOTNET_9_BASE}" = "docker-image://${DONET_9_WOLFY}"
  }
}

target "Basket" {
  inherits = [
    "_eshop_base"
  ]
  context = "./src/Basket.API/"
  tags = [
    "${DOCKER_REGISTRY}/docker/basket:${TAG}",
    "${DOCKER_REGISTRY}/docker/basket:latest"
  ]
}

target "Identity" {
  context = "./src/Identity.API/"
  contexts = {
    dotnetassets = "."
    servicedefaults = "./src/eShop.ServiceDefaults/"
    shared = "./src/Shared/"
    "${DOTNET_9_BASE}" = "docker-image://${DONET_9_WOLFY}"
  }
  args = {
    BUILD_CONFIGURATION = "${BUILD_CONFIGURATION}"
  }
  tags = [
    "${DOCKER_REGISTRY}/docker/identity:${TAG}",
    "${DOCKER_REGISTRY}/docker/identity:latest"
  ]
}

target "Catalog" {
  inherits = [
    "_eshop_base"
  ]
  context = "./src/Catalog.API/"
  contexts = {
    eflogs = "./src/IntegrationEventLogEF/"
  }
  tags = [
    "${DOCKER_REGISTRY}/docker/catalog:${TAG}",
    "${DOCKER_REGISTRY}/docker/catalog:latest"
  ]
}

target "Ordering" {
  inherits = [
    "_eshop_base"
  ]
  context = "./src/Ordering.API/"
  contexts = {
    eflogs = "./src/IntegrationEventLogEF/"
    domain = "./src/Ordering.Domain/"
    infra = "./src/Ordering.Infrastructure/"
  }
  tags = [
    "${DOCKER_REGISTRY}/docker/ordering:${TAG}",
    "${DOCKER_REGISTRY}/docker/ordering:latest"
  ]
}

target "OrderProcessor" {
  inherits = [
    "_eshop_base"
  ]
  context = "./src/OrderProcessor/"
  tags = [
    "${DOCKER_REGISTRY}/docker/orderprocessor:${TAG}",
    "${DOCKER_REGISTRY}/docker/orderprocessor:latest"
  ]
}

target "PaymentProcessor" {
  inherits = [
    "_eshop_base"
  ]
  context = "./src/PaymentProcessor/"
  args = {
    BUILD_CONFIGURATION = "${BUILD_CONFIGURATION}"
  }
  tags = [
    "${DOCKER_REGISTRY}/docker/paymentprocessor:${TAG}",
    "${DOCKER_REGISTRY}/docker/paymentprocessor:latest"
  ]
}

target "Webhook" {
  inherits = [
    "_eshop_base"
  ]
  context = "./src/Webhooks.API/"
  contexts = {
    eflogs = "./src/IntegrationEventLogEF/"
  }
  tags = [
    "${DOCKER_REGISTRY}/docker/webhook:${TAG}",
    "${DOCKER_REGISTRY}/docker/webhook:latest"
  ]
}

target "WebApp" {
  inherits = [
    "_eshop_base"
  ]
  context = "./src/WebApp/"
  contexts = {
    webcomponents = "./src/WebAppComponents/"
    basketproto = "./src/Basket.API/Proto/"
  }
  tags = [
    "${DOCKER_REGISTRY}/docker/webapp:${TAG}",
    "${DOCKER_REGISTRY}/docker/webapp:latest"
  ]
}

target "cnpg_vector" {
  dockerfile-inline = <<EOF
FROM ghcr.io/cloudnative-pg/postgresql:17.4
USER root

RUN apt update; \
    apt install postgresql-17-pgvector -y; \
    rm -fr /tmp/* ; \
    rm -rf /var/lib/apt/lists/*;

USER 26
EOF
  tags = [
    "${DOCKER_REGISTRY}/docker/postgresql:17.4-pgvector"
  ]
}

group "default" {
  targets = [
    "Basket",
    "Identity",
    "Catalog",
    "Ordering",
    "OrderProcessor",
    "PaymentProcessor",
    "Webhook",
    "WebApp"
  ]
}