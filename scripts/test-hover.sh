#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
mkdir -p .build/cache/clang
swiftc -module-cache-path "$PWD/.build/cache/clang" -o .build/HoverIntentTests \
  Sources/NotchLinks/HoverIntent.swift Tests/NotchLinksTests/HoverIntentTests.swift
.build/HoverIntentTests
