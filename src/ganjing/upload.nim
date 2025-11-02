## High-level convenience functions for complete workflows
## All IDs and intermediate results are preserved and returned

import std/[asyncdispatch, os, strformat, times, options]
import types, client, videoutils

# ============================================================================
# PROGRESS TRACKING HELPERS
# ============================================================================

proc notifyProgress(callback: ProgressCallback, phase: UploadPhase,
                   message: string, percent: int) =
  ## Helper to call progress callback if provided
  if callback != nil:
    callback(UploadProgress(
      phase: phase,
      message: message,
      percentComplete: percent
    ))

# ============================================================================
# LOW-LEVEL HELPERS - Primitives for upload workflows
# ============================================================================

proc prepareThumbnail(
  videoPath: string,
  thumbnailPath: string,
  autoExtract: bool
): tuple[path: string, wasExtracted: bool] =
  ## Prepare thumbnail - use provided or extract from video
  ## Returns: (thumbnail path, whether it was extracted)

  if thumbnailPath != "" and fileExists(thumbnailPath):
    return (thumbnailPath, false)

  if not autoExtract:
    raise newException(IOError, "Thumbnail required but not provided: " & thumbnailPath)

  if not hasFfmpeg():
    raise newException(OSError,
      "No thumbnail provided and ffmpeg not available. " &
      "Please provide a thumbnail or install ffmpeg.")

  let extracted = extractFirstFrame(videoPath)
  return (extracted, true)

proc cleanupTempFile(path: string) =
  ## Safely remove temporary file, ignore errors
  try:
    removeFile(path)
  except:
    discard

proc pollUntilReady(
  client: GanJingClient,
  videoId: VideoId,
  pollInterval: int,
  maxWaitTime: int
): Future[VideoStatusResult] {.async.} =
  ## Poll video status until processed/failed or timeout
  ## Returns: Final status

  var elapsed = 0
  result = await client.getVideoStatus(videoId)

  while result.status != StatusProcessed and
        result.status != StatusFailed and
        elapsed < maxWaitTime:
    await sleepAsync(pollInterval)
    elapsed += pollInterval
    result = await client.getVideoStatus(videoId)

    if result.progress > 0 and client.verbose:
      echo &"  Processing: {result.progress}%"

proc logUploadStatus(client: GanJingClient, status: ProcessingStatus, url: string) =
  ## Log final upload status
  case status
  of StatusProcessed:
    client.log("✓ Video processed successfully")
  of StatusFailed:
    client.log("✗ Video processing failed")
  else:
    client.log("⚠ Video still processing (timeout reached)")

# ============================================================================
# MID-LEVEL OPERATIONS - Composable workflow steps
# ============================================================================

proc uploadAssets*(
  client: GanJingClient,
  videoPath: string,
  thumbnailPath: string,
  channelId: ChannelId,
  metadata: VideoMetadata,
  autoExtractThumbnail: bool = true,
  onProgress: ProgressCallback = nil
): Future[tuple[
  thumbnailResult: ThumbnailResult,
  contentResult: ContentResult,
  videoResult: VideoUploadResult
]] {.async.} =
  ## Upload thumbnail, create draft, upload video
  ## Returns: ALL intermediate results (not just IDs)

  client.log("=== Starting upload ==="  )
  client.log(&"Video: {videoPath}")
  notifyProgress(onProgress, PhaseGettingToken, "Starting upload", 0)

  # Prepare thumbnail
  let (thumbPath, wasExtracted) = prepareThumbnail(videoPath, thumbnailPath, autoExtractThumbnail)

  if wasExtracted:
    client.log("→ Extracted thumbnail from video")
  else:
    client.log(&"Thumbnail: {thumbPath}")

  # Upload thumbnail
  notifyProgress(onProgress, PhaseUploadingThumbnail, "Uploading thumbnail", 25)
  let thumbResult = await client.uploadThumbnail(thumbPath)

  if wasExtracted:
    cleanupTempFile(thumbPath)
    client.log("→ Cleaned up temporary thumbnail")

  # Create draft
  notifyProgress(onProgress, PhaseCreatingDraft, "Creating draft video", 50)
  let contentResult = await client.createDraftVideo(
    channelId,
    metadata,
    thumbResult.url672,
    thumbResult.url1280
  )

  # Upload video
  notifyProgress(onProgress, PhaseUploadingVideo, "Uploading video file", 75)
  let videoResult = await client.uploadVideo(
    videoPath,
    channelId,
    contentResult.contentId
  )

  # Return ALL results, not just IDs
  result = (thumbResult, contentResult, videoResult)

