#!/bin/bash
set -euo pipefail # Stop when an experiment or dependency check fails.
cd "$(dirname "$0")" # Resolve the delivered package independently of Finder's working directory.
python3 -m venv .venv # Keep the project's Python dependencies isolated.
source .venv/bin/activate # Use the project's own Python interpreter.
python -m pip install -r requirements.txt # Install the documented native runner and validator dependencies.
export PGHOST="${PGHOST:-localhost}" # Reuse an existing server setting when supplied.
export PGDATABASE="${PGDATABASE:-demo}" # Retain the teammate's default demo database.
export PGUSER="${PGUSER:-postgres}" # Allow the user to override the server account.
if [[ -z "${PGPASSWORD:-}" && ! -f "$HOME/.pgpass" ]]; then # Prefer existing libpq credentials.
 read -r -s -p 'PostgreSQL password: ' PGPASSWORD # Read the password without echoing it.
 echo # Move the next progress message onto its own line.
 export PGPASSWORD # Pass the credential only to this process tree.
fi # Finish optional local credential entry.
python scripts/run_native.py --output "evidence/native_$(date +%Y%m%d_%H%M%S)" # Run fresh Task 3 and Task 4 measurements in an isolated schema.
unset PGPASSWORD # Remove the temporary credential before the launcher exits.
