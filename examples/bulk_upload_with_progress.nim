## Bulk Upload Example with Progress Tracking
## Demonstrates:
## - Progress callbacks for monitoring uploads
## - Limiting concurrent uploads
## - Accessing all intermediate results
## - Building upload queues

import asyncdispatch, os, times
import std/[strformat, options, deques]
import ganjing

type
  UploadJob = object
    videoPath: string
    thumbnailPath: string
    metadata: VideoMetadata

# ============================================================================
# Progress Tracking
# ============================================================================

proc makeProgressHandler(jobId: string): ProgressCallback =
  ## Create a progress callback for a specific job
  result = proc(p: UploadProgress) =
    echo &"[Job {jobId}] [{p.percentComplete:3}%] {p.phase}: {p.message}"

# ============================================================================
# Concurrent Upload Manager
# ============================================================================

proc uploadWithLimit(
  client: GanJingClient,
  jobs: seq[UploadJob],
  channelId: ChannelId,
  maxConcurrent: int = 3
): Future[seq[CompleteUploadResult]] {.async.} =
  ## Upload multiple videos with concurrency limit
  ## Returns all results with complete intermediate data

  var
    queue = jobs.toDeque()
    active: seq[Future[CompleteUploadResult]] = @[]
    completed: seq[CompleteUploadResult] = @[]
    jobCounter = 0

  echo &"=== Starting bulk upload: {jobs.len} videos, max {maxConcurrent} concurrent ==="
  echo ""

  while queue.len > 0 or active.len > 0:
    # Start new uploads if we have capacity
    while queue.len > 0 and active.len < maxConcurrent:
      let job = queue.popFirst()
      inc jobCounter
      let jobId = &"video-{jobCounter}"

      # Create progress callback
      let progressHandler = makeProgressHandler(jobId)

      # Start upload (non-blocking)
      echo &"[Job {jobId}] Starting upload: {job.videoPath}"
      let uploadFuture = client.upload(
        job.videoPath,
        channelId,
        job.metadata,
        thumbnail = job.thumbnailPath,
        onProgress = progressHandler
      )

      active.add(uploadFuture)

    # Wait for at least one to complete
    if active.len > 0:
      # This is a simple approach - wait for any one
      await sleepAsync(100)

      # Check for completed uploads
      var stillActive: seq[Future[CompleteUploadResult]] = @[]
      for fut in active:
        if fut.finished:
          let result = fut.read()
          completed.add(result)
          echo ""
          echo &"✓ Upload completed: {result.webUrl}"
          echo &"  All intermediate results available:"
          echo &"    - Thumbnail: {result.thumbnailResult.allUrls.len} URLs"
          echo &"    - Content:   {result.contentResult.title}"
          echo &"    - Video:     {result.videoResult.filename}"
          echo &"    - Status:    {result.processedStatus.status}"
          echo ""
        else:
          stillActive.add(fut)

      active = stillActive

  result = completed

# ============================================================================
# Example Usage
# ============================================================================

proc main() {.async.} =
  let accessToken = getEnv("GANJING_ACCESS_TOKEN")
  let channelId = ChannelId(getEnv("GANJING_CHANNEL_ID"))

  if accessToken == "" or $channelId == "":
    echo "Set GANJING_ACCESS_TOKEN and GANJING_CHANNEL_ID"
    quit(1)

  # Create client (can disable verbose for cleaner progress output)
  let client = newGanJingClient(accessToken, verbose = false)

  try:
    # Define upload jobs
    let jobs = @[
      UploadJob(
        videoPath: "video1.mp4",
        thumbnailPath: "thumb1.jpg",
        metadata: VideoMetadata(
          title: "First Video",
          description: "Bulk upload test 1",
          category: CategoryTechnology,
          visibility: VisibilityPublic,
          lang: "en-US"
        )
      ),
      UploadJob(
        videoPath: "video2.mp4",
        thumbnailPath: "thumb2.jpg",
        metadata: VideoMetadata(
          title: "Second Video",
          description: "Bulk upload test 2",
          category: CategoryTechnology,
          visibility: VisibilityPublic,
          lang: "en-US"
        )
      ),
      UploadJob(
        videoPath: "video3.mp4",
        thumbnailPath: "",  # Will auto-extract
        metadata: VideoMetadata(
          title: "Third Video",
          description: "Bulk upload test 3",
          category: CategoryTechnology,
          visibility: VisibilityPublic,
          lang: "en-US"
        )
      )
    ]

    # Upload with concurrency limit
    let results = await client.uploadWithLimit(jobs, channelId, maxConcurrent = 2)

    echo "=== All uploads completed ==="
    echo ""
    echo "Results summary:"
    for i, result in results:
      echo &"{i+1}. {result.contentResult.title}"
      echo &"   URL: {result.webUrl}"
      echo &"   IDs: content={result.contentId}, video={result.videoId}, image={result.imageId}"

      # Access ALL intermediate results
      echo &"   Thumbnail URLs: {result.thumbnailResult.allUrls.len} variants"
      echo &"   Created at: {result.contentResult.createdAt}"
      echo &"   Video filename: {result.videoResult.filename}"

      if result.processedStatus.url.isSome():
        echo &"   Stream URL: {result.processedStatus.url.get()}"

      if result.processedStatus.durationSec.isSome():
        echo &"   Duration: {result.processedStatus.durationSec.get()}s"

      echo ""

  finally:
    client.close()

when isMainModule:
  waitFor main()
