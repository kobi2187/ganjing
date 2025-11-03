## Test real API responses
## This script makes actual API calls and prints the responses
## so we can verify our parsing code matches reality

import std/[asyncdispatch, os, json, strformat, strutils, times, options]
import "../src/ganjing"

proc testRealAPI() {.async.} =
  echo repeat("=", 60)
  echo "Testing Real API Responses"
  echo repeat("=", 60)
  echo ""

  # Get credentials from environment
  let accessToken = getEnv("GANJING_ACCESS_TOKEN")
  let channelIdStr = getEnv("GANJING_CHANNEL_ID")

  if accessToken == "":
    echo "❌ Set GANJING_ACCESS_TOKEN environment variable"
    quit(1)

  if channelIdStr == "":
    echo "❌ Set GANJING_CHANNEL_ID environment variable"
    quit(1)

  let channelId = ChannelId(channelIdStr)

  # Create minimal test files
  if not fileExists("test_video.mp4"):
    writeFile("test_video.mp4", "Test video")
  if not fileExists("test_thumb.jpg"):
    writeFile("test_thumb.jpg", "Test image")

  let client = newGanJingClient(accessToken)

  try:
    # Test 1: Get upload token
    echo "=" .repeat(60)
    echo "TEST 1: Get Upload Token"
    echo "=" .repeat(60)
    try:
      let tokenResp = await client.getUploadToken()
      echo "✓ Success!"
      echo "Response structure:"
      echo "  token field exists: ", tokenResp.token != ""
      echo "  token length: ", tokenResp.token.len
      echo "  token preview: ", tokenResp.token[0..min(30, tokenResp.token.len-1)], "..."
      echo ""
    except CatchableError as e:
      echo "❌ Error: ", e.msg
      echo ""

    # Test 2: Upload thumbnail
    echo "=" .repeat(60)
    echo "TEST 2: Upload Thumbnail"
    echo "=" .repeat(60)
    try:
      let thumbResult = await client.uploadThumbnail("test_thumb.jpg")
      echo "✓ Success!"
      echo "Response structure:"
      echo "  imageId: ", thumbResult.imageId
      echo "  filename: ", thumbResult.filename
      echo "  extension: ", thumbResult.extension
      echo "  allUrls count: ", thumbResult.allUrls.len
      echo "  url672: ", if thumbResult.url672 != "": "✓" else: "✗"
      echo "  url1280: ", if thumbResult.url1280 != "": "✓" else: "✗"
      echo "  url1920: ", if thumbResult.url1920 != "": "✓" else: "✗"
      echo "  analyzedScore: ", thumbResult.analyzedScore
      echo ""
      echo "All URLs:"
      for i, url in thumbResult.allUrls:
        echo &"  [{i}] {url}"
      echo ""

      # Test 3: Create draft video
      echo "=" .repeat(60)
      echo "TEST 3: Create Draft Video"
      echo "=" .repeat(60)
      try:
        let metadata = VideoMetadata(
          title: "API Test " & $epochTime().int,
          description: "Testing real API responses",
          category: CategoryTechnology,
          visibility: VisibilityPrivate,  # Use private for testing
          lang: "en-US"
        )

        let contentResult = await client.createDraftVideo(
          channelId,
          metadata,
          thumbResult.url672,
          thumbResult.url1280
        )
        echo "✓ Success!"
        echo "Response structure:"
        echo "  contentId: ", contentResult.contentId
        echo "  ownerId: ", contentResult.ownerId
        echo "  videoType: ", contentResult.videoType
        echo "  categoryId: ", contentResult.categoryId
        echo "  slug: ", contentResult.slug
        echo "  title: ", contentResult.title
        echo "  description: ", contentResult.description
        echo "  visibility: ", contentResult.visibility
        echo "  posterUrl: ", if contentResult.posterUrl != "": "✓" else: "✗"
        echo "  posterHdUrl: ", if contentResult.posterHdUrl != "": "✓" else: "✗"
        echo "  createdAt: ", contentResult.createdAt
        echo "  viewCount: ", contentResult.viewCount
        echo "  likeCount: ", contentResult.likeCount
        echo ""

        # Test 4: Upload video
        echo "=" .repeat(60)
        echo "TEST 4: Upload Video File"
        echo "=" .repeat(60)
        try:
          let videoResult = await client.uploadVideo(
            "test_video.mp4",
            channelId,
            contentResult.contentId
          )
          echo "✓ Success!"
          echo "Response structure:"
          echo "  videoId: ", videoResult.videoId
          echo "  filename: ", videoResult.filename
          echo ""

          # Test 5: Check video status
          echo "=" .repeat(60)
          echo "TEST 5: Get Video Status"
          echo "=" .repeat(60)
          try:
            let status = await client.getVideoStatus(videoResult.videoId)
            echo "✓ Success!"
            echo "Response structure:"
            echo "  videoId: ", status.videoId
            echo "  filename: ", status.filename
            echo "  status: ", status.status
            echo "  progress: ", status.progress, "%"
            echo "  url: ", if status.url.isSome(): status.url.get() else: "(none)"
            echo "  durationSec: ", if status.durationSec.isSome(): $status.durationSec.get() else: "(none)"
            echo "  width: ", if status.width.isSome(): $status.width.get() else: "(none)"
            echo "  height: ", if status.height.isSome(): $status.height.get() else: "(none)"
            echo "  loudness: ", if status.loudness.isSome(): status.loudness.get() else: "(none)"
            echo "  thumbBaseUrl: ", if status.thumbBaseUrl.isSome(): "✓" else: "✗"
            echo "  thumbSizes: ", if status.thumbSizes.isSome(): status.thumbSizes.get() else: "(none)"
            echo ""

            # Test 6: Refresh access token
            echo "=" .repeat(60)
            echo "TEST 6: Refresh Access Token"
            echo "=" .repeat(60)
            try:
              let refreshResp = await client.refreshAccessToken()
              echo "✓ Success!"
              echo "Response structure:"
              echo "  userId: ", refreshResp.userId
              echo "  token length: ", refreshResp.token.len
              echo "  refreshToken length: ", refreshResp.refreshToken.len
              echo ""
            except CatchableError as e:
              echo "❌ Error: ", e.msg
              echo ""

          except CatchableError as e:
            echo "❌ Error: ", e.msg
            echo ""
        except CatchableError as e:
          echo "❌ Error: ", e.msg
          echo ""
      except CatchableError as e:
        echo "❌ Error: ", e.msg
        echo ""
    except CatchableError as e:
      echo "❌ Error: ", e.msg
      echo ""

    echo "=" .repeat(60)
    echo "API Testing Complete"
    echo "=" .repeat(60)

  finally:
    client.close()

when isMainModule:
  echo "This will make real API calls to test actual responses."
  echo "Starting in 2 seconds..."
  sleep(2000)
  waitFor testRealAPI()
