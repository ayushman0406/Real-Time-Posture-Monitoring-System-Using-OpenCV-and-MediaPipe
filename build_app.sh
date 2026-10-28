#!/bin/bash
set -euo pipefail

APP_NAME="PostureBar"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "🔨 Compiling native Swift sources for ${APP_NAME}..."

mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

swiftc \
    -O \
    -target arm64-apple-macosx14.0 \
    -sdk "$(xcrun --show-sdk-path)" \
    -framework SwiftUI \
    -framework AppKit \
    -framework AVFoundation \
    -framework Vision \
    -framework CoreMedia \
    -framework CoreImage \
    -framework UserNotifications \
    Sources/PostureBar/App/AppSettings.swift \
    Sources/PostureBar/Vision/PostureMathEngine.swift \
    Sources/PostureBar/Vision/PoseVisionProcessor.swift \
    Sources/PostureBar/Vision/CameraScheduler.swift \
    Sources/PostureBar/Feedback/ScreenOverlayWindow.swift \
    Sources/PostureBar/Feedback/FeedbackCoordinator.swift \
    Sources/PostureBar/Views/CameraPreviewView.swift \
    Sources/PostureBar/Views/OnboardingView.swift \
    Sources/PostureBar/Views/MenuBarPopoverView.swift \
    Sources/PostureBar/App/PostureBarApp.swift \
    -o "${MACOS_DIR}/${APP_NAME}"

cp Info.plist "${CONTENTS_DIR}/Info.plist"
echo "APPL????" > "${CONTENTS_DIR}/PkgInfo"

# Ad-hoc sign the app bundle so macOS TCC camera & notification permissions work cleanly
codesign --force --deep --sign - "${APP_BUNDLE}" >/dev/null 2>&1 || true

echo "✅ Built ${APP_BUNDLE} successfully!"
echo "👉 Run 'open ${APP_BUNDLE}' to launch PostureBar in your top menu bar."
