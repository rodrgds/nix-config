# Explicitly imported helper, not a service module. Keep bootstrap/system OIDs
# with the cluster administrator; transfer only audited application objects.
{
  lib,
  pkgs,
  service,
  applicationRole ? service,
  applicationDatabase ? service,
  applicationRoleFile ? null,
  applicationDatabaseFile ? null,
  applicationPasswordFile ? null,
  adminPasswordFile ? null,
  extensions ? [ ],
}:
let
  admin = "${service}_cluster_admin";
  transition = "${service}_role_transition";
  extensionNames = lib.concatMapStringsSep ", " (name: "'${name}'") extensions;
  connection = ''
    set -eu
    export PGOPTIONS='-c search_path=pg_catalog,pg_temp'
    export APP_ROLE=${
      if applicationRoleFile == null then
        lib.escapeShellArg applicationRole
      else
        "\"$(cat ${lib.escapeShellArg applicationRoleFile})\""
    }
    export APP_DATABASE=${
      if applicationDatabaseFile == null then
        lib.escapeShellArg applicationDatabase
      else
        "\"$(cat ${lib.escapeShellArg applicationDatabaseFile})\""
    }
    export APP_PASSWORD=${
      if applicationPasswordFile == null then
        "\"$APP_POSTGRES_PASSWORD\""
      else
        "\"$(cat ${lib.escapeShellArg applicationPasswordFile})\""
    }
    export ADMIN_PASSWORD=${
      if adminPasswordFile == null then
        "\"$POSTGRES_PASSWORD\""
      else
        "\"$(cat ${lib.escapeShellArg adminPasswordFile})\""
    }
    initial_role=${admin}
    if ! psql -X -U "$initial_role" -d "$APP_DATABASE" -Atqc 'SELECT 1' >/dev/null 2>&1; then
      initial_role="$APP_ROLE"
    fi
    exec psql -X -q -U "$initial_role" -d "$APP_DATABASE" -v ON_ERROR_STOP=1 -v VERBOSITY=terse
  '';
