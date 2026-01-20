# Debugging Guide

## Common Issues

### "Failed to load folder" Error

This error occurs when dropping a folder onto the drop zone. Here's how to debug:

#### 1. Check Console Output

The app now prints detailed debug information to the console. To view it:

1. Run the app from Xcode (not as a standalone app)
2. Open the Debug Area (View > Debug Area > Show Debug Area, or `Cmd+Shift+Y`)
3. Look for messages starting with:
   - `📁 Dropped URL:` - Shows the URL that was dropped
   - `❌ DropZoneView Error:` - Shows any errors
   - `✅ Valid folder dropped:` - Confirms successful drop

#### 2. Common Causes

**Issue: Dragging from certain locations**
- **Solution**: Try dragging directly from Finder's sidebar or a Finder window
- Some locations (like Desktop aliases) may not work correctly

**Issue: NAS / Network Volumes** ⚠️ **Common Issue**
- **Problem**: Drag-and-drop from network volumes (NAS, SMB shares, etc.) often fails due to macOS security restrictions
- **Solution**: Use the **"Browse..." button** instead of drag-and-drop
  - Click the "Browse..." button below the drop zone
  - Navigate to your NAS folder using the file picker
  - This method properly handles security-scoped resources for network volumes
- **Why**: macOS requires explicit permission grants for network volumes, which the file picker handles automatically
- **Alternative**: Mount your NAS as a local volume if drag-and-drop is preferred

**Issue: Permissions**
- **Solution**: Check that the app has Full Disk Access in System Settings
- Go to System Settings > Privacy & Security > Full Disk Access
- Add Plexify if it's not there
- **Note**: For network volumes, Full Disk Access may not be sufficient - use the Browse button instead

**Issue: URL format**
- **Solution**: The app expects file URLs. If you're dragging from certain apps, they might provide different URL formats

#### 3. Manual Testing

Try these steps:

1. **Open Finder**
2. **Navigate to a folder** (e.g., `/Users/YourName/Movies`)
3. **Drag the folder** directly from Finder onto the drop zone
4. **Check the console** for debug output

#### 4. Alternative: Use File Picker

If drag-and-drop continues to fail, we can add a file picker button as an alternative. Let me know if you'd like this feature.

### "No media files found" Error

This means the folder was loaded successfully, but no video files were detected.

**Check:**
- Does the folder contain video files? (mp4, mkv, avi, mov, etc.)
- Are files in excluded folders? (Featurettes, Extras, Samples, etc.)
- Are files named with "sample" or "trailer" in the name?

### "Missing API Key" Error

**Solution:**
1. Ensure `TMDB_API_KEY` is set in Xcode scheme
2. Go to Product > Scheme > Edit Scheme...
3. Select "Run" > "Arguments" tab
4. Add environment variable: `TMDB_API_KEY` = `your_key_here`
5. Restart Xcode after adding

### Scanning Takes Too Long

**Possible causes:**
- Large folder with many files
- Network request to TMDb API (if IMDb lookup is enabled)
- First-time cache creation

**Solution:**
- Wait for the scan to complete
- Check console for progress messages
- Consider disabling IMDb lookup for faster scanning (future feature)

## Debug Console Commands

When running from Xcode, you can use these in the debug console:

```swift
// Check current state
po viewModel.currentState

// Check scan result
po viewModel.scanResult

// Check rename plan
po viewModel.renamePlan

// Check errors
po viewModel.errorMessage
```

## Enabling More Verbose Logging

To add more detailed logging, you can modify the code to add print statements in:

- `DropZoneView.handleDrop()` - Already has debug prints
- `FolderScanner.scan()` - Add prints for each step
- `PlexifyViewModel.scanFolder()` - Add prints for state changes

## Common System Messages

### "Unable to obtain a task name port right" Warning

**Message**: `Unable to obtain a task name port right for pid XXX: (os/kern) failure (0x5)`

**What it means**: This is a macOS system message related to the debugger trying to inspect the app process. It's **harmless** and can be safely ignored.

**Why it happens**:
- The app is sandboxed (App Sandbox is enabled)
- The debugger doesn't have permission to inspect certain process details
- This is a macOS security feature, not an app bug

**Solution**: 
- **You can ignore this message** - it doesn't affect app functionality
- The app will work normally despite this warning
- This only appears when running from Xcode, not in standalone builds

**If it bothers you**:
- You can filter it out in Xcode's console
- Or run the app standalone (not from Xcode) - the message won't appear

## Reporting Issues

When reporting issues, please include:

1. **Console output** (from Xcode debug area)
2. **Steps to reproduce**
3. **macOS version** (System Settings > General > About)
4. **Xcode version** (Xcode > About Xcode)
5. **Where you're dragging from** (Finder sidebar, Finder window, Desktop, etc.)
6. **Any error messages** (excluding the "task name port right" warning if that's the only issue)
