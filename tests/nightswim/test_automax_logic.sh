#!/usr/bin/env bash
# Runs the pure-logic tests for nightswim/automax.py.
exec /usr/bin/python3 -I "$(dirname "$0")/test_automax_logic.py"
