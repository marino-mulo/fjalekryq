# ── Stage 1: Build Angular frontend ──
FROM node:22-alpine AS frontend-build
WORKDIR /app/client
COPY fjalekryq-client/package*.json ./
RUN npm ci
COPY fjalekryq-client/ ./
RUN npx ng build --configuration production

# ── Stage 2: Build .NET backend ──
FROM mcr.microsoft.com/dotnet/sdk:9.0-alpine AS backend-build
WORKDIR /app
COPY Fjalekryq.Api/ ./
RUN dotnet publish -c Release -o /publish

# ── Stage 3: Final runtime image ──
FROM mcr.microsoft.com/dotnet/aspnet:9.0-alpine AS runtime
WORKDIR /app

COPY --from=backend-build /publish ./

# Copy Angular build output into wwwroot
COPY --from=frontend-build /app/client/dist/fjalekryq-client/browser/ ./wwwroot/

# Railway injects PORT env var at runtime
ENV PORT=8080
ENV ASPNETCORE_ENVIRONMENT=Production
EXPOSE 8080

# Use shell form so $PORT is resolved at runtime
CMD ASPNETCORE_HTTP_PORTS=$PORT dotnet Fjalekryq.Api.dll
