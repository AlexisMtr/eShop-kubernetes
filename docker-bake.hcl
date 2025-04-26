variable "TAG"  {
  default = "latest"
}

variable "DOCKER_REGISTRY" {
  default = "localhost:5000"
}

variable "BUILD_CONFIGURATION" {
  default = "Release"
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