# ============================================================================
# HIGH-LEVEL API - Simple, elegant interface
# ============================================================================

proc uploadVideoComplete*(
  client: GanJingClient,
  videoPath: string,
  channelId: ChannelId,
  metadata: VideoMetadata,
  thumbnailPath: string = "",
  waitForProcessing: bool = true,
  pollInterval: int = 5000,
  maxWaitTime: int = 600000,
  autoExtractThumbnail: bool = true,
  onProgress: ProgressCallback = nil
): Future[CompleteUploadResult] {.async.} =
  ## Complete upload workflow: thumbnail → draft → video → status
  ## Returns: CompleteUploadResult with ALL intermediate results
  ##
  ## If thumbnailPath is empty and autoExtractThumbnail is true,
  ## will automatically extract first frame from video using ffmpeg.
  ##
  ## onProgress: Optional callback to track upload progress

  # Upload all assets
  let (thumbResult, contentResult, videoResult) = await client.uploadAssets(
    videoPath,
    thumbnailPath,
    channelId,
    metadata,
    autoExtractThumbnail,
    onProgress
  )

  # Populate ALL intermediate results
  result.thumbnailResult = thumbResult
  result.contentResult = contentResult
  result.videoResult = videoResult

  # Quick access IDs
  result.contentId = contentResult.contentId
  result.videoId = videoResult.videoId
  result.imageId = thumbResult.imageId
  result.webUrl = getWebUrl(contentResult.contentId)

  # Check/wait for processing
  if waitForProcessing:
    client.log("→ Waiting for video processing...")
    notifyProgress(onProgress, PhaseWaitingForProcessing, "Waiting for video processing", 90)

    result.processedStatus = await client.pollUntilReady(videoResult.videoId, pollInterval, maxWaitTime)
    result.videoUrl = result.processedStatus.url
    result.currentPhase = PhaseCompleted

    client.logUploadStatus(result.processedStatus.status, result.webUrl)
  else:
    notifyProgress(onProgress, PhaseCheckingStatus, "Checking initial status", 90)
    result.processedStatus = await client.getVideoStatus(videoResult.videoId)
    result.currentPhase = PhaseCheckingStatus

  result.completedAt = some(getTime().toUnix())
  notifyProgress(onProgress, PhaseCompleted, "Upload complete", 100)

  client.log(&"=== Upload complete: {result.webUrl} ===")

proc waitForProcessing*(
  client: GanJingClient,
  videoId: VideoId,
  pollInterval: int = 5000,
  maxWaitTime: int = 600000
): Future[VideoStatusResult] {.async.} =
  ## Poll video status until processed or failed
  ## Returns: Final VideoStatusResult with videoId
  result = await client.pollUntilReady(videoId, pollInterval, maxWaitTime)

# ============================================================================
# SUPER SIMPLE API - Most elegant, minimal interface
# ============================================================================

proc upload*(
  client: GanJingClient,
  videoPath: string,
  channelId: ChannelId,
  metadata: VideoMetadata,
  thumbnail: string = "",
  onProgress: ProgressCallback = nil
): Future[CompleteUploadResult] {.async.} =
  ## Simplest upload API - just video, channel, metadata
  ## Automatically extracts thumbnail if not provided
  ## Waits for processing by default
  ##
  ## Example:
  ##   let result = await client.upload("video.mp4", channelId, metadata)
  ##   echo result.webUrl
  ##
  ## With progress tracking:
  ##   proc showProgress(p: UploadProgress) =
  ##     echo &"[{p.percentComplete}%] {p.phase}: {p.message}"
  ##
  ##   let result = await client.upload("video.mp4", channelId, metadata,
  ##                                     onProgress = showProgress)
  result = await client.uploadVideoComplete(
    videoPath,
    channelId,
    metadata,
    thumbnailPath = thumbnail,
    waitForProcessing = true,
    autoExtractThumbnail = true,
    onProgress = onProgress
  )
