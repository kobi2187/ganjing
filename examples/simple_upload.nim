## Simple upload example
## Demonstrates basic usage with all IDs accessible

import asyncdispatch, ganjing, os

proc simpleUpload() {.async.} =
  # Get credentials from environment
  let accessToken = getEnv("GANJING_ACCESS_TOKEN")
  let channelId = ChannelId(getEnv("GANJING_CHANNEL_ID"))
  
  if accessToken == "" or $channelId == "":
    echo "Set GANJING_ACCESS_TOKEN and GANJING_CHANNEL_ID"
    quit(1)
  
  # Create client
  let client = newGanJingClient(accessToken)
  
  try:
    # Upload video with complete workflow
    let result = await client.uploadVideoComplete(
      videoPath = "myvideo.mp4",
      thumbnailPath = "mythumb.jpg",
      channelId = channelId,
      metadata = VideoMetadata(
        title = "My First Upload",
        description = "Uploaded via Nim client",
        category = CategoryTechnology,
        visibility = VisibilityPublic,
        lang = "en-US"
      ),
      waitForProcessing = true
    )
    
    # All IDs are directly accessible
    echo ""
    echo "✅ Upload complete!"
    echo &"   Content ID: {result.contentId}"
    echo &"   Video ID: {result.videoId}"
    echo &"   Image ID: {result.imageId}"
    echo &"   Watch at: {result.webUrl}"
    
    if result.videoUrl.isSome:
      echo &"   Stream URL: {result.videoUrl.get()}"
    
  finally:
    client.close()

when isMainModule:
  waitFor simpleUpload()
