## GanJing World API Client
## Core client with small, focused functions returning all IDs

import std/[asyncdispatch, httpclient, json, options, os, strformat]
import types, responses

const
  API_BASE* = "https://gw.ganjingworld.com"
  IMG_API_BASE* = "https://imgapi.cloudokyo.cloud"
  VOD_API_BASE* = "https://vodapi.cloudokyo.cloud"

type
  GanJingClient* = ref object
    accessToken*: string
    uploadToken*: Option[string]
    httpClient: AsyncHttpClient

proc newGanJingClient*(accessToken: string): GanJingClient =
  ## Create a new client with access token
  result = GanJingClient(
    accessToken: accessToken,
    uploadToken: none(string),
    httpClient: newAsyncHttpClient()
  )

proc close*(client: GanJingClient) =
  ## Close the HTTP client
  client.httpClient.close()

# ============================================================================
# AUTHENTICATION - Small functions returning exact API responses
# ============================================================================

proc getUploadToken*(client: GanJingClient): Future[UploadTokenResponse] {.async.} =
  ## Get upload token from access token
  ## Returns: UploadTokenResponse with token field
  client.httpClient.headers = newHttpHeaders({
    "accept": "application/json",
    "authorization": client.accessToken
  })
  
  let response = await client.httpClient.get(
    API_BASE & "/v1.0c/get-vod-token"
  )
  let body = await response.body
  
  result = parseUploadToken(body)
  client.uploadToken = some(result.token)
  
  echo "→ Upload token obtained"

proc refreshAccessToken*(
  client: GanJingClient
): Future[RefreshTokenResponse] {.async.} =
  ## Get refresh token from current access token
  ## Returns: RefreshTokenResponse with userId, token, refreshToken
  client.httpClient.headers = newHttpHeaders({
    "Content-Type": "application/json"
  })
  
  let requestBody = %* {"token": client.accessToken}
  
  let response = await client.httpClient.post(
    API_BASE & "/v1.0c/auth/refresh",
    body = $requestBody
  )
  let body = await response.body
  
  result = parseRefreshToken(body)
  
  echo "→ Access token refreshed"

# ============================================================================
# IMAGE UPLOAD - Returns ImageId and all URLs
# ============================================================================

proc uploadThumbnail*(
  client: GanJingClient,
  imagePath: string,
  name: string = "thumbnail",
  sizes: seq[int] = @[140,240,360,380,480,580,672,960,1280,1920]
): Future[ThumbnailResult] {.async.} =
  ## Upload thumbnail image
  ## Returns: ThumbnailResult with imageId and all generated URLs
  
  if not fileExists(imagePath):
    raise newException(IOError, "Image file not found: " & imagePath)
  
  # Ensure we have upload token
  if client.uploadToken.isNone:
    discard await client.getUploadToken()
  
  let imageData = readFile(imagePath)
  let filename = imagePath.extractFilename()
  
  var multipart = newMultipartData()
  multipart["name"] = name
  multipart["file"] = (filename, "image/jpeg", imageData)
  
  # Build sizes header
  var sizesStr = ""
  for i, size in sizes:
    if i > 0: sizesStr.add(",")
    sizesStr.add($size)
  
  client.httpClient.headers = newHttpHeaders({
    "accept": "application/json, text/plain, */*",
    "authorization": "Bearer " & client.uploadToken.get(),
    "resizing-list": sizesStr
  })
  
  let response = await client.httpClient.post(
    IMG_API_BASE & "/api/v1/image",
    multipart = multipart
  )
  let body = await response.body
  
  result = parseThumbnailResult(body)
  
  echo &"→ Thumbnail uploaded: {result.imageId}"
  echo &"  All URLs count: {result.allUrls.len}"
  echo &"  Standard (672): {result.url672}"
  echo &"  HD (1280): {result.url1280}"

# ============================================================================
# CONTENT CREATION - Returns ContentId and all metadata
# ============================================================================

proc createDraftVideo*(
  client: GanJingClient,
  channelId: ChannelId,
  metadata: VideoMetadata,
  posterUrl: string,
  posterHdUrl: string
): Future[ContentResult] {.async.} =
  ## Create draft video content
  ## Returns: ContentResult with contentId and all metadata
  
  let requestBody = %* {
    "user_id2": $channelId,
    "type": "Video",
    "lang": metadata.lang,
    "category_id": $metadata.category,
    "title": metadata.title,
    "description": metadata.description,
    "visibility": $metadata.visibility,
    "mode": "draft",
    "poster_url": posterUrl,
    "poster_hd_url": posterHdUrl
  }
  
  client.httpClient.headers = newHttpHeaders({
    "accept": "application/json",
    "authorization": client.accessToken,
    "content-type": "application/json"
  })
  
  let response = await client.httpClient.post(
    API_BASE & "/v1.0c/add-content",
    body = $requestBody
  )
  let body = await response.body
  
  result = parseContentResult(body)
  
  echo &"→ Draft created: {result.contentId}"
  echo &"  Title: {result.title}"
  echo &"  Slug: {result.slug}"
  echo &"  Owner: {result.ownerId}"

# ============================================================================
# VIDEO UPLOAD - Returns VideoId
# ============================================================================

proc uploadVideo*(
  client: GanJingClient,
  videoPath: string,
  channelId: ChannelId,
  contentId: ContentId
): Future[VideoUploadResult] {.async.} =
  ## Upload video file
  ## Returns: VideoUploadResult with videoId
  
  if not fileExists(videoPath):
    raise newException(IOError, "Video file not found: " & videoPath)
  
  # Ensure we have upload token
  if client.uploadToken.isNone:
    discard await client.getUploadToken()
  
  let videoData = readFile(videoPath)
  let filename = videoPath.extractFilename()
  
  let metadata = %* {
    "filename": filename,
    "filetype": "video/mp4",
    "channel_id": $channelId,
    "content_id": $contentId
  }
  
  var multipart = newMultipartData()
  multipart["metadata"] = $metadata
  multipart["file"] = (filename, "video/mp4", videoData)
  
  client.httpClient.headers = newHttpHeaders({
    "Accept-Language": "en-US,en;q=0.9",
    "Authorization": "Bearer " & client.uploadToken.get()
  })
  
  let response = await client.httpClient.post(
    VOD_API_BASE & "/api/v1/video",
    multipart = multipart
  )
  let body = await response.body
  
  result = parseVideoUploadResult(body)
  
  echo &"→ Video uploaded: {result.videoId}"
  echo &"  Filename: {result.filename}"

# ============================================================================
# STATUS CHECK - Returns VideoId and full status
# ============================================================================

proc getVideoStatus*(
  client: GanJingClient,
  videoId: VideoId
): Future[VideoStatusResult] {.async.} =
  ## Check video processing status
  ## Returns: VideoStatusResult with videoId and status details
  
  # Ensure we have upload token
  if client.uploadToken.isNone:
    discard await client.getUploadToken()
  
  client.httpClient.headers = newHttpHeaders({
    "Authorization": "Bearer " & client.uploadToken.get()
  })
  
  let response = await client.httpClient.get(
    VOD_API_BASE & &"/api/v1/status/{videoId}"
  )
  let body = await response.body
  
  result = parseVideoStatus(body)
  
  echo &"→ Status: {result.status}"
  if result.progress > 0:
    echo &"  Progress: {result.progress}%"
  if result.url.isSome:
    echo &"  Video URL: {result.url.get()}"
  if result.durationSec.isSome:
    echo &"  Duration: {result.durationSec.get()}s"
