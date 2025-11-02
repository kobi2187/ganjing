# GanJing World API Client for Nim

An idiomatic, elegant Nim client library for the [GanJing World](https://www.ganjingworld.com) video platform API.

## Features

- ✅ **All IDs Exposed** - Every API call returns complete results with all IDs for direct use
- ✅ **Small, Focused Functions** - Each function does one thing and returns structured data
- ✅ **Type-Safe** - Distinct types for ContentId, VideoId, ImageId, ChannelId
- ✅ **Async/Await** - Non-blocking I/O for efficient operations
- ✅ **Complete Workflow** - High-level functions for common tasks
- ✅ **Zero Dependencies** - Uses only stdlib (optional: no external deps)
- ✅ **Comprehensive Tests** - Unit tests for all response parsing
- ✅ **Echo Results** - All operations echo their results for visibility

## Installation

```bash
nimble install ganjing
```

Or add to your `.nimble` file:
```nim
requires "ganjing >= 0.1.0"
```

## Quick Start

```nim
import asyncdispatch, ganjing

proc main() {.async.} =
  let client = newGanJingClient("your_access_token")
  
  # Complete upload workflow
  let result = await client.uploadVideoComplete(
    videoPath = "myvideo.mp4",
    thumbnailPath = "thumbnail.jpg",
    channelId = ChannelId("your_channel_id"),
    metadata = VideoMetadata(
      title: "My Awesome Video",
      description: "Video description here",
      category: CategoryTechnology,
      visibility: VisibilityPublic,
      lang: "en-US"
    )
  )
  
  # All IDs are directly accessible
  echo "Content ID: ", result.contentId
  echo "Video ID: ", result.videoId
  echo "Image ID: ", result.imageId
  echo "Watch at: ", result.webUrl
  
  client.close()

waitFor main()
```

## API Overview

### Client Initialization

```nim
let client = newGanJingClient(accessToken: string)
```

### Authentication

```nim
# Get upload token (automatic when needed)
let tokenResp = await client.getUploadToken()
echo tokenResp.token

# Refresh access token
let refreshResp = await client.refreshAccessToken()
echo refreshResp.token  # New access token
echo refreshResp.refreshToken  # New refresh token
```

### Upload Thumbnail

```nim
let thumbResult = await client.uploadThumbnail("image.jpg")
echo thumbResult.imageId       # ImageId exposed
echo thumbResult.url672        # Standard poster
echo thumbResult.url1280       # HD poster
echo thumbResult.allUrls.len   # All generated URLs
```

### Create Draft Video

```nim
let contentResult = await client.createDraftVideo(
  channelId,
  metadata,
  thumbResult.url672,
  thumbResult.url1280
)
echo contentResult.contentId    # ContentId exposed
echo contentResult.ownerId      # ChannelId exposed
echo contentResult.title
echo contentResult.slug
```

### Upload Video File

```nim
let videoResult = await client.uploadVideo(
  "video.mp4",
  channelId,
  contentResult.contentId
)
echo videoResult.videoId        # VideoId exposed
echo videoResult.filename
```

### Check Processing Status

```nim
let status = await client.getVideoStatus(videoResult.videoId)
echo status.videoId             # VideoId exposed
echo status.status              # ProcessingStatus enum
echo status.progress            # 0-100%

if status.url.isSome:
  echo status.url.get()         # m3u8 stream URL
if status.durationSec.isSome:
  echo status.durationSec.get() # Duration in seconds
```

### Complete Workflow (High-Level)

```nim
let result = await client.uploadVideoComplete(
  videoPath = "video.mp4",
  thumbnailPath = "thumb.jpg",
  channelId = ChannelId("channel_id"),
  metadata = VideoMetadata(...),
  waitForProcessing = true,
  pollInterval = 5000,
  maxWaitTime = 600000
)

# All IDs directly accessible
echo result.contentId   # ContentId
echo result.videoId     # VideoId  
echo result.imageId     # ImageId
echo result.webUrl      # Public URL
```

## All IDs Are Exposed

Every function returns complete results with all IDs:

```nim
# Thumbnail upload returns ImageId
let thumbResult = await client.uploadThumbnail(...)
let imageId: ImageId = thumbResult.imageId  ✅

# Draft creation returns ContentId and ChannelId
let contentResult = await client.createDraftVideo(...)
let contentId: ContentId = contentResult.contentId  ✅
let ownerId: ChannelId = contentResult.ownerId      ✅

# Video upload returns VideoId
let videoResult = await client.uploadVideo(...)
let videoId: VideoId = videoResult.videoId  ✅

# Complete workflow returns all IDs
let result = await client.uploadVideoComplete(...)
let allIds = (result.contentId, result.videoId, result.imageId)  ✅
```

## Data Types

### Distinct ID Types
- `ContentId` - Video content identifier
- `VideoId` - Video file identifier
- `ImageId` - Thumbnail image identifier
- `ChannelId` - Channel identifier

### Enums
- `Category` - Video categories (News, Technology, Education, etc.)
- `Visibility` - Public, Private, Unlisted
- `ProcessingStatus` - Uploading, InProgress, Processed, Failed

### Result Types
All result types expose their IDs:
- `UploadTokenResponse` - Contains `token`
- `ThumbnailResult` - Contains `imageId` + all URLs
- `ContentResult` - Contains `contentId` + `ownerId`
- `VideoUploadResult` - Contains `videoId`
- `VideoStatusResult` - Contains `videoId` + status
- `CompleteUploadResult` - Contains all IDs

## Testing

### Run Unit Tests
```bash
nimble test
```

### Run Integration Tests
Requires real API credentials:

```bash
export GANJING_ACCESS_TOKEN="your_token"
export GANJING_CHANNEL_ID="your_channel_id"
nimble integration
```

## Examples

See the `examples/` directory for more examples:
- `simple_upload.nim` - Basic upload
- `batch_upload.nim` - Upload multiple videos
- `using_ids.nim` - Working with returned IDs

## Architecture

```
ganjing/
├── types.nim         # All data types and IDs
├── responses.nim     # Parse API responses
├── client.nim        # Core API functions
└── upload.nim        # High-level workflows
```

## Design Principles

1. **Small Functions** - Each function does one thing
2. **All IDs Exposed** - No swallowed identifiers
3. **Echo Results** - Operations print their progress
4. **Type Safety** - Distinct types prevent ID confusion
5. **Async First** - All I/O is non-blocking
6. **Zero Magic** - Clear, explicit code

## API Documentation

API version: v1.0c / v1.1

Endpoints used:
- `gw.ganjingworld.com` - Authentication and content management
- `imgapi.cloudokyo.cloud` - Image/thumbnail uploads
- `vodapi.cloudokyo.cloud` - Video uploads and status

## License

MIT

## Contributing

Contributions welcome! Please ensure:
- All IDs remain exposed in results
- Functions are small and focused
- Tests are added for new features
- Documentation is updated
