## Elegant Upload Example
## Shows the simplest, most elegant way to use the API

import asyncdispatch, os
import std/strformat
import ganjing

proc main() {.async.} =
  # Get credentials from environment
  let accessToken = getEnv("GANJING_ACCESS_TOKEN")
  let channelId = ChannelId(getEnv("GANJING_CHANNEL_ID"))

  if accessToken == "" or $channelId == "":
    echo "Set GANJING_ACCESS_TOKEN and GANJING_CHANNEL_ID"
    quit(1)

  # Create client (verbose=true by default)
  let client = newGanJingClient(accessToken)

  try:
    # Simple metadata - just the essentials
    let metadata = VideoMetadata(
      title: "My Video",
      description: "Uploaded with the elegant Nim API",
      category: CategoryTechnology,
      visibility: VisibilityPublic,
      lang: "en-US"
    )

    # === SIMPLEST WAY - just upload! ===
    # Auto-extracts thumbnail, waits for processing
    let result = await client.upload("myvideo.mp4", channelId, metadata)

    echo ""
    echo "✅ Done!"
    echo &"Watch at: {result.webUrl}"
    echo ""
    echo "All IDs available:"
    echo &"  Content: {result.contentId}"
    echo &"  Video:   {result.videoId}"
    echo &"  Image:   {result.imageId}"

    # === WITH THUMBNAIL ===
    # let result = await client.upload("video.mp4", channelId, metadata,
    #                                   thumbnail = "thumb.jpg")

    # === CUSTOM WORKFLOWS - Composable! ===
    # Upload assets separately
    # let (contentId, videoId, imageId) = await client.uploadAssets(
    #   "video.mp4", "thumb.jpg", channelId, metadata
    # )
    #
    # # Poll for completion later
    # let status = await client.waitForProcessing(videoId)

  finally:
    client.close()

when isMainModule:
  waitFor main()
