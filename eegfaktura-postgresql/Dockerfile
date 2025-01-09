FROM postgres:15-alpine

LABEL org.vfeeg.vendor="Verein zur Förderung von Erneuerbaren Energiegemeinschaften"
LABEL org.vfeeg.image.authors="eegfaktura@vfeeg.org"
LABEL org.opencontainers.image.vendor="Verein zur Förderung von Erneuerbaren Energiegemeinschaften"
LABEL org.opencontainers.image.authors="eegfaktura@vfeeg.org"
LABEL org.opencontainers.image.title="eegfaktura-postgresql"
LABEL org.opencontainers.image.version="0.1.1"
LABEL org.opencontainers.image.description="Database container with initial DB Schema for EEG Faktura"
LABEL org.opencontainers.image.licenses="AGPL-3.0"
LABEL org.opencontainers.image.source="https://github.com/eegfaktura/eegfaktura-docker-compose"
LABEL org.opencontainers.image.base.name="docker.io/postgres:15-alpine"
LABEL description="Database container with initial DB Schema for EEG Faktura"
LABEL version="0.1.1"

# Install necessary packages and set locales
RUN apk add --no-cache \
    bash \
    icu-libs \
    libc6-compat \
    musl-locales \
    gcompat \
    libintl

# Set the locale environment variables
ENV MUSL_LOCPATH="/usr/share/i18n/locales/musl" \
    LANG=de_DE.UTF-8 \
    LANGUAGE=de_DE:de \
    LC_ALL=de_DE.UTF-8

# Copy initialization scripts
COPY --chown=postgres:postgres docker-entrypoint-initdb.d/* /docker-entrypoint-initdb.d

# Environment variables
ENV DB_DATABASE="eegfaktura"
ENV DB_USER="eegfaktura"

# Expose the PostgreSQL port
EXPOSE 5432