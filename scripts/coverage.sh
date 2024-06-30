#!/usr/local/bin/bash

cd example

flutter clean && flutter pub get

flutter test --coverage
genhtml coverage/lcov.info -o coverage/html

open coverage/html/index.html