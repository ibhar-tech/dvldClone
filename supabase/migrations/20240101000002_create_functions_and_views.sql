CREATE OR REPLACE FUNCTION get_driver_full_name(
    p_first_name VARCHAR,
    p_last_name VARCHAR
)
RETURNS TEXT AS $$
BEGIN
    RETURN CONCAT(p_first_name, ' ', p_last_name);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION get_detained_licenses(
    p_is_released BOOLEAN DEFAULT NULL,
    p_driver_id UUID DEFAULT NULL
)
RETURNS TABLE (
    detain_id UUID,
    license_id UUID,
    detain_date TIMESTAMPTZ,
    is_released BOOLEAN,
    fine_fees DECIMAL(10, 4),
    release_date TIMESTAMPTZ,
    release_application_id UUID,
    driver_id UUID,
    national_number VARCHAR(50),
    full_name TEXT,
    license_class_id UUID,
    class_name VARCHAR(50),
    created_by_user_id UUID,
    released_by_user_id UUID
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        dl.detain_id,
        dl.license_id,
        dl.detain_date,
        dl.is_released,
        dl.fine_fees,
        dl.release_date,
        dl.release_application_id,
        d.driver_id,
        d.national_number,
        get_driver_full_name(d.first_name, d.last_name) AS full_name,
        l.license_class_id,
        lc.class_name,
        dl.created_by_user_id,
        dl.released_by_user_id
    FROM detained_licenses dl
    JOIN licenses l ON dl.license_id = l.license_id
    JOIN drivers d ON l.driver_id = d.driver_id
    JOIN license_classes lc ON l.license_class_id = lc.license_class_id
    WHERE (p_is_released IS NULL OR dl.is_released = p_is_released)
      AND (p_driver_id IS NULL OR d.driver_id = p_driver_id)
    ORDER BY dl.detain_date DESC;
END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION get_local_driving_license_full_applications(
    p_driver_id UUID DEFAULT NULL,
    p_application_status_id UUID DEFAULT NULL
)
RETURNS TABLE (
    application_id UUID,
    driver_id UUID,
    national_number VARCHAR(50),
    driver_full_name TEXT,
    application_date TIMESTAMPTZ,
    application_type_id UUID,
    application_type_title VARCHAR(100),
    application_status_id UUID,
    application_status_title VARCHAR(50),
    last_status_date TIMESTAMPTZ,
    paid_fees DECIMAL(10, 4),
    created_by_user_id UUID,
    local_driving_license_application_id UUID,
    license_class_id UUID,
    class_name VARCHAR(50)
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        a.application_id,
        a.driver_id,
        d.national_number,
        get_driver_full_name(d.first_name, d.last_name) AS driver_full_name,
        a.application_date,
        a.application_type_id,
        at.application_type_title,
        a.application_status_id,
        ast.application_status_title,
        a.last_status_date,
        a.paid_fees,
        a.created_by_user_id,
        ldla.local_driving_license_application_id,
        ldla.license_class_id,
        lc.class_name
    FROM applications a
    JOIN local_driving_license_applications ldla ON a.application_id = ldla.application_id
    JOIN drivers d ON a.driver_id = d.driver_id
    JOIN application_types at ON a.application_type_id = at.application_type_id
    JOIN application_statuses ast ON a.application_status_id = ast.application_status_id
    JOIN license_classes lc ON ldla.license_class_id = lc.license_class_id
    WHERE (p_driver_id IS NULL OR a.driver_id = p_driver_id)
      AND (p_application_status_id IS NULL OR a.application_status_id = p_application_status_id)
    ORDER BY a.application_date DESC;
END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION get_local_driving_license_applications(
    p_driver_id UUID DEFAULT NULL,
    p_application_status_id UUID DEFAULT NULL,
    p_license_class_id UUID DEFAULT NULL
)
RETURNS TABLE (
    local_driving_license_application_id UUID,
    application_id UUID,
    driver_id UUID,
    national_number VARCHAR(50),
    full_name TEXT,
    application_date TIMESTAMPTZ,
    application_type_id UUID,
    application_type_title VARCHAR(100),
    application_status_id UUID,
    status VARCHAR(50),
    last_status_date TIMESTAMPTZ,
    paid_fees DECIMAL(10, 4),
    license_class_id UUID,
    class_name VARCHAR(50),
    passed_test_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        ldla.local_driving_license_application_id,
        a.application_id,
        a.driver_id,
        d.national_number,
        get_driver_full_name(d.first_name, d.last_name) AS full_name,
        a.application_date,
        a.application_type_id,
        at.application_type_title,
        a.application_status_id,
        ast.application_status_title AS status,
        a.last_status_date,
        a.paid_fees,
        ldla.license_class_id,
        lc.class_name,
        COALESCE(tc.passed_count, 0) AS passed_test_count
    FROM local_driving_license_applications ldla
    JOIN applications a ON ldla.application_id = a.application_id
    JOIN drivers d ON a.driver_id = d.driver_id
    JOIN license_classes lc ON ldla.license_class_id = lc.license_class_id
    JOIN application_types at ON a.application_type_id = at.application_type_id
    JOIN application_statuses ast ON a.application_status_id = ast.application_status_id
    LEFT JOIN (
        SELECT ta.local_driving_license_application_id, COUNT(*) as passed_count
        FROM tests t
        JOIN test_appointments ta ON t.test_appointment_id = ta.test_appointment_id
        WHERE t.is_test_passed = TRUE
        GROUP BY ta.local_driving_license_application_id
    ) tc ON ldla.local_driving_license_application_id = tc.local_driving_license_application_id
    WHERE (p_driver_id IS NULL OR a.driver_id = p_driver_id)
      AND (p_application_status_id IS NULL OR a.application_status_id = p_application_status_id)
      AND (p_license_class_id IS NULL OR ldla.license_class_id = p_license_class_id)
    ORDER BY a.application_date DESC;
END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION get_test_appointments(
    p_driver_id UUID DEFAULT NULL,
    p_test_type_id UUID DEFAULT NULL,
    p_is_locked BOOLEAN DEFAULT NULL,
    p_from_date TIMESTAMPTZ DEFAULT NULL,
    p_to_date TIMESTAMPTZ DEFAULT NULL
)
RETURNS TABLE (
    test_appointment_id UUID,
    test_type_id UUID,
    test_type_title VARCHAR(100),
    local_driving_license_application_id UUID,
    application_id UUID,
    driver_id UUID,
    national_number VARCHAR(50),
    full_name TEXT,
    license_class_id UUID,
    class_name VARCHAR(50),
    appointment_date TIMESTAMPTZ,
    paid_fees DECIMAL(10, 4),
    is_locked BOOLEAN,
    retake_test_application_id UUID,
    created_by_user_id UUID,
    has_test_result BOOLEAN,
    is_test_passed BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        ta.test_appointment_id,
        ta.test_type_id,
        tt.test_type_title,
        ta.local_driving_license_application_id,
        ldla.application_id,
        a.driver_id,
        d.national_number,
        get_driver_full_name(d.first_name, d.last_name) AS full_name,
        ldla.license_class_id,
        lc.class_name,
        ta.appointment_date,
        ta.paid_fees,
        ta.is_locked,
        ta.retake_test_application_id,
        ta.created_by_user_id,
        (t.test_id IS NOT NULL) AS has_test_result,
        t.is_test_passed
    FROM test_appointments ta
    JOIN test_types tt ON ta.test_type_id = tt.test_type_id
    JOIN local_driving_license_applications ldla ON ta.local_driving_license_application_id = ldla.local_driving_license_application_id
    JOIN applications a ON ldla.application_id = a.application_id
    JOIN drivers d ON a.driver_id = d.driver_id
    JOIN license_classes lc ON ldla.license_class_id = lc.license_class_id
    LEFT JOIN tests t ON ta.test_appointment_id = t.test_appointment_id
    WHERE (p_driver_id IS NULL OR a.driver_id = p_driver_id)
      AND (p_test_type_id IS NULL OR ta.test_type_id = p_test_type_id)
      AND (p_is_locked IS NULL OR ta.is_locked = p_is_locked)
      AND (p_from_date IS NULL OR ta.appointment_date >= p_from_date)
      AND (p_to_date IS NULL OR ta.appointment_date <= p_to_date)
    ORDER BY ta.appointment_date DESC;
END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION get_drivers(
    p_driver_id UUID DEFAULT NULL,
    p_national_number VARCHAR DEFAULT NULL,
    p_country_id UUID DEFAULT NULL
)
RETURNS TABLE (
    driver_id UUID,
    national_number VARCHAR(50),
    full_name TEXT,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    date_of_birth TIMESTAMPTZ,
    is_female BOOLEAN,
    address TEXT,
    phone VARCHAR(20),
    email VARCHAR(255),
    country_id UUID,
    country_name VARCHAR(100),
    avatar TEXT,
    created_at TIMESTAMPTZ,
    created_by_user_id UUID,
    number_of_active_licenses BIGINT,
    number_of_detained_licenses BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        d.driver_id,
        d.national_number,
        get_driver_full_name(d.first_name, d.last_name) AS full_name,
        d.first_name,
        d.last_name,
        d.date_of_birth,
        d.is_female,
        d.address,
        d.phone,
        d.email,
        d.country_id,
        c.country_name,
        d.avatar,
        d.created_at,
        d.created_by_user_id,
        COALESCE(lc.active_license_count, 0) AS number_of_active_licenses,
        COALESCE(dlc.detained_license_count, 0) AS number_of_detained_licenses
    FROM drivers d
    JOIN countries c ON d.country_id = c.country_id
    LEFT JOIN (
        SELECT l.driver_id, COUNT(*) as active_license_count
        FROM licenses l
        WHERE l.is_active = TRUE
        GROUP BY l.driver_id
    ) lc ON d.driver_id = lc.driver_id
    LEFT JOIN (
        SELECT l.driver_id, COUNT(*) as detained_license_count
        FROM detained_licenses dl
        JOIN licenses l ON dl.license_id = l.license_id
        WHERE dl.is_released = FALSE
        GROUP BY l.driver_id
    ) dlc ON d.driver_id = dlc.driver_id
    WHERE (p_driver_id IS NULL OR d.driver_id = p_driver_id)
      AND (p_national_number IS NULL OR d.national_number = p_national_number)
      AND (p_country_id IS NULL OR d.country_id = p_country_id)
    ORDER BY d.created_at DESC;
END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION get_licenses(
    p_driver_id UUID DEFAULT NULL,
    p_license_class_id UUID DEFAULT NULL,
    p_is_active BOOLEAN DEFAULT NULL,
    p_include_expired BOOLEAN DEFAULT TRUE
)
RETURNS TABLE (
    license_id UUID,
    application_id UUID,
    driver_id UUID,
    driver_full_name TEXT,
    national_number VARCHAR(50),
    license_class_id UUID,
    class_name VARCHAR(50),
    issue_date TIMESTAMPTZ,
    expiration_date TIMESTAMPTZ,
    is_expired BOOLEAN,
    notes TEXT,
    paid_fees DECIMAL(10, 4),
    is_active BOOLEAN,
    issue_reason_id UUID,
    issue_reason_name VARCHAR(100),
    is_detained BOOLEAN,
    created_by_user_id UUID
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        l.license_id,
        l.application_id,
        l.driver_id,
        get_driver_full_name(d.first_name, d.last_name) AS driver_full_name,
        d.national_number,
        l.license_class_id,
        lc.class_name,
        l.issue_date,
        l.expiration_date,
        (l.expiration_date < NOW()) AS is_expired,
        l.notes,
        l.paid_fees,
        l.is_active,
        l.issue_reason_id,
        ir.reason_name AS issue_reason_name,
        (dl.detain_id IS NOT NULL AND dl.is_released = FALSE) AS is_detained,
        l.created_by_user_id
    FROM licenses l
    JOIN drivers d ON l.driver_id = d.driver_id
    JOIN license_classes lc ON l.license_class_id = lc.license_class_id
    JOIN issue_reasons ir ON l.issue_reason_id = ir.issue_reason_id
    LEFT JOIN detained_licenses dl ON l.license_id = dl.license_id AND dl.is_released = FALSE
    WHERE (p_driver_id IS NULL OR l.driver_id = p_driver_id)
      AND (p_license_class_id IS NULL OR l.license_class_id = p_license_class_id)
      AND (p_is_active IS NULL OR l.is_active = p_is_active)
      AND (p_include_expired = TRUE OR l.expiration_date >= NOW())
    ORDER BY l.issue_date DESC;
END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION can_apply_for_license_class(
    p_driver_id UUID,
    p_license_class_id UUID
)
RETURNS TABLE (
    can_apply BOOLEAN,
    reason TEXT
) AS $$
DECLARE
    v_driver_age INTEGER;
    v_minimum_age SMALLINT;
    v_has_active_license BOOLEAN;
BEGIN
    SELECT EXTRACT(YEAR FROM AGE(NOW(), date_of_birth))::INTEGER
    INTO v_driver_age
    FROM drivers
    WHERE driver_id = p_driver_id;

    IF v_driver_age IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Driver not found'::TEXT;
        RETURN;
    END IF;

    SELECT minimum_allowed_age
    INTO v_minimum_age
    FROM license_classes
    WHERE license_class_id = p_license_class_id;

    IF v_minimum_age IS NULL THEN
        RETURN QUERY SELECT FALSE, 'License class not found'::TEXT;
        RETURN;
    END IF;

    IF v_driver_age < v_minimum_age THEN
        RETURN QUERY SELECT FALSE, FORMAT('Driver must be at least %s years old', v_minimum_age);
        RETURN;
    END IF;

    SELECT EXISTS(
        SELECT 1 FROM licenses
        WHERE driver_id = p_driver_id
        AND license_class_id = p_license_class_id
        AND is_active = TRUE
        AND expiration_date > NOW()
    ) INTO v_has_active_license;

    IF v_has_active_license THEN
        RETURN QUERY SELECT FALSE, 'Driver already has an active license for this class'::TEXT;
        RETURN;
    END IF;

    RETURN QUERY SELECT TRUE, 'Driver is eligible to apply'::TEXT;
END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION get_test_statistics_for_application(
    p_local_driving_license_application_id UUID
)
RETURNS TABLE (
    test_type_id UUID,
    test_type_title VARCHAR(100),
    total_attempts INTEGER,
    passed_attempts INTEGER,
    failed_attempts INTEGER,
    last_attempt_date TIMESTAMPTZ,
    last_attempt_passed BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        tt.test_type_id,
        tt.test_type_title,
        COUNT(t.test_id)::INTEGER AS total_attempts,
        SUM(CASE WHEN t.is_test_passed THEN 1 ELSE 0 END)::INTEGER AS passed_attempts,
        SUM(CASE WHEN NOT t.is_test_passed THEN 1 ELSE 0 END)::INTEGER AS failed_attempts,
        MAX(ta.appointment_date) AS last_attempt_date,
        (SELECT t2.is_test_passed
         FROM tests t2
         JOIN test_appointments ta2 ON t2.test_appointment_id = ta2.test_appointment_id
         WHERE ta2.local_driving_license_application_id = p_local_driving_license_application_id
           AND ta2.test_type_id = tt.test_type_id
         ORDER BY ta2.appointment_date DESC
         LIMIT 1) AS last_attempt_passed
    FROM test_types tt
    LEFT JOIN test_appointments ta ON tt.test_type_id = ta.test_type_id
        AND ta.local_driving_license_application_id = p_local_driving_license_application_id
    LEFT JOIN tests t ON ta.test_appointment_id = t.test_appointment_id
    GROUP BY tt.test_type_id, tt.test_type_title
    ORDER BY tt.test_type_title;
END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE VIEW detained_licenses_view AS
SELECT * FROM get_detained_licenses();

CREATE OR REPLACE VIEW drivers_view AS
SELECT * FROM get_drivers();
