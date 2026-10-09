#!/bin/sh
set -eu
python3 -m unittest discover -s backend/tests
cd app
flutter analyze
flutter test
flutter build web
