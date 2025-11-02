## Integration test - demonstrates actual API usage
## Run with real credentials to verify end-to-end workflow
## Set GANJING_ACCESS_TOKEN and GANJING_CHANNEL_ID environment variables

import std/[asyncdispatch, os, strformat, strutils, options]
import ganjing

proc createTestFiles() =
  ## Create minimal test files for upload
  if not fileExists("test_video.mp4"):
    echo "Creating test video file..."
    # Create a minimal MP4 header (won't be valid but tests API)
    writeFile("test_video.mp4", "Test video content")
  
  if not fileExists("test_thumb.jpg"):
    echo "Creating test thumbnail file..."
    writeFile("test_thumb.jpg", "Test image content")

proc testCompleteWorkflow() {.async.} =
  echo repeat("=", 60)
  echo "GanJing World API Integration Test"
  echo repeat("=", 60)
  echo ""
  
  # Get credentials from environment
  let accessToken = getEnv("GANJING_ACCESS_TOKEN")
  let channelIdStr = getEnv("GANJING_CHANNEL_ID")
  
  if accessToken == "":
    echo "❌ Set GANJING_ACCESS_TOKEN environment variable"
    echo "   export GANJING_ACCESS_TOKEN='your_token'"
    quit(1)
  
  if channelIdStr == "":
    echo "❌ Set GANJING_CHANNEL_ID environment variable"
    echo "   export GANJING_CHANNEL_ID='your_channel_id'"
    quit(1)
  
  let channelId = ChannelId(channelIdStr)
  
  # Prepare test files
  createTestFiles()
  
  # Create client
  echo "→ Initializing client..."
  let client = newGanJingClient(accessToken)
  
  try:
    # Test 1: Get upload token
    echo ""
    echo "--- Test 1: Get Upload Token ---"
    let tokenResp = await client.getUploadToken()
    echo "✓ Upload token obtained"
    echo &"  Token (first 20 chars): {tokenResp.token[0..min(19, tokenResp.token.len-1)]}..."
    
    # Test 2: Upload thumbnail
    echo ""
    echo "--- Test 2: Upload Thumbnail ---"
    let thumbResult = await client.uploadThumbnail("test_thumb.jpg")
    echo "✓ Thumbnail uploaded"
    echo &"  ImageId: {thumbResult.imageId}"
    echo &"  Filename: {thumbResult.filename}"
    echo &"  Extension: {thumbResult.extension}"
    echo &"  Total URLs: {thumbResult.allUrls.len}"
    echo &"  Standard poster (672): {thumbResult.url672}"
    echo &"  HD poster (1280): {thumbResult.url1280}"
    echo &"  Full HD poster (1920): {thumbResult.url1920}"
    echo &"  Analyzed score: {thumbResult.analyzedScore}"
    
    # Test 3: Create draft video
    echo ""
    echo "--- Test 3: Create Draft Video ---"
    let metadata = VideoMetadata(
      title: "Integration Test Video",
      description: "Testing GanJing World API from Nim client",
      category: CategoryTechnology,
      visibility: VisibilityPublic,
      lang: "en-US"
    )
    
    let contentResult = await client.createDraftVideo(
      channelId,
      metadata,
      thumbResult.url672,
      thumbResult.url1280
    )
    echo "✓ Draft video created"
    echo &"  ContentId: {contentResult.contentId}"
    echo &"  OwnerId: {contentResult.ownerId}"
    echo &"  Title: {contentResult.title}"
    echo &"  Slug: {contentResult.slug}"
    echo &"  Category: {contentResult.categoryId}"
    echo &"  Visibility: {contentResult.visibility}"
    echo &"  Created at: {contentResult.createdAt}"
    echo &"  View count: {contentResult.viewCount}"
    echo &"  Like count: {contentResult.likeCount}"
    
    # Test 4: Upload video file
    echo ""
    echo "--- Test 4: Upload Video File ---"
    let videoResult = await client.uploadVideo(
      "test_video.mp4",
      channelId,
      contentResult.contentId
    )
    echo "✓ Video file uploaded"
    echo &"  VideoId: {videoResult.videoId}"
    echo &"  Filename: {videoResult.filename}"
    
    # Test 5: Check video status
    echo ""
    echo "--- Test 5: Check Video Status ---"
    let status = await client.getVideoStatus(videoResult.videoId)
    echo "✓ Status retrieved"
    echo &"  VideoId: {status.videoId}"
    echo &"  Filename: {status.filename}"
    echo &"  Status: {status.status}"
    echo &"  Progress: {status.progress}%"
    
    if status.url.isSome():
      echo &"  Video URL: {status.url.get()}"
    if status.durationSec.isSome():
      echo &"  Duration: {status.durationSec.get()}s"
    if status.width.isSome() and status.height.isSome():
      echo &"  Resolution: {status.width.get()}x{status.height.get()}"
    if status.loudness.isSome():
      echo &"  Loudness: {status.loudness.get()}"
    
    # Test 6: Complete upload workflow (high-level)
    echo ""
    echo "--- Test 6: Complete Upload Workflow ---"
    let completeResult = await client.uploadVideoComplete(
      videoPath = "test_video.mp4",
      thumbnailPath = "test_thumb.jpg",
      channelId = channelId,
      metadata = VideoMetadata(
        title: "Complete Workflow Test",
        description: "Testing high-level upload function",
        category: CategoryEducation,
        visibility: VisibilityPublic,
        lang: "en-US"
      ),
      waitForProcessing = false  # Don't wait in test
    )
    
    echo "✓ Complete upload finished"
    echo &"  ContentId: {completeResult.contentId}"
    echo &"  VideoId: {completeResult.videoId}"
    echo &"  ImageId: {completeResult.imageId}"
    echo &"  Web URL: {completeResult.webUrl}"
    echo &"  Status: {completeResult.processedStatus.status}"
    
    if completeResult.videoUrl.isSome():
      echo &"  Video URL: {completeResult.videoUrl.get()}"
    
    echo ""
    echo repeat("=", 60)
    echo "✅ All integration tests passed!"
    echo repeat("=", 60)
    echo ""
    echo "Generated IDs (for direct use):"
    echo &"  Content ID: {completeResult.contentId}"
    echo &"  Video ID: {completeResult.videoId}"
    echo &"  Image ID: {completeResult.imageId}"
    echo ""
    echo &"View your video at: {completeResult.webUrl}"
    
  except CatchableError as e:
    echo ""
    echo "❌ Integration test failed:"
    echo &"   Error: {e.msg}"
    echo ""
    echo "Stack trace:"
    echo e.getStackTrace()
    quit(1)
  
  finally:
    client.close()

when isMainModule:
  echo "Integration test will create test files and upload to your channel."
  echo "Press Ctrl+C within 3 seconds to cancel..."
  sleep(3000)
  waitFor testCompleteWorkflow()
