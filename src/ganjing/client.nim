## GanJing World API Client
## Core client with small, focused functions returning all IDs

import std/[asyncdispatch, httpclient, json, options, os, strformat, times]
import types, responses

const
  API_BASE* = "https://gw.ganjingworld.com"
  IMG_API_BASE* = "https://imgapi.cloudokyo.cloud"
  VOD_API_BASE* = "https://vodapi.cloudokyo.cloud"

const
  TOKEN_EXPIRY_SECONDS = 3600 # Upload token expires after 1 hour (conservative estimate)

type
  GanJingClient* = ref object
    accessToken*: string
    uploadToken*: Option[string]
    uploadTokenExpiry*: int64 # Unix timestamp when token expires
    httpClient: AsyncHttpClient
    verbose*: bool # Enable/disable logging

proc newGanJingClient*(accessToken: string,
    verbose: bool = true): GanJingClient =
  ## Create a new client with access token
  result = GanJingClient(
    accessToken: accessToken,
    uploadToken: none(string),
    uploadTokenExpiry: 0,
    httpClient: newAsyncHttpClient(),
    verbose: verbose
  )

proc close*(client: GanJingClient) =
  ## Close the HTTP client
  client.httpClient.close()

proc log*(client: GanJingClient, msg: string) =
  ## Logging helper - only outputs if verbose mode is enabled
  if client.verbose:
    echo msg

# ============================================================================
# LOW-LEVEL HELPERS - The primitives
# ============================================================================

proc ensureUploadToken(client: GanJingClient): Future[string] {.async.} =
  ## Ensure upload token exists and is not expired, fetch if needed
  ## Returns the upload token
  let currentTime = getTime().toUnix()

  # Check if token is missing or expired
  if client.uploadToken.isNone() or currentTime >= client.uploadTokenExpiry:
    if client.uploadToken.isSome():
      client.log("→ Upload token expired, refreshing...")

    client.httpClient.headers = newHttpHeaders({
      "accept": "application/json",
      "authorization": client.accessToken
    })

    let response = await client.httpClient.get(API_BASE & "/v1.0c/get-vod-token")
    let body = await response.body
    let tokenResp = parseUploadToken(body)

    client.uploadToken = some(tokenResp.token)
    client.uploadTokenExpiry = currentTime + TOKEN_EXPIRY_SECONDS
    client.log("→ Upload token obtained")

  return client.uploadToken.get()

proc makeAuthHeaders(client: GanJingClient): HttpHeaders =
  ## Create headers for API authentication
  newHttpHeaders({
    "accept": "application/json",
    "authorization": client.accessToken,
    "content-type": "application/json"
  })

proc buildSizesHeader(sizes: seq[int]): string =
  ## Build comma-separated sizes header
  result = ""
  for i, size in sizes:
    if i > 0: result.add(",")
    result.add($size)

proc setUploadHeaders(
  client: GanJingClient,
  token: string,
  resizingSizes: seq[int] = @[],
  acceptLanguage: string = ""
) =
  ## Unified header setter for all upload operations
  ## Set resizingSizes for image uploads, acceptLanguage for video uploads
  client.httpClient.headers = newHttpHeaders({"Authorization": "Bearer " & token})

  if resizingSizes.len > 0:
    client.httpClient.headers["resizing-list"] = buildSizesHeader(resizingSizes)

  if acceptLanguage != "":
    client.httpClient.headers["Accept-Language"] = acceptLanguage

proc readFileData(path: string): string =
  ## Read file and validate it exists
  if not fileExists(path):
    raise newException(IOError, "File not found: " & path)
  readFile(path)

proc makeImageMultipart(filename, imageData: string): MultipartData =
  ## Build multipart data for image upload
  ## NOTE: Only the 'file' field is sent - the 'name' field causes API errors
  result = newMultipartData()
  result["file"] = (filename, "image/jpeg", imageData)

proc makeVideoMultipart(
  filename, videoData: string,
  channelId: ChannelId,
  contentId: ContentId
): MultipartData =
  ## Build multipart data for video upload
  let metadata = %* {
    "filename": filename,
    "filetype": "video/mp4",
    "channel_id": $channelId,
    "content_id": $contentId
  }

  result = newMultipartData()
  result["metadata"] = $metadata
  result["file"] = (filename, "video/mp4", videoData)

