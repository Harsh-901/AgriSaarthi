#!/usr/bin/env bash
# Exit on error
set -o errexit

# Install dependencies
pip install -r requirements.txt

# Create static directory if it doesn't exist
mkdir -p staticfiles

# Apply database migrations
python manage.py migrate

# Collect static files
python manage.py collectstatic --no-input
