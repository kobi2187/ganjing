## Simple upload example
## Demonstrates basic usage with all IDs accessible

import asyncdispatch, ganjing, os
import std/[options, strformat]

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
    # Define metadata
    let metadata = VideoMetadata(
      title: "My First Upload",
      description: "Uploaded via Nim client",
      category: CategoryTechnology,
      visibility: VisibilityPublic,
      lang: "en-US"
    )

    # Option 1: Super simple - with thumbnail
    let result = await client.upload(
      "myvideo.mp4",
      channelId,
      metadata,
      thumbnail = "mythumb.jpg"
    )

    # Option 2: Even simpler - auto-extract thumbnail
    # let result = await client.upload("myvideo.mp4", channelId, metadata)

    # Option 3: Full control with uploadVideoComplete
    # let result = await client.uploadVideoComplete(
    #   videoPath = "myvideo.mp4",
    #   channelId = channelId,
    #   metadata = metadata,
    #   thumbnailPath = "mythumb.jpg",
    #   waitForProcessing = true
    # )

    # All IDs are directly accessible
    echo ""
    echo "✅ Upload complete!"
    echo &"   Content ID: {result.contentId}"
    echo &"   Video ID: {result.videoId}"
    echo &"   Image ID: {result.imageId}"
    echo &"   Watch at: {result.webUrl}"

    if result.videoUrl.isSome():
      echo &"   Stream URL: {result.videoUrl.get()}"

  finally:
    client.close()

when isMainModule:
  waitFor simpleUpload()
