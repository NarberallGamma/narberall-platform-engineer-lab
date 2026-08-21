
CREATE DATABASE notification;

DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'postgres') THEN
        CREATE USER postgres WITH ENCRYPTED PASSWORD 'CHANGE_ME';
END IF;
END
$$;

GRANT ALL PRIVILEGES ON DATABASE notification TO postgres;

CREATE DATABASE tariff;

GRANT ALL PRIVILEGES ON DATABASE tariff TO postgres;