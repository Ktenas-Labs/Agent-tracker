FROM debian:bookworm-slim AS build

RUN apt-get update && apt-get install -y curl unzip xz-utils git ca-certificates && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 --branch stable https://github.com/flutter/flutter.git /opt/flutter
ENV PATH="/opt/flutter/bin:${PATH}"

WORKDIR /app
COPY . .
RUN flutter config --enable-web --no-analytics \
    && flutter pub get \
    && flutter build web --release

FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 8080
