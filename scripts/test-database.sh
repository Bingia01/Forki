#!/bin/sh
set -eu
forki_pg_bin="${FORKI_POSTGRES_BIN:-$(pg_config --bindir)}"
forki_test_dir=$(mktemp -d "${FORKI_TEST_TMP:-/tmp}/forki-db.XXXXXX")
forki_port=${FORKI_TEST_PORT:-56549}
forki_socket_dir=$(mktemp -d /tmp/forki-socket.XXXXXX)
cleanup() { "$forki_pg_bin/pg_ctl" -D "$forki_test_dir/data" -m immediate stop >/dev/null 2>&1 || true; rm -rf "$forki_test_dir" "$forki_socket_dir"; }
trap cleanup EXIT INT TERM
"$forki_pg_bin/initdb" -D "$forki_test_dir/data" --auth=trust --no-locale >/dev/null
"$forki_pg_bin/pg_ctl" -D "$forki_test_dir/data" -l "$forki_test_dir/postgres.log" -o "-p $forki_port -k $forki_socket_dir -c listen_addresses=''" -w start >/dev/null
run_sql() { "$forki_pg_bin/psql" -X -v ON_ERROR_STOP=1 -h "$forki_socket_dir" -p "$forki_port" -d postgres -f "$1"; }
run_sql supabase/tests/security_fixture.sql
for forki_migration in supabase/migrations/*.sql; do run_sql "$forki_migration"; done
run_sql supabase/tests/security_assertions.sql
