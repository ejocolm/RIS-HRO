# =============================================================
# RIS HRO - ASP.NET Core .NET 10
# Imagen multi-stage para producción (Linux)
# =============================================================

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS base
WORKDIR /app

# Desde .NET 8 las imágenes ASP.NET Core escuchan normalmente en 8080.
ENV ASPNETCORE_HTTP_PORTS=8080 \
    DOTNET_RUNNING_IN_CONTAINER=true \
    TZ=America/Guatemala

EXPOSE 8080

# curl: healthcheck
# tzdata: asegura zona horaria America/Guatemala
# fonts-liberation2: fuentes libres usadas por el resolver de PDFsharp en Linux
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
       curl \
       tzdata \
       fonts-liberation2 \
    && rm -rf /var/lib/apt/lists/*

FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
ARG BUILD_CONFIGURATION=Release
WORKDIR /src

# Copiar primero el proyecto para aprovechar cache de restore.
COPY ["RIS_HRO.csproj", "./"]
RUN dotnet restore "RIS_HRO.csproj"

# Copiar el resto del código fuente.
COPY . .

RUN dotnet build "RIS_HRO.csproj" \
    -c $BUILD_CONFIGURATION \
    -o /app/build \
    --no-restore

FROM build AS publish
ARG BUILD_CONFIGURATION=Release
RUN dotnet publish "RIS_HRO.csproj" \
    -c $BUILD_CONFIGURATION \
    -o /app/publish \
    --no-restore \
    /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .

ENTRYPOINT ["dotnet", "RIS_HRO.dll"]
