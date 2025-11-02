## Test video utilities (thumbnail extraction)

import std/[os, unittest]
import ganjing/videoutils

suite "Video Utilities":
  
  test "Check ffmpeg availability":
    let available = hasFfmpeg()
    if available:
      echo "✓ ffmpeg is available"
    else:
      echo "⚠ ffmpeg not found (install for thumbnail extraction)"
  
  test "Extract thumbnail from video":
    # This test requires ffmpeg and a video file
    if not hasFfmpeg():
      echo "⚠ Skipping: ffmpeg not available"
      skip()
      return
    
    # Create a dummy video file for testing
    # In real use, you'd have an actual video
    let testVideo = "test_video_for_thumb.mp4"
    
    if not fileExists(testVideo):
      echo "⚠ Skipping: no test video file"
      echo "  Create 'test_video_for_thumb.mp4' to test extraction"
      skip()
      return
    
    # Extract thumbnail
    let thumbPath = extractFirstFrame(testVideo, timeOffset = 0.5)
    
    check fileExists(thumbPath)
    echo &"✓ Thumbnail extracted: {thumbPath}"
    
    # Cleanup
    if fileExists(thumbPath):
      removeFile(thumbPath)
      echo "✓ Cleaned up test thumbnail"
