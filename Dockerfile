# Migration image for the schedules database.
# It contains Flyway plus this repository's migrations, and exits when done.
# ftx-infra runs it as a one-shot service before ftx-schedules-api starts.
#
# Runtime variables (required): FLYWAY_URL, FLYWAY_USER, FLYWAY_PASSWORD
#
# The Flyway version is pinned so local runs and CI use the same binary.
# Upgrade it deliberately, in its own Pull Request.
FROM flyway/flyway:10.22.0

COPY db/migration /flyway/sql

ENV FLYWAY_LOCATIONS=filesystem:/flyway/sql \
    FLYWAY_SCHEMAS=schedules \
    FLYWAY_CONNECT_RETRIES=10 \
    FLYWAY_VALIDATE_MIGRATION_NAMING=true

CMD ["migrate"]
