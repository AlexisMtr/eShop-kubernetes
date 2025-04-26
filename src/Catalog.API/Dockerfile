# See https://aka.ms/customizecontainer to learn how to customize your debug container and how Visual Studio uses this Dockerfile to build your images for faster debugging.

# This stage is used when running from VS in fast mode (Default for Debug configuration)
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS base
USER $APP_UID
WORKDIR /app
EXPOSE 8080


# This stage is used to build the service project
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
ARG BUILD_CONFIGURATION=Release
WORKDIR /src
COPY --from=dotnetassets "Directory.Packages.props" "."
COPY --from=dotnetassets "Directory.Build.props" "."
COPY --from=dotnetassets "Directory.Build.targets" "."
COPY --from=dotnetassets "nuget.config" "."
COPY "Catalog.API.csproj" "./Catalog.API/"
COPY --from=rabbit "EventBusRabbitMQ.csproj" "./EventBusRabbitMQ/"
COPY --from=eventbus "EventBus.csproj" "./EventBus/"
COPY --from=eflogs "IntegrationEventLogEF.csproj" "./IntegrationEventLogEF/"
COPY --from=servicedefaults "eShop.ServiceDefaults.csproj" "./eShop.ServiceDefaults/"
RUN dotnet restore "./Catalog.API/Catalog.API.csproj"
COPY "." "./Catalog.API/"
COPY --from=shared "." "./Shared/"
COPY --from=servicedefaults "." "./eShop.ServiceDefaults/"
COPY --from=rabbit "." "./EventBusRabbitMQ/"
COPY --from=eventbus "." "./EventBus/"
COPY --from=eflogs "." "./IntegrationEventLogEF/"
WORKDIR /src/Catalog.API
RUN dotnet build "./Catalog.API.csproj" -c $BUILD_CONFIGURATION -o /app/build --no-restore

# This stage is used to publish the service project to be copied to the final stage
FROM build AS publish
ARG BUILD_CONFIGURATION=Release
RUN dotnet publish "./Catalog.API.csproj" -c $BUILD_CONFIGURATION -o /app/publish /p:UseAppHost=false

# This stage is used in production or when running from VS in regular mode (Default when not using the Debug configuration)
FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "Catalog.API.dll"]