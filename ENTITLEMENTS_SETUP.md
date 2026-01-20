# Entitlements Setup

The app requires sandbox entitlements to access files via the file picker (especially for NAS/network volumes).

## What Was Added

1. **Plexify.entitlements** file with:
   - App Sandbox enabled
   - User-selected file read/write access
   - Downloads folder access
   - Network client access (for TMDb API)

2. **Project configuration** updated to reference the entitlements file

## Verify Setup in Xcode

1. **Open the project** in Xcode
2. **Select the Plexify target**
3. **Go to "Signing & Capabilities" tab**
4. **Check that "App Sandbox" is enabled** (should show a list of capabilities)
5. **Verify the entitlements file is referenced**:
   - Look for "User Selected File" in the capabilities list
   - Or check Build Settings > Code Signing Entitlements = `Plexify/Plexify.entitlements`

## If Entitlements File Doesn't Appear

If Xcode doesn't automatically pick up the entitlements file:

1. **Right-click on the Plexify folder** in the Project Navigator
2. **Select "Add Files to Plexify..."**
3. **Navigate to** `Plexify/Plexify/Plexify.entitlements`
4. **Make sure "Copy items if needed" is unchecked**
5. **Click "Add"**

## Manual Setup (Alternative)

If the automatic setup doesn't work:

1. In Xcode, select the **Plexify target**
2. Go to **Build Settings**
3. Search for **"Code Signing Entitlements"**
4. Set it to: `Plexify/Plexify.entitlements`

## Required Entitlements

The entitlements file includes:

- `com.apple.security.app-sandbox` - Enables App Sandbox
- `com.apple.security.files.user-selected.read-write` - Allows file picker access
- `com.apple.security.files.downloads.read-write` - Allows Downloads folder access
- `com.apple.security.network.client` - Allows network requests (TMDb API)

## Testing

After setting up entitlements:

1. **Clean build folder** (Product > Clean Build Folder, or `Cmd+Shift+K`)
2. **Rebuild the app** (Product > Build, or `Cmd+B`)
3. **Run the app**
4. **Click "Browse..." button** - should now work without errors
5. **Select a folder** from your NAS - should work!

## Troubleshooting

**If you still get entitlement errors:**

1. Make sure you **cleaned and rebuilt** after adding entitlements
2. Check that the entitlements file is in the correct location: `Plexify/Plexify/Plexify.entitlements`
3. Verify the build setting points to the correct path
4. Try quitting and reopening Xcode
