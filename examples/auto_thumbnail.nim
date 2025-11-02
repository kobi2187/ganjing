## Example: Upload without thumbnail (auto-extract)
## Demonstrates automatic thumbnail extraction from video

import asyncdispatch, ganjing, os

proc uploadWithAutoThumbnail() {.async.} =
  let accessToken = getEnv("GANJING_ACCESS_TOKEN")
  let channelId = ChannelId(getEnv("GANJING_CHANNEL_ID"))
  
  if accessToken == "" or $channelId == "":
    echo "Set GANJING_ACCESS_TOKEN and GANJING_CHANNEL_ID"
    quit(1)
  
  let client = newGanJingClient(accessToken)
  
  try:
    # Upload WITHOUT providing thumbnail
    # Will auto-extract first frame using ffmpeg
    let result = await client.uploadVideoComplete(
      videoPath = "myvideo.mp4",
      thumbnailPath = "",  # Empty - will auto-extract!
      channelId = channelId,
      metadata = VideoMetadata(
        title = "Auto-Thumbnail Test",
        description = "Thumbnail auto-extracted from video",
        category = CategoryTechnology,
        visibility = VisibilityPublic,
        lang = "en-US"
      ),
      autoExtractThumbnail = true  # Enable auto-extraction
    )
    
    echo ""
    echo "✅ Upload complete (thumbnail auto-extracted)!"
    echo &"   Content ID: {result.contentId}"
    echo &"   Video ID: {result.videoId}"
    echo &"   Image ID: {result.imageId}"
    echo &"   Watch at: {result.webUrl}"
    
  finally:
    client.close()

when isMainModule:
  if not hasFfmpeg():
    echo "❌ ffmpeg not found!"
    echo "   Install ffmpeg for automatic thumbnail extraction:"
    echo "   - Ubuntu/Debian: sudo apt-get install ffmpeg"
    echo "   - macOS: brew install ffmpeg"
    echo "   - Windows: download from ffmpeg.org"
    quit(1)
  
  waitFor uploadWithAutoThumbnail()
