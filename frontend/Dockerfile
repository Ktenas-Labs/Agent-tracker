# Production: prebuilt Flutter SDK (no git clone — faster, reliable multi-arch builds)
FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app

COPY pubspec.yaml ./
RUN flutter config --enable-web --no-analytics \
    && flutter pub get

COPY . .
RUN flutter pub get \
    && flutter build web --release

FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 8080
