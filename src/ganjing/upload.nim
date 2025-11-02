## High-level convenience functions for complete workflows
## All IDs are preserved and returned in results

import std/[asyncdispatch, options, os]
import types, client, videoutils

proc uploadVideoComplete*(
  client: GanJingClient,
  videoPath: string,
  thumbnailPath: string = "",  # Now optional - will extract if empty
  channelId: ChannelId,
  metadata: VideoMetadata,
  waitForProcessing: bool = true,
  pollInterval: int = 5000,
  maxWaitTime: int = 600000,
  autoExtractThumbnail: bool = true  # Auto-extract if thumbnail not provided
): Future[CompleteUploadResult] {.async.} =
  ## Complete upload workflow: thumbnail → draft → video → status
  ## Returns: CompleteUploadResult with all IDs (contentId, videoId, imageId)
  ## 
  ## If thumbnailPath is empty and autoExtractThumbnail is true,
  ## will automatically extract first frame from video using ffmpeg.
  
  echo "=== Starting complete upload ==="
  echo &"Video: {videoPath}"
  
  # Handle thumbnail
  var actualThumbnailPath = thumbnailPath
  var extractedThumbnail = false
  
  if thumbnailPath == "" or not fileExists(thumbnailPath):
    if autoExtractThumbnail:
      if not hasFfmpeg():
        raise newException(OSError, 
          "No thumbnail provided and ffmpeg not available. " &
          "Please provide a thumbnail or install ffmpeg.")
      
      echo "→ No thumbnail provided, extracting from video..."
      actualThumbnailPath = extractFirstFrame(videoPath)
      extractedThumbnail = true
    else:
      raise newException(IOError, 
        "Thumbnail required but not provided: " & thumbnailPath)
  else:
    echo &"Thumbnail: {actualThumbnailPath}"
  
  # Step 1: Upload thumbnail
  let thumbResult = await client.uploadThumbnail(actualThumbnailPath)
  result.imageId = thumbResult.imageId
  
  # Clean up extracted thumbnail if we created it
  if extractedThumbnail:
    try:
      removeFile(actualThumbnailPath)
      echo &"→ Cleaned up temporary thumbnail"
    except:
      discard  # Ignore cleanup errors
  
  # Step 2: Create draft
  let contentResult = await client.createDraftVideo(
    channelId,
    metadata,
    thumbResult.url672,
    thumbResult.url1280
  )
  result.contentId = contentResult.contentId
  result.webUrl = getWebUrl(contentResult.contentId)
  
  # Step 3: Upload video
  let videoResult = await client.uploadVideo(
    videoPath,
    channelId,
    contentResult.contentId
  )
  result.videoId = videoResult.videoId
  
  # Step 4: Check status
  if waitForProcessing:
    echo "→ Waiting for video processing..."
    var elapsed = 0
    var status = await client.getVideoStatus(videoResult.videoId)
    
    while status.status != StatusProcessed and 
          status.status != StatusFailed and
          elapsed < maxWaitTime:
      await sleepAsync(pollInterval)
      elapsed += pollInterval
      status = await client.getVideoStatus(videoResult.videoId)
    
    result.processedStatus = status
    result.videoUrl = status.url
    
    if status.status == StatusProcessed:
      echo "✓ Video processed successfully"
    elif status.status == StatusFailed:
      echo "✗ Video processing failed"
    else:
      echo "⚠ Video still processing (timeout reached)"
  else:
    # Just get initial status
    result.processedStatus = await client.getVideoStatus(videoResult.videoId)
  
  echo &"=== Upload complete: {result.webUrl} ==="

proc waitForProcessing*(
  client: GanJingClient,
  videoId: VideoId,
  pollInterval: int = 5000,
  maxWaitTime: int = 600000
): Future[VideoStatusResult] {.async.} =
  ## Poll video status until processed or failed
  ## Returns: Final VideoStatusResult with videoId
  
  var elapsed = 0
  result = await client.getVideoStatus(videoId)
  
  while result.status != StatusProcessed and 
        result.status != StatusFailed and
        elapsed < maxWaitTime:
    await sleepAsync(pollInterval)
    elapsed += pollInterval
    result = await client.getVideoStatus(videoId)
    
    if result.progress > 0:
      echo &"  Processing: {result.progress}%"
