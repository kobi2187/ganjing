## Core data types for GanJing World API client
## All IDs and results are exposed for direct use

import std/options

type
  # Core identifier types - all exposed
  ContentId* = distinct string
  VideoId* = distinct string
  ImageId* = distinct string
  ChannelId* = distinct string

  # Enums - All 45 categories from GanJing World
  # note: for some reason, 10 and 28 are missing in the api.
  Category* = enum
    CategoryArchitecture = "cat1" #
    CategoryArts = "cat2" #
    CategoryAutos = "cat3" #
    CategoryBeauty = "cat4" #
    CategoryBusiness = "cat5" #
    CategoryLifeHacks = "cat6" #
    CategoryEducation = "cat7" #
    CategoryEntertainment = "cat8" #
    CategoryFood = "cat9" #
    CategoryGovernment = "cat11" #
    CategoryHealth = "cat12" #
    CategoryCulture = "cat13" #
    CategoryKids = "cat14" #
    CategoryLifestyle = "cat15" #
    CategoryMilitary = "cat16" #
    CategoryPopularMusic = "cat17" #
    CategoryNature = "cat18" #
    CategoryTalkShows = "cat19" #
    CategoryNonprofit = "cat20" #
    CategoryPets = "cat21" #
    CategoryFinance = "cat22" #
    CategoryTech = "cat23" #
    CategoryReligion = "cat24" #
    CategorySports = "cat25" #
    CategoryMysteries = "cat26" #
    CategoryTravel = "cat27" #
    CategoryRelationship = "cat29" #
    CategoryDance = "cat30" #
    CategoryCareer = "cat31" #
    CategoryNews = "cat32" #
    CategoryTv = "cat33" #
    CategoryClassicalMusic = "cat34" #
    CategoryHistory = "cat35" #
    CategoryFashion = "cat36" #
    CategoryLaw = "cat37" #
    CategoryImmigration = "cat38" #
    CategoryPeople = "cat39" #
    CategoryLiterature = "cat40" #
    CategoryIndustrialTechnology = "cat41" #
    CategoryAgriculture = "cat42" #
    CategoryHomeProject = "cat43" #
    CategorySculpture = "cat44" #
    CategoryCaligraphy = "cat45" #
    CategoryPhotography = "cat46" #
    CategoryMovies = "cat47" #


  Visibility* = enum
    VisibilityPublic = "public"
    VisibilityPrivate = "private"
    VisibilityUnlisted = "unlisted"

  ProcessingStatus* = enum
    StatusUploading = "uploading"
    StatusInProgress = "in_progress"
    StatusProcessed = "processed"
    StatusFailed = "failed"
    StatusUnknown = "unknown"

  UploadPhase* = enum
    PhaseNotStarted = "not_started"
    PhaseGettingToken = "getting_token"
    PhaseUploadingThumbnail = "uploading_thumbnail"
    PhaseCreatingDraft = "creating_draft"
    PhaseUploadingVideo = "uploading_video"
    PhaseCheckingStatus = "checking_status"
    PhaseWaitingForProcessing = "waiting_for_processing"
    PhaseCompleted = "completed"
    PhaseFailed = "failed"

  # Progress callback for upload tracking
  UploadProgress* = object
    phase*: UploadPhase
    message*: string
    percentComplete*: int # 0-100

  ProgressCallback* = proc(progress: UploadProgress) {.closure.}

  # Auth responses - all fields exposed
  RefreshTokenResponse* = object
    userId*: string
    token*: string        # New access token
    refreshToken*: string # New refresh token

  UploadTokenResponse* = object
    token*: string # Upload token for file operations

  # Image upload response - all IDs and URLs exposed
  ThumbnailResult* = object
    imageId*: ImageId     # Exposed ID
    filename*: string
    allUrls*: seq[string] # All generated URLs
    url672*: string       # Standard poster (672.webp)
    url1280*: string      # HD poster (1280.webp)
    url1920*: string      # Full HD poster (1920.webp)
    analyzedScore*: float
    extension*: string

  # Content creation response - all IDs exposed
  ContentResult* = object
    contentId*: ContentId # Exposed ID
    ownerId*: ChannelId   # Exposed channel ID
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
    videoId*: VideoId # Exposed ID
    filename*: string

  # Video status response - ID and all metadata exposed
  VideoStatusResult* = object
    videoId*: VideoId # Exposed ID
    filename*: string
    status*: ProcessingStatus
    progress*: int    # 0-100
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

  # High-level upload result - ALL intermediate results preserved
  CompleteUploadResult* = object
    # Quick access IDs
    contentId*: ContentId
    videoId*: VideoId
    imageId*: ImageId
    webUrl*: string
    videoUrl*: Option[string]           # m3u8 stream URL if processed

    # Full intermediate results - all metadata preserved
    thumbnailResult*: ThumbnailResult   # Complete thumbnail upload response
    contentResult*: ContentResult       # Complete draft creation response
    videoResult*: VideoUploadResult     # Complete video upload response
    processedStatus*: VideoStatusResult # Complete status response

    # Progress tracking
    currentPhase*: UploadPhase
    completedAt*: Option[int64]         # Unix timestamp when completed

# String conversion for IDs
proc `$`*(id: ContentId): string {.borrow.}
proc `$`*(id: VideoId): string {.borrow.}
proc `$`*(id: ImageId): string {.borrow.}
proc `$`*(id: ChannelId): string {.borrow.}

# Helper to get web URL from content ID
proc getWebUrl*(contentId: ContentId): string =
  result = "https://www.ganjingworld.com/video/" & $contentId