proc buildDraftPayload(
  channelId: ChannelId,
  metadata: VideoMetadata,
  posterUrl, posterHdUrl: string
): JsonNode =
  ## Build JSON payload for draft creation
  %* {
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

proc checkApiError(jsonBody: string) =
  ## Check if API response contains an error and raise exception if found
  ## Handles various error response formats from GanJing API
  try:
    let data = parseJson(jsonBody)

    # Check for error field with status_code: {"error":"...","status_code":...}
    if data.hasKey("error") and data["error"].kind != JNull:
      let errorMsg = if data["error"].kind == JString:
        data["error"].getStr()
      else:
        $data["error"]
      let statusCode = if data.hasKey("status_code"):
        " [" & $data["status_code"].getInt() & "]"
      else:
        ""
      raise newException(IOError, "API Error" & statusCode & ": " & errorMsg)

    # Check for result format: {"result":{"result_code":..,"message":..}}
    if data.hasKey("result"):
      let result = data["result"]
      if result.hasKey("result_code"):
        let code = result["result_code"].getInt()
        # Success codes: 0, 200000, 201000
        if code != 0 and code != 200000 and code != 201000:  # Non-success codes
          let message = if result.hasKey("message"):
            result["message"].getStr()
          else:
            "Unknown error"
          raise newException(IOError, &"API Error [{code}]: {message}")
      # If result_code is a success, this format doesn't have a "data" field
      # So we should return early and not check for missing "data" field
      return

    # Check for error message field
    if data.hasKey("message") and data.hasKey("code"):
      raise newException(IOError, "API Error [" & $data["code"].getInt() & "]: " & data["message"].getStr())

    # Check for msg field (common error format)
    if data.hasKey("msg"):
      let msg = data["msg"].getStr()
      if msg != "" and msg != "success":
        raise newException(IOError, "API Error: " & msg)

    # Check if data field is missing (expected for successful responses)
    if not data.hasKey("data") and not data.hasKey("body"):
      # If data/body field is missing, this is likely an error response
      # Show the entire response body for debugging
      raise newException(IOError, "API Error: Missing 'data'/'body' field in response. Response: " & jsonBody)

    # Check if data field is null (sometimes indicates error)
    if data.hasKey("data") and data["data"].kind == JNull:
      if data.hasKey("msg"):
        raise newException(IOError, "API Error: " & data["msg"].getStr())
      else:
        raise newException(IOError, "API Error: data field is null")
  except JsonParsingError as e:
    raise newException(IOError, "Invalid JSON in API response: " & e.msg)

# ============================================================================
# AUTHENTICATION - Refactored with helpers
# ============================================================================

proc getUploadToken*(client: GanJingClient): Future[
    UploadTokenResponse] {.async.} =
  ## Get upload token from access token
  ## Returns: UploadTokenResponse with token field
  let token = await client.ensureUploadToken()
  result = UploadTokenResponse(token: token)

proc refreshAccessToken*(client: GanJingClient): Future[
    RefreshTokenResponse] {.async.} =
  ## Get refresh token from current access token
  ## Returns: RefreshTokenResponse with userId, token, refreshToken
  client.httpClient.headers = newHttpHeaders({
      "Content-Type": "application/json"})
  let requestBody = %* {"token": client.accessToken}

  let response = await client.httpClient.post(
    API_BASE & "/v1.0c/auth/refresh",
    body = $requestBody
  )
  let body = await response.body

  result = parseRefreshToken(body)
  client.log("→ Access token refreshed")

# ============================================================================
# IMAGE UPLOAD - Forth-style: small, composed functions
# ============================================================================

proc prepareImageData(imagePath: string): tuple[data: string,
    filename: string] =
  ## Prepare image data for upload (Forth: one tiny task)
  (readFileData(imagePath), imagePath.extractFilename())

proc executeImageUpload(
  client: GanJingClient,
  multipart: MultipartData
): Future[string] {.async.} =
  ## Execute HTTP POST for image upload (Forth: one tiny task)
  let response = await client.httpClient.post(
    IMG_API_BASE & "/api/v1/image",
    multipart = multipart
  )
  result = await response.body

proc logThumbnailResult(client: GanJingClient, result: ThumbnailResult) =
  ## Log thumbnail upload result (Forth: one tiny task)
  client.log(&"→ Thumbnail uploaded: {result.imageId}")
  client.log(&"  All URLs count: {result.allUrls.len}")
  client.log(&"  Standard (672): {result.url672}")
  client.log(&"  HD (1280): {result.url1280}")

proc uploadThumbnail*(
  client: GanJingClient,
  imagePath: string,
  sizes: seq[int] = @[140, 240, 360, 380, 480, 580, 672, 960, 1280, 1920]
): Future[ThumbnailResult] {.async.} =
  ## Upload thumbnail - composed of tiny functions (Forth style)
  ## NOTE: The 'name' parameter was removed - the API rejects it
  let (imageData, filename) = prepareImageData(imagePath)
  let token = await client.ensureUploadToken()
  let multipart = makeImageMultipart(filename, imageData)

  client.setUploadHeaders(token, resizingSizes = sizes)
  let body = await client.executeImageUpload(multipart)
  result = parseThumbnailResult(body)
  client.logThumbnailResult(result)

# ============================================================================
# CONTENT CREATION - Forth-style: small, composed functions
# ============================================================================

proc executeDraftCreation(
  client: GanJingClient,
  payload: JsonNode
): Future[string] {.async.} =
  ## Execute HTTP POST for draft creation (Forth: one tiny task)
  let response = await client.httpClient.post(API_BASE & "/v1.0c/add-content",
      body = $payload)
  result = await response.body

proc logContentResult(client: GanJingClient, result: ContentResult) =
  ## Log content creation result (Forth: one tiny task)
  client.log(&"→ Draft created: {result.contentId}")
  client.log(&"  Title: {result.title}")
  client.log(&"  Slug: {result.slug}")
  client.log(&"  Owner: {result.ownerId}")

proc createDraftVideo*(
  client: GanJingClient,
  channelId: ChannelId,
  metadata: VideoMetadata,
  posterUrl: string,
  posterHdUrl: string
): Future[ContentResult] {.async.} =
  ## Create draft - composed of tiny functions (Forth style)
  let payload = buildDraftPayload(channelId, metadata, posterUrl, posterHdUrl)
  client.httpClient.headers = client.makeAuthHeaders()
  echo payload
  let body = await client.executeDraftCreation(payload)

  # Check for API errors before parsing
  checkApiError(body)

  result = parseContentResult(body)
  client.logContentResult(result)

# ============================================================================
# VIDEO UPLOAD - Forth-style: small, composed functions
# ============================================================================

proc prepareVideoData(videoPath: string): tuple[data: string,
    filename: string] =
  ## Prepare video data for upload (Forth: one tiny task)
  (readFileData(videoPath), videoPath.extractFilename())

proc executeVideoUpload(
  client: GanJingClient,
  multipart: MultipartData
): Future[string] {.async.} =
  ## Execute HTTP POST for video upload (Forth: one tiny task)
  let response = await client.httpClient.post(
    VOD_API_BASE & "/api/v1/video",
    multipart = multipart
  )
  result = await response.body

proc logVideoResult(client: GanJingClient, result: VideoUploadResult) =
  ## Log video upload result (Forth: one tiny task)
  client.log(&"→ Video uploaded: {result.videoId}")
  client.log(&"  Filename: {result.filename}")

proc uploadVideo*(client: GanJingClient, videoPath: string, channelId: ChannelId, contentId: ContentId): Future[VideoUploadResult] {.async.} =
  ## Upload video - composed of tiny functions (Forth style)
  let (videoData, filename) = prepareVideoData(videoPath)
  let token = await client.ensureUploadToken()
  let multipart = makeVideoMultipart(filename, videoData, channelId, contentId)

  client.setUploadHeaders(token, acceptLanguage = "en-US,en;q=0.9")
  let body = await client.executeVideoUpload(multipart)
  echo "Video upload response: ", body  # Debug logging

  # Check for API errors before parsing
  checkApiError(body)

  result = parseVideoUploadResult(body)
  client.logVideoResult(result)

# ============================================================================
# STATUS CHECK - Forth-style: small, composed functions
# ============================================================================

proc executeStatusCheck(
  client: GanJingClient,
  videoId: VideoId
): Future[string] {.async.} =
  ## Execute HTTP GET for status check (Forth: one tiny task)
  let response = await client.httpClient.get(VOD_API_BASE &
      &"/api/v1/status/{videoId}")
  result = await response.body

proc logStatusResult(client: GanJingClient, result: VideoStatusResult) =
  ## Log status result (Forth: one tiny task)
  client.log(&"→ Status: {result.status}")
  if result.progress > 0:
    client.log(&"  Progress: {result.progress}%")
  if result.url.isSome():
    client.log(&"  Video URL: {result.url.get()}")
  if result.durationSec.isSome():
    client.log(&"  Duration: {result.durationSec.get()}s")

proc getVideoStatus*(
  client: GanJingClient,
  videoId: VideoId
): Future[VideoStatusResult] {.async.} =
  ## Check status - composed of tiny functions (Forth style)
  let token = await client.ensureUploadToken()
  client.setUploadHeaders(token)

  let body = await client.executeStatusCheck(videoId)
  result = parseVideoStatus(body)
  client.logStatusResult(result)
