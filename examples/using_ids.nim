## Example: Using exposed IDs directly
## Shows how all IDs are accessible for direct use

import asyncdispatch, ganjing
import std/strformat

proc demonstrateIdUsage() {.async.} =
  let client = newGanJingClient("your_access_token")
  let channelId = ChannelId("your_channel_id")
  
  echo "=== Demonstrating Exposed IDs ==="
  echo ""
  
  # Step 1: Upload thumbnail - get ImageId
  echo "1. Uploading thumbnail..."
  let thumbResult = await client.uploadThumbnail("thumb.jpg")
  
  let imageId: ImageId = thumbResult.imageId  # ✅ Directly accessible
  echo &"   → ImageId: {imageId}"
  echo &"   → Can use this ID: {imageId}"
  echo ""
  
  # Step 2: Create draft - get ContentId and ChannelId
  echo "2. Creating draft..."
  let contentResult = await client.createDraftVideo(
    channelId,
    VideoMetadata(
      title: "Test",
      description: "Test",
      category: CategoryOther,
      visibility: VisibilityPublic,
      lang: "en-US"
    ),
    thumbResult.url672,
    thumbResult.url1280
  )
  
  let contentId: ContentId = contentResult.contentId  # ✅ Directly accessible
  let ownerId: ChannelId = contentResult.ownerId      # ✅ Directly accessible
  echo &"   → ContentId: {contentId}"
  echo &"   → OwnerId: {ownerId}"
  echo &"   → Can use these IDs: {contentId}, {ownerId}"
  echo ""
  
  # Step 3: Upload video - get VideoId
  echo "3. Uploading video..."
  let videoResult = await client.uploadVideo(
    "video.mp4",
    channelId,
    contentResult.contentId  # Using the ContentId we got
  )
  
  let videoId: VideoId = videoResult.videoId  # ✅ Directly accessible
  echo &"   → VideoId: {videoId}"
  echo &"   → Can use this ID: {videoId}"
  echo ""
  
  # Step 4: Check status - VideoId is in result
  echo "4. Checking status..."
  let status = await client.getVideoStatus(videoId)  # Using the VideoId
  
  let statusVideoId: VideoId = status.videoId  # ✅ Still accessible
  echo &"   → VideoId in status: {statusVideoId}"
  echo &"   → Status: {status.status}"
  echo ""
  
  # Step 5: Complete workflow - ALL IDs exposed
  echo "5. Complete workflow (all IDs)..."
  let result = await client.uploadVideoComplete(
    videoPath = "video2.mp4",
    channelId = channelId,
    metadata = VideoMetadata(
      title: "Complete Test",
      description: "Testing complete workflow",
      category: CategoryTechnology,
      visibility: VisibilityPublic,
      lang: "en-US"
    ),
    thumbnailPath = "thumb2.jpg",
    waitForProcessing = false
  )
  
  # All three IDs are exposed and accessible
  let allContentId: ContentId = result.contentId  # ✅
  let allVideoId: VideoId = result.videoId        # ✅
  let allImageId: ImageId = result.imageId        # ✅
  
  echo &"   → ContentId: {allContentId}"
  echo &"   → VideoId: {allVideoId}"
  echo &"   → ImageId: {allImageId}"
  echo &"   → Web URL: {result.webUrl}"
  echo ""
  
  # Use IDs directly in your code
  echo "=== Using IDs in Your Code ==="
  echo ""
  echo "You can now use these IDs for:"
  echo &"  - Store contentId in database: {allContentId}"
  echo &"  - Track upload with videoId: {allVideoId}"
  echo &"  - Reference image with imageId: {allImageId}"
  echo &"  - Generate links: {getWebUrl(allContentId)}"
  echo ""
  
  # IDs can be converted to strings
  let contentIdStr: string = $allContentId
  let videoIdStr: string = $allVideoId
  let imageIdStr: string = $allImageId
  
  echo "Convert to strings for storage:"
  echo &"  contentId string: {contentIdStr}"
  echo &"  videoId string: {videoIdStr}"
  echo &"  imageId string: {imageIdStr}"
  
  client.close()

when isMainModule:
  waitFor demonstrateIdUsage()
