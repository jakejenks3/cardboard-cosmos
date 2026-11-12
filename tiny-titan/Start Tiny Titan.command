#!/bin/bash
# Double-click on a Mac (or run `sh start.sh` in a terminal) to start Tiny Titan.
cd "$(dirname "$0")" || exit 1

pause_and_exit() {
  echo
  read -r -p "  Press Enter to close. " _
  exit "$1"
}

if ! command -v node >/dev/null 2>&1; then
  echo
  echo "  Node.js is not installed yet."
  echo
  echo "  1. Go to https://nodejs.org and install the LTS version."
  echo "  2. Then open this file again."
  pause_and_exit 1
fi

if [ ! -d node_modules ]; then
  echo
  echo "  Setting up Tiny Titan for the first time. This takes about a minute..."
  echo
  npm install || { echo; echo "  Setup did not finish. The messages above say why."; pause_and_exit 1; }
fi

npm run app
