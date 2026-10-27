#!/usr/bin/env bash
# ==============================================================================
# Script runner for the PostgreSQL Performance Audit Benchmark
# ==============================================================================
set -e

# Setup environment (adjust to your local rbenv/rvm setup)
export PATH="$HOME/.rbenv/bin:$HOME/.rbenv/shims:$PATH"
export RBENV_VERSION="${RBENV_VERSION:-3.2.9}"

# Target PostgreSQL benchmark instance (Docker container port 5435)
export DATABASE_URL="${DATABASE_URL:-postgresql://postgres:postgres@localhost:5435/good_meal_benchmark}"
export RAILS_ENV="${RAILS_ENV:-development}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo ">>> Running PostgreSQL Real Services Benchmark via: $SCRIPT_DIR/benchmark_real_services.rb"

bundle exec ruby "$SCRIPT_DIR/benchmark_real_services.rb"
