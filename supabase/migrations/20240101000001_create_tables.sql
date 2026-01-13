CREATE TABLE countries (
    country_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    country_name VARCHAR(100) NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE application_types (
    application_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    application_type_title VARCHAR(100) NOT NULL UNIQUE,
    application_fees DECIMAL(10, 4) NOT NULL DEFAULT 0 CHECK (application_fees >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE application_statuses (
    application_status_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    application_status_title VARCHAR(50) NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE license_classes (
    license_class_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    class_name VARCHAR(50) NOT NULL UNIQUE,
    class_description TEXT NOT NULL,
    minimum_allowed_age SMALLINT NOT NULL DEFAULT 18 CHECK (minimum_allowed_age >= 16 AND minimum_allowed_age <= 100),
    default_validity_length SMALLINT NOT NULL DEFAULT 1 CHECK (default_validity_length > 0),
    class_fees DECIMAL(10, 4) NOT NULL DEFAULT 0 CHECK (class_fees >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE test_types (
    test_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    test_type_title VARCHAR(100) NOT NULL UNIQUE,
    test_type_description TEXT NOT NULL,
    test_type_fees DECIMAL(10, 4) NOT NULL CHECK (test_type_fees >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE issue_reasons (
    issue_reason_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reason_name VARCHAR(100) NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE drivers (
    driver_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    date_of_birth TIMESTAMPTZ NOT NULL CHECK (date_of_birth < NOW()),
    national_number VARCHAR(50) NOT NULL UNIQUE,
    is_female BOOLEAN NOT NULL DEFAULT FALSE,
    address TEXT NOT NULL,
    phone VARCHAR(20) NOT NULL CHECK (phone ~ '^\+?[0-9\s\-\(\)]{10,20}$'),
    email VARCHAR(255) UNIQUE CHECK (email IS NULL OR email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    country_id UUID NOT NULL REFERENCES countries(country_id) ON DELETE RESTRICT,
    avatar TEXT,
    created_by_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ,
    updated_by_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

CREATE TABLE applications (
    application_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    driver_id UUID REFERENCES drivers(driver_id) ON DELETE SET NULL,
    application_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    application_type_id UUID NOT NULL REFERENCES application_types(application_type_id) ON DELETE RESTRICT,
    application_status_id UUID NOT NULL REFERENCES application_statuses(application_status_id) ON DELETE RESTRICT,
    last_status_date TIMESTAMPTZ NOT NULL DEFAULT NOW() CHECK (last_status_date >= application_date),
    paid_fees DECIMAL(10, 4) NOT NULL CHECK (paid_fees >= 0),
    created_by_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ,
    updated_by_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

CREATE TABLE local_driving_license_applications (
    local_driving_license_application_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    application_id UUID NOT NULL REFERENCES applications(application_id) ON DELETE CASCADE UNIQUE,
    license_class_id UUID NOT NULL REFERENCES license_classes(license_class_id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE test_appointments (
    test_appointment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    test_type_id UUID NOT NULL REFERENCES test_types(test_type_id) ON DELETE RESTRICT,
    local_driving_license_application_id UUID NOT NULL REFERENCES local_driving_license_applications(local_driving_license_application_id) ON DELETE CASCADE,
    appointment_date TIMESTAMPTZ NOT NULL,
    paid_fees DECIMAL(10, 4) NOT NULL CHECK (paid_fees >= 0),
    created_by_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
    is_locked BOOLEAN NOT NULL DEFAULT FALSE,
    retake_test_application_id UUID REFERENCES applications(application_id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ,
    updated_by_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    CONSTRAINT test_appointments_date_check CHECK (appointment_date >= created_at)
);

CREATE TABLE tests (
    test_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    test_appointment_id UUID NOT NULL REFERENCES test_appointments(test_appointment_id) ON DELETE CASCADE UNIQUE,
    is_test_passed BOOLEAN NOT NULL,
    notes TEXT,
    created_by_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE licenses (
    license_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    application_id UUID NOT NULL REFERENCES applications(application_id) ON DELETE RESTRICT,
    driver_id UUID NOT NULL REFERENCES drivers(driver_id) ON DELETE RESTRICT,
    license_class_id UUID NOT NULL REFERENCES license_classes(license_class_id) ON DELETE RESTRICT,
    issue_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expiration_date TIMESTAMPTZ NOT NULL CHECK (expiration_date > issue_date),
    notes TEXT,
    paid_fees DECIMAL(10, 4) NOT NULL CHECK (paid_fees >= 0),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    issue_reason_id UUID NOT NULL REFERENCES issue_reasons(issue_reason_id) ON DELETE RESTRICT,
    created_by_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ,
    updated_by_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

CREATE TABLE detained_licenses (
    detain_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    license_id UUID NOT NULL REFERENCES licenses(license_id) ON DELETE CASCADE,
    detain_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    fine_fees DECIMAL(10, 4) NOT NULL CHECK (fine_fees >= 0),
    created_by_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
    is_released BOOLEAN NOT NULL DEFAULT FALSE,
    release_date TIMESTAMPTZ CHECK (release_date IS NULL OR release_date >= detain_date),
    released_by_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    release_application_id UUID REFERENCES applications(application_id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ,
    updated_by_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    CONSTRAINT detained_licenses_release_check CHECK (
        (is_released = FALSE AND release_date IS NULL AND released_by_user_id IS NULL)
        OR (is_released = TRUE AND release_date IS NOT NULL AND released_by_user_id IS NOT NULL)
    )
);

CREATE TABLE international_licenses (
    international_license_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    application_id UUID NOT NULL REFERENCES applications(application_id) ON DELETE RESTRICT,
    driver_id UUID NOT NULL REFERENCES drivers(driver_id) ON DELETE RESTRICT,
    issued_using_local_license_id UUID NOT NULL REFERENCES licenses(license_id) ON DELETE RESTRICT,
    issue_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expiration_date TIMESTAMPTZ NOT NULL CHECK (expiration_date > issue_date),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_by_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ,
    updated_by_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_drivers_updated_at BEFORE UPDATE ON drivers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_applications_updated_at BEFORE UPDATE ON applications
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_test_appointments_updated_at BEFORE UPDATE ON test_appointments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_licenses_updated_at BEFORE UPDATE ON licenses
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_detained_licenses_updated_at BEFORE UPDATE ON detained_licenses
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_international_licenses_updated_at BEFORE UPDATE ON international_licenses
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
