## Core data types for GanJing World API client
## All IDs and results are exposed for direct use

import std/options

type
  # Core identifier types - all exposed
  ContentId* = distinct string
  VideoId* = distinct string
  ImageId* = distinct string
  ChannelId* = distinct string
  
  # String conversion for IDs
  proc `$`*(id: ContentId): string {.borrow.}
  proc `$`*(id: VideoId): string {.borrow.}
  proc `$`*(id: ImageId): string {.borrow.}
  proc `$`*(id: ChannelId): string {.borrow.}
  
  # Enums
  Category* = enum
    CategoryNews = "cat1"
    CategoryEntertainment = "cat2"
    CategorySports = "cat3"
    CategoryEducation = "cat4"
    CategoryScience = "cat5"
    CategoryTechnology = "cat6"
    CategoryGaming = "cat7"
    CategoryMusic = "cat8"
    CategoryArtsAndCulture = "cat9"
    CategoryLifestyle = "cat10"
    CategoryTravel = "cat11"
    CategoryFood = "cat12"
    CategoryOther = "cat13"
  
  Visibility* = enum
    VisibilityPublic = "public"
    VisibilityPrivate = "private"
    VisibilityUnlisted = "unlisted"
  
  ProcessingStatus* = enum
    StatusUploading = "uploading"
    StatusInProgress = "in_progress"
    StatusProcessed = "processed"
    StatusFailed = "failed"
  
  UploadPhase* = enum
    PhaseNotStarted
    PhaseGettingToken
    PhaseUploadingThumbnail
    PhaseCreatingDraft
    PhaseUploadingVideo
    PhaseCheckingStatus
    PhaseCompleted
    PhaseFailed
  
  # Auth responses - all fields exposed
  RefreshTokenResponse* = object
    userId*: string
    token*: string  # New access token
    refreshToken*: string  # New refresh token
  
  UploadTokenResponse* = object
    token*: string  # Upload token for file operations
  
  # Image upload response - all IDs and URLs exposed
  ThumbnailResult* = object
    imageId*: ImageId  # Exposed ID
    filename*: string
    allUrls*: seq[string]  # All generated URLs
    url672*: string  # Standard poster (672.webp)
    url1280*: string  # HD poster (1280.webp)
    url1920*: string  # Full HD poster (1920.webp)
    analyzedScore*: float
    extension*: string
  
  # Content creation response - all IDs exposed
  ContentResult* = object
    contentId*: ContentId  # Exposed ID
    ownerId*: ChannelId  # Exposed channel ID
    videoType*: string
    categoryId*: string
    slug*: string
    title*: string
    description*: string
    visibility*: string
    posterUrl*: string
    posterHdUrl*: string
    createdAt*: int64
    timeScheduled*: int64
    viewCount*: int
    likeCount*: int
    saveCount*: int
    commentCount*: int
  
  # Video upload response - ID exposed
  VideoUploadResult* = object
    videoId*: VideoId  # Exposed ID
    filename*: string
  
  # Video status response - ID and all metadata exposed
  VideoStatusResult* = object
    videoId*: VideoId  # Exposed ID
    filename*: string
    status*: ProcessingStatus
    progress*: int  # 0-100
    # Available when processed:
    url*: Option[string]
    durationSec*: Option[float]
    width*: Option[int]
    height*: Option[int]
    loudness*: Option[string]
    thumbBaseUrl*: Option[string]
    thumbSizes*: Option[string]
  
  # Metadata for video creation
  VideoMetadata* = object
    title*: string
    description*: string
    category*: Category
    visibility*: Visibility
    lang*: string
  
  # High-level upload result - all IDs exposed
  CompleteUploadResult* = object
    contentId*: ContentId  # Exposed
    videoId*: VideoId  # Exposed
    imageId*: ImageId  # Exposed
    webUrl*: string
    videoUrl*: Option[string]  # m3u8 stream URL if processed
    processedStatus*: VideoStatusResult

# Helper to get web URL from content ID
proc getWebUrl*(contentId: ContentId): string =
  result = "https://www.ganjingworld.com/video/" & $contentId
