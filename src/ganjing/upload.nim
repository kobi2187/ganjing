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
# MID-LEVEL OPERATIONS - Forth-style: small, composed functions
# ============================================================================

proc logUploadStart(client: GanJingClient, videoPath: string, onProgress: ProgressCallback) =
  ## Log upload start (Forth: one tiny task)
  client.log("=== Starting upload ===")
  client.log(&"Video: {videoPath}")
  notifyProgress(onProgress, PhaseGettingToken, "Starting upload", 0)

proc logThumbnailPrep(client: GanJingClient, thumbPath: string, wasExtracted: bool) =
  ## Log thumbnail preparation (Forth: one tiny task)
  if wasExtracted:
    client.log("→ Extracted thumbnail from video")
  else:
    client.log(&"Thumbnail: {thumbPath}")

proc uploadThumbnailStep(
  client: GanJingClient,
  thumbPath: string,
  wasExtracted: bool,
  onProgress: ProgressCallback
): Future[ThumbnailResult] {.async.} =
  ## Upload thumbnail and cleanup (Forth: one composite task)
  notifyProgress(onProgress, PhaseUploadingThumbnail, "Uploading thumbnail", 25)
  result = await client.uploadThumbnail(thumbPath)

  if wasExtracted:
    cleanupTempFile(thumbPath)
    client.log("→ Cleaned up temporary thumbnail")

proc createDraftStep(
  client: GanJingClient,
  channelId: ChannelId,
  metadata: VideoMetadata,
  thumbResult: ThumbnailResult,
  onProgress: ProgressCallback
): Future[ContentResult] {.async.} =
  ## Create draft with progress (Forth: one composite task)
  notifyProgress(onProgress, PhaseCreatingDraft, "Creating draft video", 50)
  result = await client.createDraftVideo(channelId, metadata, thumbResult.url672, thumbResult.url1280)

proc uploadVideoStep(
  client: GanJingClient,
  videoPath: string,
  channelId: ChannelId,
  contentId: ContentId,
  onProgress: ProgressCallback
): Future[VideoUploadResult] {.async.} =
  ## Upload video with progress (Forth: one composite task)
  notifyProgress(onProgress, PhaseUploadingVideo, "Uploading video file", 75)
  result = await client.uploadVideo(videoPath, channelId, contentId)

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
  ## Upload assets - composed of small steps (Forth style)
  client.logUploadStart(videoPath, onProgress)

  let (thumbPath, wasExtracted) = prepareThumbnail(videoPath, thumbnailPath, autoExtractThumbnail)
  client.logThumbnailPrep(thumbPath, wasExtracted)

  let thumbResult = await client.uploadThumbnailStep(thumbPath, wasExtracted, onProgress)
  let contentResult = await client.createDraftStep(channelId, metadata, thumbResult, onProgress)
  let videoResult = await client.uploadVideoStep(videoPath, channelId, contentResult.contentId, onProgress)

  result = (thumbResult, contentResult, videoResult)

# ============================================================================
# HIGH-LEVEL API - Simple, elegant interface
# ============================================================================

proc populateUploadResult(
  result: var CompleteUploadResult,
  thumbResult: ThumbnailResult,
  contentResult: ContentResult,
  videoResult: VideoUploadResult
) =
  ## Populate result with all intermediate data (Forth: one tiny task)
  result.thumbnailResult = thumbResult
  result.contentResult = contentResult
  result.videoResult = videoResult
  result.contentId = contentResult.contentId
  result.videoId = videoResult.videoId
  result.imageId = thumbResult.imageId
  result.webUrl = getWebUrl(contentResult.contentId)

proc waitAndGetStatus(
  client: GanJingClient,
  videoId: VideoId,
  pollInterval, maxWaitTime: int,
  onProgress: ProgressCallback
): Future[VideoStatusResult] {.async.} =
  ## Wait for processing and get status (Forth: one composite task)
  client.log("→ Waiting for video processing...")
  notifyProgress(onProgress, PhaseWaitingForProcessing, "Waiting for video processing", 90)
  result = await client.pollUntilReady(videoId, pollInterval, maxWaitTime)

proc getInitialStatus(
  client: GanJingClient,
  videoId: VideoId,
  onProgress: ProgressCallback
): Future[VideoStatusResult] {.async.} =
  ## Check initial status without waiting (Forth: one composite task)
  notifyProgress(onProgress, PhaseCheckingStatus, "Checking initial status", 90)
  result = await client.getVideoStatus(videoId)

proc updateResultWithStatus(
  result: var CompleteUploadResult,
  status: VideoStatusResult,
  phase: UploadPhase,
  webUrl: string,
  client: GanJingClient
) =
  ## Update result with status (Forth: one tiny task)
  result.processedStatus = status
  result.videoUrl = status.url
  result.currentPhase = phase
  if phase == PhaseCompleted:
    client.logUploadStatus(status.status, webUrl)

proc finalizeUpload(
  client: GanJingClient,
  result: var CompleteUploadResult,
  onProgress: ProgressCallback
) =
  ## Finalize upload with timestamp and notification (Forth: one tiny task)
  result.completedAt = some(getTime().toUnix())
  notifyProgress(onProgress, PhaseCompleted, "Upload complete", 100)
  client.log(&"=== Upload complete: {result.webUrl} ===")

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
  ## Complete upload - composed of small steps (Forth style)
  let (thumbResult, contentResult, videoResult) = await client.uploadAssets(
    videoPath, thumbnailPath, channelId, metadata, autoExtractThumbnail, onProgress
  )

  result.populateUploadResult(thumbResult, contentResult, videoResult)

  let status = if waitForProcessing:
    await client.waitAndGetStatus(videoResult.videoId, pollInterval, maxWaitTime, onProgress)
  else:
    await client.getInitialStatus(videoResult.videoId, onProgress)

  let phase = if waitForProcessing: PhaseCompleted else: PhaseCheckingStatus
  result.updateResultWithStatus(status, phase, result.webUrl, client)

  client.finalizeUpload(result, onProgress)

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