in
pkgs.writeShellScript "${service}-postgres-roles" ''
  set -euo pipefail
  until ${pkgs.podman}/bin/podman exec ${service}-postgres pg_isready -h 127.0.0.1 >/dev/null; do sleep 1; done
  # Read mounted _FILE secrets as root inside PostgreSQL, before libpq connects.
  # Passwords never enter command arguments, SQL echo, or host plaintext files.
  ${pkgs.podman}/bin/podman exec -i ${service}-postgres sh -ec ${lib.escapeShellArg connection} <<'SQL'
  BEGIN;
  SET LOCAL search_path = pg_catalog, pg_temp;
  SET LOCAL log_statement = 'none';
  SET LOCAL log_min_error_statement = 'panic';
  \getenv application_role APP_ROLE
  \getenv application_database APP_DATABASE
  \getenv application_password APP_PASSWORD
  \getenv admin_password ADMIN_PASSWORD
  SELECT set_config('rgo.application_role', :'application_role', true) \gset
  -- The audited services have none of these policies. Fail atomically if a
  -- future custom policy needs a reviewed OID/ACL migration instead of dropping it.
  DO $preflight$
  DECLARE app_oid oid := (SELECT oid FROM pg_roles WHERE rolname = current_setting('rgo.application_role'));
  BEGIN
    IF current_setting('rgo.application_role') IN ('${admin}', '${transition}') THEN
      RAISE EXCEPTION 'application/admin role collision';
    END IF;
    IF EXISTS (SELECT FROM pg_auth_members WHERE member = app_oid OR roleid = app_oid)
      OR EXISTS (SELECT FROM pg_default_acl WHERE defaclrole = app_oid)
      OR EXISTS (SELECT FROM pg_policy WHERE app_oid = ANY(polroles)) THEN
      RAISE EXCEPTION 'custom application role policies require a reviewed transition';
    END IF;
    ${lib.optionalString (extensions != [ ]) ''
      IF EXISTS (SELECT FROM pg_extension e JOIN pg_namespace n ON n.oid=e.extnamespace
          WHERE e.extname IN (${extensionNames}) AND n.nspname <> 'public')
        OR (EXISTS (SELECT FROM pg_roles WHERE oid=app_oid AND NOT rolsuper)
          AND (SELECT count(*) FROM pg_extension WHERE extname IN (${extensionNames})) <> ${toString (builtins.length extensions)}) THEN
        -- Reinstalling a missing extension as admin in an app-writable schema
        -- could execute hostile objects. Such repairs need their own review.
        RAISE EXCEPTION 'extension inventory changed; reviewed admin initialization required';
      END IF;
    ''}
  END
  $preflight$;
  SELECT NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${admin}') AS needs_admin \gset
  \if :needs_admin
    SELECT oid = 10 AS is_bootstrap FROM pg_roles WHERE rolname = :'application_role' \gset
    \if :is_bootstrap
      CREATE ROLE ${transition} SUPERUSER NOLOGIN;
      SET SESSION AUTHORIZATION ${transition};
      ALTER ROLE :"application_role" RENAME TO ${admin};
      SET SESSION AUTHORIZATION ${admin};
      DROP ROLE ${transition};
    \else
      CREATE ROLE ${admin} SUPERUSER LOGIN;
      SET SESSION AUTHORIZATION ${admin};
    \endif
  \endif
  SELECT NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'application_role') AS needs_application \gset
  \if :needs_application
    CREATE ROLE :"application_role" LOGIN;
  \endif
  ALTER ROLE ${admin} SUPERUSER LOGIN PASSWORD :'admin_password';
  ALTER ROLE :"application_role" LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS PASSWORD :'application_password';
  ALTER DATABASE :"application_database" OWNER TO :"application_role";
  -- Extensions and their members remain under admin control. Create required
  -- extensions before an unprivileged ORM/migrator reaches CREATE EXTENSION.
  ${lib.concatMapStringsSep "\n" (
    extension: "CREATE EXTENSION IF NOT EXISTS ${extension} WITH SCHEMA public;"
  ) extensions}
  DO $ownership$
  DECLARE item record; app text := current_setting('rgo.application_role');
  BEGIN
    FOR item IN SELECT nspname FROM pg_namespace
      WHERE nspname = 'public' AND nspowner = '${admin}'::regrole
    LOOP
      EXECUTE format('ALTER SCHEMA %I OWNER TO %I', item.nspname, app);
    END LOOP;
    FOR item IN SELECT n.nspname, c.relname, c.relkind FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public' AND c.relowner = '${admin}'::regrole
        AND c.relkind IN ('r', 'p', 'v', 'm', 'S', 'f')
        AND NOT EXISTS (SELECT FROM pg_depend d WHERE d.classid = 'pg_class'::regclass
          AND d.objid = c.oid AND d.deptype = 'e')
      ORDER BY c.relkind = 'S'
    LOOP
      EXECUTE format('ALTER %s %I.%I OWNER TO %I',
        CASE item.relkind WHEN 'S' THEN 'SEQUENCE' WHEN 'v' THEN 'VIEW'
          WHEN 'm' THEN 'MATERIALIZED VIEW' WHEN 'f' THEN 'FOREIGN TABLE' ELSE 'TABLE' END,
        item.nspname, item.relname, app);
    END LOOP;
    FOR item IN SELECT p.oid::regprocedure AS signature, p.prokind FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = 'public' AND p.proowner = '${admin}'::regrole
        AND NOT EXISTS (SELECT FROM pg_depend d WHERE d.classid = 'pg_proc'::regclass
          AND d.objid = p.oid AND d.deptype = 'e')
    LOOP
      EXECUTE format('ALTER %s %s OWNER TO %I',
        CASE item.prokind WHEN 'a' THEN 'AGGREGATE' ELSE 'ROUTINE' END, item.signature, app);
    END LOOP;
    FOR item IN SELECT n.nspname, t.typname, t.typtype FROM pg_type t
      JOIN pg_namespace n ON n.oid = t.typnamespace
      LEFT JOIN pg_class c ON c.oid = t.typrelid
      WHERE n.nspname = 'public' AND t.typowner = '${admin}'::regrole
        AND (t.typtype IN ('e', 'd', 'r') OR (t.typtype = 'c' AND c.relkind = 'c'))
        AND NOT EXISTS (SELECT FROM pg_depend d WHERE d.classid = 'pg_type'::regclass
          AND d.objid = t.oid AND d.deptype = 'e')
    LOOP
      EXECUTE format('ALTER %s %I.%I OWNER TO %I',
        CASE item.typtype WHEN 'd' THEN 'DOMAIN' ELSE 'TYPE' END, item.nspname, item.typname, app);
    END LOOP;
  END
  $ownership$;
  COMMIT;
  SQL
''
