FROM mcr.microsoft.com/dotnet/runtime:9.0 AS base
USER $APP_UID
WORKDIR /app

FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
ARG BUILD_CONFIGURATION=Release
WORKDIR /src
COPY --from=dotnetassets "Directory.Packages.props" "."
COPY --from=dotnetassets "Directory.Build.props" "."
COPY --from=dotnetassets "Directory.Build.targets" "."
COPY --from=dotnetassets "nuget.config" "."
COPY "OrderProcessor.csproj" "OrderProcessor/"
COPY --from=servicedefaults "eShop.ServiceDefaults.csproj" "eShop.ServiceDefaults/"
COPY --from=rabbit "EventBusRabbitMQ.csproj" "EventBusRabbitMQ/"
COPY --from=eventbus "EventBus.csproj" "EventBus/"
RUN dotnet restore "./OrderProcessor/OrderProcessor.csproj"
COPY --from=shared "." "./Shared/"
COPY --from=servicedefaults "." "./eShop.ServiceDefaults/"
COPY --from=rabbit "." "./EventBusRabbitMQ/"
COPY --from=eventbus "." "./EventBus/"
COPY "." "./OrderProcessor/"
WORKDIR /src/OrderProcessor
RUN dotnet build "./OrderProcessor.csproj" -c $BUILD_CONFIGURATION -o /app/build --no-restore

FROM build AS publish
ARG BUILD_CONFIGURATION=Release
RUN dotnet publish "./OrderProcessor.csproj" -c $BUILD_CONFIGURATION -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "OrderProcessor.dll"]