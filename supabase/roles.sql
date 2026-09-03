-- P2-L cluster role bootstrap. Supabase applies roles.sql before migrations.

DO $role$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_roles
    WHERE rolname = 'rebuy_invite_executor'
  ) THEN
    CREATE ROLE rebuy_invite_executor
      NOLOGIN
      NOSUPERUSER
      NOCREATEDB
      NOCREATEROLE
      NOINHERIT
      NOREPLICATION
      NOBYPASSRLS;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_roles
    WHERE rolname = 'rebuy_invite_executor'
      AND (
        rolsuper
        OR rolcanlogin
        OR rolcreatedb
        OR rolcreaterole
        OR rolinherit
        OR rolreplication
        OR rolbypassrls
      )
  ) THEN
    RAISE EXCEPTION 'rebuy_invite_executor_attributes_invalid';
  END IF;

  IF (
    SELECT count(*)
    FROM pg_catalog.pg_auth_members AS pam
    JOIN pg_catalog.pg_roles AS granted_role
      ON granted_role.oid = pam.roleid
    JOIN pg_catalog.pg_roles AS member_role
      ON member_role.oid = pam.member
    JOIN pg_catalog.pg_roles AS grantor_role
      ON grantor_role.oid = pam.grantor
    WHERE granted_role.rolname = 'rebuy_invite_executor'
       OR member_role.rolname = 'rebuy_invite_executor'
  ) <> 1 OR NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_auth_members AS pam
    JOIN pg_catalog.pg_roles AS granted_role
      ON granted_role.oid = pam.roleid
    JOIN pg_catalog.pg_roles AS member_role
      ON member_role.oid = pam.member
    JOIN pg_catalog.pg_roles AS grantor_role
      ON grantor_role.oid = pam.grantor
    WHERE granted_role.rolname = 'rebuy_invite_executor'
      AND member_role.rolname = 'postgres'
      AND grantor_role.rolname = 'supabase_admin'
      AND pam.admin_option
      AND NOT pam.inherit_option
      AND NOT pam.set_option
  ) THEN
    RAISE EXCEPTION 'rebuy_invite_executor_role_membership_invalid';
  END IF;
END
$role$;

-- P3 business workflow executor. Keep this separate from the exact-reviewed
-- invitation executor so later business grants cannot widen the P2-L role.
DO $role$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_roles
    WHERE rolname = 'rebuy_business_executor'
  ) THEN
    CREATE ROLE rebuy_business_executor
      NOLOGIN
      NOSUPERUSER
      NOCREATEDB
      NOCREATEROLE
      NOINHERIT
      NOREPLICATION
      NOBYPASSRLS;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_roles
    WHERE rolname = 'rebuy_business_executor'
      AND (
        rolsuper
        OR rolcanlogin
        OR rolcreatedb
        OR rolcreaterole
        OR rolinherit
        OR rolreplication
        OR rolbypassrls
      )
  ) THEN
    RAISE EXCEPTION 'rebuy_business_executor_attributes_invalid';
  END IF;

  IF (
    SELECT count(*)
    FROM pg_catalog.pg_auth_members AS pam
    JOIN pg_catalog.pg_roles AS granted_role
      ON granted_role.oid = pam.roleid
    JOIN pg_catalog.pg_roles AS member_role
      ON member_role.oid = pam.member
    JOIN pg_catalog.pg_roles AS grantor_role
      ON grantor_role.oid = pam.grantor
    WHERE granted_role.rolname = 'rebuy_business_executor'
       OR member_role.rolname = 'rebuy_business_executor'
  ) <> 1 OR NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_auth_members AS pam
    JOIN pg_catalog.pg_roles AS granted_role
      ON granted_role.oid = pam.roleid
    JOIN pg_catalog.pg_roles AS member_role
      ON member_role.oid = pam.member
    JOIN pg_catalog.pg_roles AS grantor_role
      ON grantor_role.oid = pam.grantor
    WHERE granted_role.rolname = 'rebuy_business_executor'
      AND member_role.rolname = 'postgres'
      AND grantor_role.rolname = 'supabase_admin'
      AND pam.admin_option
      AND NOT pam.inherit_option
      AND NOT pam.set_option
  ) THEN
    RAISE EXCEPTION 'rebuy_business_executor_role_membership_invalid';
  END IF;
END
$role$;
