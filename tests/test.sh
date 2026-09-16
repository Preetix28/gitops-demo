#!/bin/sh

set -e

echo "Testing home page..."
curl -f http://localhost:8080/ | grep "Nginx GitOps Demo"

echo "Testing health endpoint..."
curl -f http://localhost:8080/health | grep "OK"

echo "Testing security headers..."
curl -I http://localhost:8080/ | grep "X-Content-Type-Options"

echo "All tests passed."
