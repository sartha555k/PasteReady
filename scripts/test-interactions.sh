#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
mkdir -p .build/cache/clang
export CLANG_MODULE_CACHE_PATH="$PWD/.build/cache/clang"
swiftc -module-cache-path "$PWD/.build/cache/clang" -o .build/InteractionTests \
  Sources/NotchLinks/LinkStore.swift Sources/NotchLinks/PanelView.swift Sources/NotchLinks/PanelComponents.swift Sources/NotchLinks/ClipboardScrollView.swift Sources/NotchLinks/ClipboardPreview.swift \
  Sources/NotchLinks/NotchController.swift Sources/NotchLinks/PasteService.swift Sources/NotchLinks/DisplayGeometry.swift Sources/NotchLinks/HoverIntent.swift Tests/NotchLinksTests/InteractionTests.swift
.build/InteractionTests
