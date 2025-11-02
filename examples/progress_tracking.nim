## Progress Tracking Example
## Shows how to monitor upload progress and access all intermediate results

import asyncdispatch, os
import std/[strformat, options, times]
import ganjing

proc main() {.async.} =
  let accessToken = getEnv("GANJING_ACCESS_TOKEN")
  let channelId = ChannelId(getEnv("GANJING_CHANNEL_ID"))

  if accessToken == "" or $channelId == "":
    echo "Set GANJING_ACCESS_TOKEN and GANJING_CHANNEL_ID"
    quit(1)

  # Create client (disable verbose for cleaner progress output)
  let client = newGanJingClient(accessToken, verbose = false)

  try:
    # Define metadata
    let metadata = VideoMetadata(
      title: "Progress Tracking Demo",
      description: "Video uploaded with progress tracking",
      category: CategoryTechnology,
      visibility: VisibilityPublic,
      lang: "en-US"
    )

    # ========================================================================
    # Example 1: Simple progress callback
    # ========================================================================

    echo "=== Example 1: Simple Progress Display ==="
    echo ""

    proc showProgress(p: UploadProgress) =
      echo &"[{p.percentComplete:3}%] {p.phase}: {p.message}"

    let result1 = await client.upload(
      "video.mp4",
      channelId,
      metadata,
      onProgress = showProgress
    )

    echo ""
    echo &"✓ Upload complete: {result1.webUrl}"
    echo ""

    # ========================================================================
    # Example 2: Detailed progress with ETA calculation
    # ========================================================================

    echo "=== Example 2: Detailed Progress with Timing ==="
    echo ""

    var startTime = getTime()

    proc detailedProgress(p: UploadProgress) =
      let elapsed = (getTime() - startTime).inSeconds
      let eta = if p.percentComplete > 0:
        (elapsed * (100 - p.percentComplete)) div p.percentComplete
      else:
        0

      echo &"[{p.percentComplete:3}%] {p.phase}"
      echo &"  Message: {p.message}"
      echo &"  Elapsed: {elapsed}s, ETA: {eta}s"
      echo ""

    startTime = getTime()
    let result2 = await client.upload(
      "another_video.mp4",
      channelId,
      metadata,
      onProgress = detailedProgress
    )

    echo &"✓ Upload complete: {result2.webUrl}"
    echo ""

    # ========================================================================
    # Example 3: Access ALL intermediate results
    # ========================================================================

    echo "=== Example 3: Accessing All Intermediate Results ==="
    echo ""

    # Use result from previous upload
    let result = result2

    echo "Quick Access IDs:"
    echo &"  Content ID: {result.contentId}"
    echo &"  Video ID:   {result.videoId}"
    echo &"  Image ID:   {result.imageId}"
    echo &"  Web URL:    {result.webUrl}"
    echo ""

    echo "Full Thumbnail Result:"
    echo &"  Image ID:      {result.thumbnailResult.imageId}"
    echo &"  Filename:      {result.thumbnailResult.filename}"
    echo &"  All URLs:      {result.thumbnailResult.allUrls.len} variants"
    echo &"  Standard URL:  {result.thumbnailResult.url672}"
    echo &"  HD URL:        {result.thumbnailResult.url1280}"
    echo &"  Full HD URL:   {result.thumbnailResult.url1920}"
    echo &"  Extension:     {result.thumbnailResult.extension}"
    echo &"  Score:         {result.thumbnailResult.analyzedScore}"
    echo ""

    echo "Full Content Result:"
    echo &"  Content ID:    {result.contentResult.contentId}"
    echo &"  Owner ID:      {result.contentResult.ownerId}"
    echo &"  Title:         {result.contentResult.title}"
    echo &"  Description:   {result.contentResult.description}"
    echo &"  Slug:          {result.contentResult.slug}"
    echo &"  Category:      {result.contentResult.categoryId}"
    echo &"  Visibility:    {result.contentResult.visibility}"
    echo &"  Video Type:    {result.contentResult.videoType}"
    echo &"  Created At:    {result.contentResult.createdAt}"
    echo &"  View Count:    {result.contentResult.viewCount}"
    echo &"  Like Count:    {result.contentResult.likeCount}"
    echo &"  Comment Count: {result.contentResult.commentCount}"
    echo ""

    echo "Full Video Upload Result:"
    echo &"  Video ID:      {result.videoResult.videoId}"
    echo &"  Filename:      {result.videoResult.filename}"
    echo ""

    echo "Full Processing Status:"
    echo &"  Video ID:      {result.processedStatus.videoId}"
    echo &"  Filename:      {result.processedStatus.filename}"
    echo &"  Status:        {result.processedStatus.status}"
    echo &"  Progress:      {result.processedStatus.progress}%"

    if result.processedStatus.url.isSome():
      echo &"  Video URL:     {result.processedStatus.url.get()}"

    if result.processedStatus.durationSec.isSome():
      echo &"  Duration:      {result.processedStatus.durationSec.get()}s"

    if result.processedStatus.width.isSome() and result.processedStatus.height.isSome():
      echo &"  Resolution:    {result.processedStatus.width.get()}x{result.processedStatus.height.get()}"

    if result.processedStatus.loudness.isSome():
      echo &"  Loudness:      {result.processedStatus.loudness.get()}"

    if result.processedStatus.thumbBaseUrl.isSome():
      echo &"  Thumb Base:    {result.processedStatus.thumbBaseUrl.get()}"

    echo ""

    echo "Upload Metadata:"
    echo &"  Current Phase: {result.currentPhase}"
    if result.completedAt.isSome():
      echo &"  Completed At:  {result.completedAt.get()} (Unix timestamp)"
    echo ""

    # ========================================================================
    # Example 4: Composable workflow with progress tracking
    # ========================================================================

    echo "=== Example 4: Composable Workflow ==="
    echo ""

    var phase = PhaseNotStarted

    proc trackPhase(p: UploadProgress) =
      if p.phase != phase:
        phase = p.phase
        echo &"→ Phase changed to: {p.phase}"

    # Upload assets only (no waiting for processing)
    let (thumbRes, contentRes, videoRes) = await client.uploadAssets(
      "video.mp4",
      "thumb.jpg",
      channelId,
      metadata,
      onProgress = trackPhase
    )

    echo ""
    echo "Assets uploaded, IDs available:"
    echo &"  Image ID:   {thumbRes.imageId}"
    echo &"  Content ID: {contentRes.contentId}"
    echo &"  Video ID:   {videoRes.videoId}"
    echo ""
    echo "Can now do custom processing, store in DB, etc."
    echo ""

    # Later, check status
    echo "Checking video status..."
    let status = await client.getVideoStatus(videoRes.videoId)
    echo &"Status: {status.status}, Progress: {status.progress}%"

  finally:
    client.close()

when isMainModule:
  waitFor main()
