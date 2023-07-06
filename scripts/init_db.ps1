try {
    Invoke-Expression -Command "psql --version" -ErrorAction Stop
}
catch {
    Write-Host "psql is not installed" -ForegroundColor Red
    Write-Host "Make sure postgresql command line tools are installed and 'C:\Program Files\PostgreSQL\15\bin' is added to PATH"
    Exit
}

try {
    Invoke-Expression -Command "sqlx --version" -ErrorAction Stop
}
catch {
    Write-Host "sqlx is not installed" -ForegroundColor Red
    Write-Host "Make sure sqlx is installed, install with 'cargo install --version="~0.6" sqlx-cli --no-default-features --features rustls,postgres'"
    Exit
}

$DB_USER = "postgres"
$DB_PASSWORD = "password"
$DB_NAME = "newsletter"
$DB_PORT = "5432"
$DB_HOST = "localhost"

try {
    $Response = Invoke-Expression "docker run --name newsletter-db -e POSTGRES_USER=${DB_USER} -e POSTGRES_PASSWORD=${DB_PASSWORD} -e POSTGRES_DB=${DB_NAME} -p ${DB_PORT}:5432 -d postgres postgres -N 1000 2>&1"

    if ($Response -like "*is already in use*") {
        throw "Docker container with name '${DB_NAME}' already exists."
    }
}
catch {
    Write-Host $_ -ForegroundColor Red
    Write-Host "Failed to start Postgres container." -ForegroundColor Red
    Exit
}

# Keep pinging Postgres until it's ready to accept commands
$env:PGPASSWORD = "${DB_PASSWORD}"
do {
    try {
        # Attempt to connect to the database
        psql -h "${DB_HOST}" -U "${DB_USER}" -p "${DB_PORT}" -d "postgres" -c '\q' -ErrorAction Stop
    }
    catch {
        # If there is an exception, sleep for a bit and then try again
        Write-Host "Postgres is still unavailable - sleeping" -ForegroundColor Yellow
        Start-Sleep -Seconds 1
        continue
    }
    # If no exception, break the loop
    break
} while ($true)

Write-Host "Postgres is up and running on port ${DB_PORT}!" -ForegroundColor Green

$DATABASE_URL = "postgres://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}"
$env:DATABASE_URL = $DATABASE_URL
sqlx database create
