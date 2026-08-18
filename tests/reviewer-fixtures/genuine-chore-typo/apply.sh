#!/usr/bin/env bash
set -euo pipefail
sed -i '0,/the/s//teh/' "$R/README.md"
sed -i '0,/teh/s//the/' "$R/README.md"
printf '\nRun the test suite before opening a pull request.\n' >> "$R/README.md"
