-- =====================================================
-- DVLD Seed Data
-- =====================================================

DO $$
DECLARE
    v_user_id uuid;
BEGIN
    -- =====================================================
    -- 1. AUTH USER SETUP
    -- =====================================================
    CREATE EXTENSION IF NOT EXISTS pgcrypto;
    
    -- Check if user exists first to avoid ON CONFLICT issues
    SELECT id INTO v_user_id FROM auth.users WHERE email = 'admin@ibhartech.com';
    
    IF v_user_id IS NULL THEN
        v_user_id := gen_random_uuid();
        INSERT INTO auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
        VALUES (
            '00000000-0000-0000-0000-000000000000', v_user_id, 'authenticated', 'authenticated', 'admin@ibhartech.com', 
            crypt('password123', gen_salt('bf')), NOW(), '{"provider":"email","providers":["email"]}', '{}', NOW(), NOW()
        );
    END IF;

    -- =====================================================
    -- 2. CLEANUP
    -- =====================================================
    TRUNCATE TABLE international_licenses, detained_licenses, licenses, tests, test_appointments, 
                   local_driving_license_applications, applications, drivers, 
                   issue_reasons, test_types, license_classes, application_statuses, 
                   application_types, countries CASCADE;

    -- =====================================================
    -- 3. LOOKUP DATA
    -- =====================================================
    INSERT INTO countries (country_name) VALUES ('United States'), ('United Kingdom'), ('Canada');

    INSERT INTO application_types (application_type_title, application_fees) VALUES
        ('New Local Driving License', 150.00), ('Renew Driving License', 75.00), ('New International License', 200.00);

    INSERT INTO application_statuses (application_status_title) VALUES ('New'), ('Cancelled'), ('Completed');

    INSERT INTO license_classes (class_name, class_description, minimum_allowed_age, default_validity_length, class_fees) VALUES
        ('Class 1 - Small Motorcycle', 'Motorcycles up to 125cc', 18, 5, 50.00),
        ('Class 3 - Ordinary Driving License', 'Private vehicles up to 8 seats', 18, 10, 100.00),
        ('Class 4 - Commercial', 'Commercial vehicles and taxis', 21, 5, 150.00);

    INSERT INTO test_types (test_type_title, test_type_description, test_type_fees) VALUES
        ('Vision Test', 'Eye examination for driving', 10.00),
        ('Written Test', 'Traffic rules examination', 20.00),
        ('Street Test', 'Practical driving test', 50.00);

    INSERT INTO issue_reasons (reason_name) VALUES ('First Time'), ('Renew');

    -- =====================================================
    -- 4. CORE DATA (Using Subqueries for IDs)
    -- =====================================================
    
    -- Drivers
    INSERT INTO drivers (first_name, last_name, date_of_birth, national_number, is_female, address, phone, email, country_id, created_by_user_id)
    SELECT 'John', 'Smith', '1990-05-15'::TIMESTAMPTZ, 'SSN-123-45-6789', FALSE, '123 Main St, NY', '+1-555-0101', 'john.smith@email.com', country_id, v_user_id FROM countries WHERE country_name = 'United States'
    UNION ALL
    SELECT 'Emma', 'Johnson', '1992-08-22'::TIMESTAMPTZ, 'SSN-234-56-7890', TRUE, '456 Oak Ave, CA', '+1-555-0102', 'emma.j@email.com', country_id, v_user_id FROM countries WHERE country_name = 'United States'
    UNION ALL
    SELECT 'Michael', 'Williams', '1988-03-10'::TIMESTAMPTZ, 'SSN-345-67-8901', FALSE, '789 Pine Rd, IL', '+1-555-0103', 'michael.w@email.com', country_id, v_user_id FROM countries WHERE country_name = 'United States';

    -- Applications (John & Emma = Completed, Michael = New)
    INSERT INTO applications (driver_id, application_date, application_type_id, application_status_id, last_status_date, paid_fees, created_by_user_id)
    SELECT d.driver_id, '2023-01-15'::TIMESTAMPTZ, at.application_type_id, ast.application_status_id, '2023-02-20'::TIMESTAMPTZ, 150.00, v_user_id
    FROM drivers d, application_types at, application_statuses ast
    WHERE d.national_number = 'SSN-123-45-6789' AND at.application_type_title = 'New Local Driving License' AND ast.application_status_title = 'Completed'
    UNION ALL
    SELECT d.driver_id, '2023-02-10'::TIMESTAMPTZ, at.application_type_id, ast.application_status_id, '2023-03-15'::TIMESTAMPTZ, 150.00, v_user_id
    FROM drivers d, application_types at, application_statuses ast
    WHERE d.national_number = 'SSN-234-56-7890' AND at.application_type_title = 'New Local Driving License' AND ast.application_status_title = 'Completed'
    UNION ALL
    SELECT d.driver_id, '2024-01-10'::TIMESTAMPTZ, at.application_type_id, ast.application_status_id, '2024-01-10'::TIMESTAMPTZ, 150.00, v_user_id
    FROM drivers d, application_types at, application_statuses ast
    WHERE d.national_number = 'SSN-345-67-8901' AND at.application_type_title = 'New Local Driving License' AND ast.application_status_title = 'New';

    -- Local Driving License Applications
    INSERT INTO local_driving_license_applications (application_id, license_class_id)
    SELECT a.application_id, lc.license_class_id
    FROM applications a
    JOIN drivers d ON a.driver_id = d.driver_id
    JOIN license_classes lc ON lc.class_name LIKE 'Class 3%'
    WHERE d.national_number IN ('SSN-123-45-6789', 'SSN-234-56-7890', 'SSN-345-67-8901');

    -- Test Appointments (For John)
    INSERT INTO test_appointments (test_type_id, local_driving_license_application_id, appointment_date, paid_fees, created_by_user_id, is_locked, created_at)
    SELECT tt.test_type_id, ldla.local_driving_license_application_id, '2023-01-20'::TIMESTAMPTZ, 10.00, v_user_id, TRUE, '2023-01-01'::TIMESTAMPTZ
    FROM test_types tt, local_driving_license_applications ldla
    JOIN applications a ON ldla.application_id = a.application_id
    JOIN drivers d ON a.driver_id = d.driver_id
    WHERE tt.test_type_title = 'Vision Test' AND d.national_number = 'SSN-123-45-6789';

    -- Licenses (For John)
    INSERT INTO licenses (application_id, driver_id, license_class_id, issue_date, expiration_date, paid_fees, is_active, issue_reason_id, created_by_user_id)
    SELECT a.application_id, d.driver_id, lc.license_class_id, '2023-02-20'::TIMESTAMPTZ, '2033-02-20'::TIMESTAMPTZ, 100.00, TRUE, ir.issue_reason_id, v_user_id
    FROM applications a
    JOIN drivers d ON a.driver_id = d.driver_id
    JOIN local_driving_license_applications ldla ON a.application_id = ldla.application_id
    JOIN license_classes lc ON ldla.license_class_id = lc.license_class_id
    JOIN issue_reasons ir ON ir.reason_name = 'First Time'
    WHERE d.national_number = 'SSN-123-45-6789';

    RAISE NOTICE '✅ Seed data inserted successfully';
END $$;
