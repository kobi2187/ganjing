# GanJing World API Client for Nim

A Nim client library for uploading videos to the [GanJing World](https://www.ganjingworld.com) video platform.

**Current scope:** This library handles video uploads only. It does not support retrieving, updating, or deleting videos.

small, composable functions that give you control over your upload workflow.

## Features

- **Simple API** - One-line uploads for basic use cases
- **Composable** - Build custom workflows from primitives
- **Progress Tracking** - Real-time callbacks with phase and percentage
- **Complete Data Access** - All intermediate results preserved
- **Type-Safe IDs** - Distinct types prevent ID confusion
- **Error Handling** - Robust parsing with clear error messages
- **Token Management** - Automatic token refresh
- **Async/Await** - Non-blocking I/O
- **Auto Thumbnail Extraction** - Uses ffmpeg if thumbnail not provided

## Installation

```bash
nimble install ganjing
```

Or add to your `.nimble` file:
```nim
requires "ganjing >= 0.1.0"
```

## Quick Start

### Simple Upload

```nim
import asyncdispatch, ganjing

proc main() {.async.} =
  let client = newGanJingClient("your_access_token")

  let result = await client.upload(
    "video.mp4",
    ChannelId("your_channel_id"),
    VideoMetadata(
      title: "My Video",
      description: "Amazing content",
      category: CategoryTech,
      visibility: VisibilityPublic,
      lang: "en-US"
    )
  )

  echo result.webUrl
  client.close()

waitFor main()
```

## API Levels

The API provides multiple levels of abstraction:

### Level 1: Simple Upload (Recommended)

```nim
# Simplest possible - everything automatic
let result = await client.upload("video.mp4", channelId, metadata)
echo result.webUrl
```

**What it does:**
- Auto-extracts thumbnail if not provided (requires ffmpeg)
- Waits for video processing to complete
- Returns complete result with all IDs

### Level 2: With Progress Tracking

```nim
# Track upload progress
proc showProgress(p: UploadProgress) =
  echo &"[{p.percentComplete}%] {p.phase}: {p.message}"

let result = await client.upload(
  "video.mp4",
  channelId,
  metadata,
  thumbnail = "thumb.jpg",
  onProgress = showProgress
)
```

**Output:**
```
[  0%] PhaseGettingToken: Starting upload
[ 25%] PhaseUploadingThumbnail: Uploading thumbnail
[ 50%] PhaseCreatingDraft: Creating draft video
[ 75%] PhaseUploadingVideo: Uploading video file
[ 90%] PhaseWaitingForProcessing: Waiting for video processing
[100%] PhaseCompleted: Upload complete
```

### Level 3: Composable Workflow

```nim
# Upload assets and handle processing separately
let (thumbResult, contentResult, videoResult) = await client.uploadAssets(
  "video.mp4",
  "thumb.jpg",
  channelId,
  metadata
)

# Access intermediate data
echo "Thumbnail variants: ", thumbResult.allUrls.len
echo "  672x: ", thumbResult.url672
echo "  1280x: ", thumbResult.url1280
echo "  1920x: ", thumbResult.url1920

echo "Content ID: ", contentResult.contentId
echo "Video ID: ", videoResult.videoId

# Do custom processing...
# Save IDs to database, etc.

# Check processing status later
let status = await client.waitForProcessing(videoResult.videoId)
echo "Stream URL: ", status.url.get()
```

### Level 4: Full Control

```nim
# Complete control over every option
let result = await client.uploadVideoComplete(
  videoPath = "video.mp4",
  channelId = channelId,
  metadata = metadata,
  thumbnailPath = "thumb.jpg",
  waitForProcessing = false,        # Don't wait, return immediately
  pollInterval = 10000,             # Custom poll interval (ms)
  maxWaitTime = 300000,             # Custom timeout (ms)
  autoExtractThumbnail = true,      # Extract if needed
  onProgress = customProgressHandler
)

# Check status later
let status = await client.getVideoStatus(result.videoId)
if status.status == StatusProcessed:
  echo "Video ready: ", status.url.get()
elif status.status == StatusFailed:
  echo "Processing failed"
```

## Bulk Uploads

Example of uploading multiple videos with concurrency control:

```nim
proc uploadWithLimit(
  client: GanJingClient,
  videos: seq[VideoInfo],
  maxConcurrent: int = 3
): Future[seq[CompleteUploadResult]] {.async.} =
  var active: seq[Future[CompleteUploadResult]] = @[]
  var completed: seq[CompleteUploadResult] = @[]

  for i, video in videos:
    # Progress handler for this video
    proc progress(p: UploadProgress) =
      echo &"[Video {i+1}] [{p.percentComplete}%] {p.message}"

    # Start upload
    let uploadFuture = client.upload(
      video.path,
      channelId,
      video.metadata,
      onProgress = progress
    )

    active.add(uploadFuture)

    # Wait if we hit concurrency limit
    if active.len >= maxConcurrent:
      let finished = await active[0]
      completed.add(finished)
      active.delete(0)

  # Wait for remaining
  for fut in active:
    completed.add(await fut)

  return completed

# Use it
let results = await uploadWithLimit(client, videos, maxConcurrent = 2)

for result in results:
  echo "Video: ", result.webUrl
  echo "  Content ID: ", result.contentId
  echo "  Video ID: ", result.videoId
```

See `examples/bulk_upload_with_progress.nim` for a complete example.

## API Reference

### Client Initialization

```nim
let client = newGanJingClient(
  accessToken: string,
  verbose: bool = true  # Enable/disable logging
)
```

### High-Level Functions

#### upload()
Simplest API - automatic everything:
```nim
proc upload*(
  client: GanJingClient,
  videoPath: string,
  channelId: ChannelId,
  metadata: VideoMetadata,
  thumbnail: string = "",              # Optional, auto-extracts if empty
  onProgress: ProgressCallback = nil   # Optional progress tracking
): Future[CompleteUploadResult]
```

#### uploadAssets()
Returns all intermediate results for custom workflows:
```nim
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
]]
```

#### uploadVideoComplete()
Full control over all options:
```nim
proc uploadVideoComplete*(
  client: GanJingClient,
  videoPath: string,
  channelId: ChannelId,
  metadata: VideoMetadata,
  thumbnailPath: string = "",
  waitForProcessing: bool = true,
  pollInterval: int = 5000,            # ms between status checks
  maxWaitTime: int = 600000,           # max wait time (10 minutes)
  autoExtractThumbnail: bool = true,
  onProgress: ProgressCallback = nil
): Future[CompleteUploadResult]
```

#### waitForProcessing()
Poll video status until complete or timeout:
```nim
proc waitForProcessing*(
  client: GanJingClient,
  videoId: VideoId,
  pollInterval: int = 5000,
  maxWaitTime: int = 600000
): Future[VideoStatusResult]
```

### Core Operations

#### uploadThumbnail()
```nim
proc uploadThumbnail*(
  client: GanJingClient,
  imagePath: string,
  sizes: seq[int] = @[140,240,360,380,480,580,672,960,1280,1920]
): Future[ThumbnailResult]

# Returns:
#   imageId: ImageId
#   filename: string
#   allUrls: seq[string]         # All generated URLs
#   url672, url1280, url1920: string  # Common sizes
#   analyzedScore: float
#   extension: string
```

#### createDraftVideo()
```nim
proc createDraftVideo*(
  client: GanJingClient,
  channelId: ChannelId,
  metadata: VideoMetadata,
  posterUrl: string,
  posterHdUrl: string
): Future[ContentResult]

# Returns:
#   contentId: ContentId
#   ownerId: ChannelId
#   title, description, slug: string
#   categoryId, videoType, visibility: string
#   posterUrl, posterHdUrl: string
```

#### uploadVideo()
```nim
proc uploadVideo*(
  client: GanJingClient,
  videoPath: string,
  channelId: ChannelId,
  contentId: ContentId
): Future[VideoUploadResult]

# Returns:
#   videoId: VideoId
#   filename: string
```

#### getVideoStatus()
```nim
proc getVideoStatus*(
  client: GanJingClient,
  videoId: VideoId
): Future[VideoStatusResult]

# Returns:
#   videoId: VideoId
#   filename: string
#   status: ProcessingStatus  # StatusUploading, StatusInProgress,
#                             # StatusProcessed, StatusFailed, StatusUnknown
#   progress: int  # 0-100
#   url: Option[string]              # m3u8 stream URL when processed
#   durationSec: Option[float]
#   width, height: Option[int]
#   loudness: Option[string]
#   thumbBaseUrl: Option[string]
#   thumbSizes: Option[string]
```

### Authentication

```nim
# Get upload token (called automatically as needed, with expiry handling)
proc getUploadToken*(client: GanJingClient): Future[UploadTokenResponse]

# Refresh access token
proc refreshAccessToken*(client: GanJingClient): Future[RefreshTokenResponse]
```

## Data Types

### IDs (Type-Safe)
```nim
ContentId   # Video content identifier
VideoId     # Video file identifier
ImageId     # Thumbnail image identifier
ChannelId   # Channel identifier
```

Convert to string: `$contentId`

### Metadata
```nim
VideoMetadata(
  title: string,
  description: string,
  category: Category,
  visibility: Visibility,
  lang: string  # e.g., "en-US"
)
```

### Enums

#### Categories
All 45 GanJing World categories (note: cat10 and cat28 are missing from the API):
```nim
CategoryArchitecture, CategoryArts, CategoryAutos, CategoryBeauty,
CategoryBusiness, CategoryLifeHacks, CategoryEducation, CategoryEntertainment,
CategoryFood, CategoryGovernment, CategoryHealth, CategoryCulture, CategoryKids,
CategoryLifestyle, CategoryMilitary, CategoryPopularMusic, CategoryNature,
CategoryTalkShows, CategoryNonprofit, CategoryPets, CategoryFinance, CategoryTech,
CategoryReligion, CategorySports, CategoryMysteries, CategoryTravel,
CategoryRelationship, CategoryDance, CategoryCareer, CategoryNews, CategoryTv,
CategoryClassicalMusic, CategoryHistory, CategoryFashion, CategoryLaw,
CategoryImmigration, CategoryPeople, CategoryLiterature,
CategoryIndustrialTechnology, CategoryAgriculture, CategoryHomeProject,
CategorySculpture, CategoryCaligraphy, CategoryPhotography, CategoryMovies
```

#### Visibility
```nim
VisibilityPublic, VisibilityPrivate, VisibilityUnlisted
```

#### Processing Status
```nim
StatusUploading     # Video is uploading
StatusInProgress    # Video is being processed
StatusProcessed     # Video processing complete
StatusFailed        # Video processing failed
StatusUnknown       # Unknown status (unexpected API response)
```

#### Upload Phase
```nim
PhaseNotStarted              # Not started
PhaseGettingToken            # Getting upload token
PhaseUploadingThumbnail      # Uploading thumbnail
PhaseCreatingDraft           # Creating draft video
PhaseUploadingVideo          # Uploading video file
PhaseCheckingStatus          # Checking initial status
PhaseWaitingForProcessing    # Waiting for processing
PhaseCompleted               # Upload complete
PhaseFailed                  # Upload failed
```

### Progress Tracking
```nim
UploadProgress(
  phase: UploadPhase,
  message: string,
  percentComplete: int  # 0-100
)

ProgressCallback = proc(progress: UploadProgress) {.closure.}
```

### Complete Upload Result

```nim
CompleteUploadResult(
  # Quick access IDs
  contentId: ContentId,
  videoId: VideoId,
  imageId: ImageId,
  webUrl: string,
  videoUrl: Option[string],           # m3u8 stream URL if processed

  # Complete intermediate results with all metadata
  thumbnailResult: ThumbnailResult,   # Complete thumbnail data
  contentResult: ContentResult,       # Complete content data
  videoResult: VideoUploadResult,     # Complete video data
  processedStatus: VideoStatusResult, # Complete status data

  # Progress tracking
  currentPhase: UploadPhase,
  completedAt: Option[int64]          # Unix timestamp when completed
)
```

## Error Handling

The library provides robust error handling for API responses:

```nim
try:
  let result = await client.upload("video.mp4", channelId, metadata)
  echo result.webUrl
except ParseError as e:
  echo "Failed to parse API response: ", e.msg
except IOError as e:
  echo "File error: ", e.msg
except OSError as e:
  echo "System error: ", e.msg
```

**ParseError** is raised when:
- JSON response is malformed
- Required fields are missing from API response
- API returns unexpected data format

## Examples

See the `examples/` directory:

- **`simple_upload.nim`** - Basic usage
- **`elegant_upload.nim`** - Minimal one-line upload
- **`using_ids.nim`** - Working with IDs
- **`progress_tracking.nim`** - Progress monitoring
- **`bulk_upload_with_progress.nim`** - Concurrent uploads
- **`auto_thumbnail.nim`** - Auto thumbnail extraction

## Testing

### Unit Tests
```bash
nimble test
```

### Integration Tests
Requires real API credentials:
```bash
export GANJING_ACCESS_TOKEN="your_token"
export GANJING_CHANNEL_ID="your_channel_id"
nim c -r tests/test_real_api.nim
```

## Architecture

Built with Forth philosophy - small, composable functions:

```
Layer 4: High-Level API
   ↓
   upload()
   uploadVideoComplete()

Layer 3: Workflows
   ↓
   uploadAssets()
   waitForProcessing()

Layer 2: Operations
   ↓
   uploadThumbnail()
   createDraftVideo()
   uploadVideo()
   getVideoStatus()

Layer 1: Primitives
   ↓
   prepareImageData(), setUploadHeaders(),
   executeImageUpload(), buildSizesHeader(),
   makeImageMultipart(), readFileData(),
   ensureUploadToken(), etc.
```

See [FORTH_PHILOSOPHY.md](FORTH_PHILOSOPHY.md) for details.

## Design Principles

1. **Small Functions** - Each function has a single responsibility
2. **Deep Composition** - 4-layer architecture
3. **All Data Preserved** - Every intermediate result accessible
4. **Progress Tracking** - Real-time callbacks throughout
5. **Type Safety** - Distinct types prevent errors
6. **Error Handling** - Clear exceptions for external data
7. **Async First** - All I/O is non-blocking
8. **Token Management** - Automatic refresh with expiry tracking

## API Endpoints

Endpoints used:
- `gw.ganjingworld.com/v1.0c` - Authentication and content management
- `imgapi.cloudokyo.cloud/api/v1` - Image/thumbnail uploads
- `vodapi.cloudokyo.cloud/api/v1` - Video uploads and status

## Performance Tips

1. **Disable verbose logging for bulk uploads:**
   ```nim
   let client = newGanJingClient(accessToken, verbose = false)
   ```

2. **Limit concurrent uploads to avoid overwhelming the API:**
   ```nim
   let results = await uploadWithLimit(client, videos, maxConcurrent = 3)
   ```

3. **Don't wait for processing if not needed:**
   ```nim
   let result = await client.uploadVideoComplete(
     ...,
     waitForProcessing = false  # Return immediately
   )
   # Poll later when needed
   let status = await client.waitForProcessing(result.videoId)
   ```

4. **Use uploadAssets() for custom workflows:**
   ```nim
   # Upload all assets immediately
   let (thumb, content, video) = await client.uploadAssets(...)

   # Store IDs in database
   db.save(content.contentId, video.videoId, thumb.imageId)

   # Check processing status later
   let status = await client.getVideoStatus(video.videoId)
   ```

## Limitations

- **Upload only** - No support for retrieving, updating, or deleting videos
- **Memory usage** - Entire files are loaded into memory (not suitable for very large files)
- **No retry logic** - Network failures are not automatically retried
- **Single token** - Only one access token per client instance

## License

MIT

## Contributing

Contributions welcome! Please ensure:
- Functions remain focused and composable
- All intermediate results are preserved
- Error handling is robust
- Tests are added for new features
- Documentation is updated

See [FORTH_PHILOSOPHY.md](FORTH_PHILOSOPHY.md) for design guidelines.
