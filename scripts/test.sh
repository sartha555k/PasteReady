#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
mkdir -p .build/cache/clang
export CLANG_MODULE_CACHE_PATH="$PWD/.build/cache/clang"
swiftc -module-cache-path "$PWD/.build/cache/clang" -o .build/ClipboardTests \
  Sources/NotchLinks/LinkStore.swift Sources/NotchLinks/PanelView.swift Sources/NotchLinks/ClipboardScrollView.swift Sources/NotchLinks/ClipboardPreview.swift \
  Tests/NotchLinksTests/ClipboardTests.swift
.build/ClipboardTests
