# Plexify Packaging Guide

This document describes how to build and package Plexify for distribution.

## Prerequisites

- Xcode 15.0 or later
- Apple Developer account (for code signing and notarization)
- Command line tools installed

## Building the App

### Development Build

For local testing, simply build and run in Xcode:
```bash
open Plexify/Plexify.xcodeproj
# Press Cmd+R to build and run
```

### Release Build

Build a release version from the command line:
```bash
cd Plexify
xcodebuild -scheme Plexify \
  -configuration Release \
  -derivedDataPath ./build \
  build
```

The built app will be at: `./build/Build/Products/Release/Plexify.app`

## Code Signing

### Setup

1. **Get a Developer ID Certificate**
   - Log into [Apple Developer Portal](https://developer.apple.com/)
   - Go to Certificates, Identifiers & Profiles
   - Create a "Developer ID Application" certificate
   - Download and install it in Keychain

2. **Configure Xcode**
   - Open the project in Xcode
   - Select the Plexify target
   - Go to "Signing & Capabilities"
   - Select your Team
   - Enable "Automatically manage signing"

### Manual Signing

If you prefer manual signing:

```bash
# Sign the app
codesign --deep --force --verify --verbose \
  --sign "Developer ID Application: Your Name (TEAM_ID)" \
  --options runtime \
  --entitlements Plexify.entitlements \
  Plexify.app
```

## Creating an Archive

Archive the app for distribution:

```bash
xcodebuild -scheme Plexify \
  -configuration Release \
  -archivePath ./build/Plexify.xcarchive \
  archive
```

## Export Options

Create an `ExportOptions.plist` file:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>Developer ID Application</string>
</dict>
</plist>
```

Export the archive:

```bash
xcodebuild -exportArchive \
  -archivePath ./build/Plexify.xcarchive \
  -exportPath ./build/export \
  -exportOptionsPlist ExportOptions.plist
```

## Notarization

Notarization is required for macOS Gatekeeper to allow the app to run.

### Submit for Notarization

```bash
xcrun notarytool submit \
  --apple-id "your@email.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "app-specific-password" \
  --wait \
  Plexify.zip
```

### Staple the Notarization Ticket

```bash
xcrun stapler staple Plexify.app
```

## Creating a DMG

### Using create-dmg (Recommended)

Install create-dmg:
```bash
brew install create-dmg
```

Create the DMG:
```bash
create-dmg \
  --volname "Plexify" \
  --volicon "icon.icns" \
  --window-pos 200 120 \
  --window-size 600 300 \
  --icon-size 100 \
  --icon "Plexify.app" 175 120 \
  --hide-extension "Plexify.app" \
  --app-drop-link 425 120 \
  --hdiutil-quiet \
  "Plexify.dmg" \
  "./build/export/Plexify.app"
```

### Manual DMG Creation

```bash
# Create a temporary directory
mkdir -p dmg_temp
cp -R Plexify.app dmg_temp/

# Create the DMG
hdiutil create -volname "Plexify" \
  -srcfolder dmg_temp \
  -ov -format UDZO \
  Plexify.dmg

# Clean up
rm -rf dmg_temp
```

## Distribution Checklist

- [ ] Build release version
- [ ] Code sign the app
- [ ] Archive the app
- [ ] Export for distribution
- [ ] Submit for notarization
- [ ] Staple notarization ticket
- [ ] Create DMG (optional)
- [ ] Test on clean macOS system
- [ ] Verify Gatekeeper acceptance

## Troubleshooting

### "App is damaged" Error

This usually means:
1. The app isn't properly signed
2. Notarization failed or wasn't completed
3. The app was modified after signing

**Solution**: Re-sign and re-notarize the app.

### Gatekeeper Rejects the App

- Ensure the app is notarized
- Check that the notarization ticket is stapled
- Verify the Developer ID certificate is valid

### Code Signing Errors

- Verify your Developer ID certificate is installed
- Check that your Team ID matches in all configurations
- Ensure the app bundle structure is correct

## Notes

- **Hardened Runtime**: Required for notarization. Configure in Xcode build settings.
- **Entitlements**: May need to add entitlements for file access:
  ```xml
  <key>com.apple.security.files.user-selected.read-write</key>
  <true/>
  ```
- **App-specific Password**: Generate in Apple ID account settings for notarization
- **Distribution Outside Mac App Store**: Use Developer ID, not Mac App Distribution certificate

## Future Enhancements

- [ ] Mac App Store distribution
- [ ] Sparkle auto-update framework
- [ ] Automated CI/CD packaging
- [ ] Automated notarization in CI
