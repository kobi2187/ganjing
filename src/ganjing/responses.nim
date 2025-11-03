## Parse API responses and extract all IDs
## Each function returns structured data with exposed IDs

import std/[json, options, strutils]
import types

type
  ParseError* = object of CatchableError
    ## Raised when API response parsing fails

# Parse upload token response
proc parseUploadToken*(jsonStr: string): UploadTokenResponse =
  try:
    let data = parseJson(jsonStr)
    if not data.hasKey("data") or not data["data"].hasKey("token"):
      raise newException(ParseError, "Missing required field: data.token")
    result.token = data["data"]["token"].getStr()
  except JsonParsingError as e:
    raise newException(ParseError, "Invalid JSON in upload token response: " & e.msg)
  except KeyError as e:
    raise newException(ParseError, "Missing field in upload token response: " & e.msg)

# Parse thumbnail upload response
proc parseThumbnailResult*(jsonStr: string): ThumbnailResult =
  try:
    let data = parseJson(jsonStr)
    if not data.hasKey("body"):
      raise newException(ParseError, "Missing required field: body")
    let body = data["body"]

    # Extract exposed ID
    if body.hasKey("image_id"):
      result.imageId = ImageId(body["image_id"].getStr())
    if body.hasKey("filename"):
      result.filename = body["filename"].getStr()
    if body.hasKey("extension"):
      result.extension = body["extension"].getStr()

    # Parse analyzed score
    if body.hasKey("analyzed_score"):
      result.analyzedScore = body["analyzed_score"]["raw_score"].getFloat()

    # Get all URLs and extract specific sizes in single loop
    if body.hasKey("image_url"):
      result.allUrls = @[]
      for urlNode in body["image_url"]:
        let url = urlNode.getStr()
        result.allUrls.add(url)

        # Extract specific size URLs as we go
        if "672.webp" in url:
          result.url672 = url
        elif "1280.webp" in url:
          result.url1280 = url
        elif "1920.webp" in url:
          result.url1920 = url
  except JsonParsingError as e:
    raise newException(ParseError, "Invalid JSON in thumbnail response: " & e.msg)
  except KeyError as e:
    raise newException(ParseError, "Missing field in thumbnail response: " & e.msg)

# Parse content creation response
proc parseContentResult*(jsonStr: string): ContentResult =
  try:
    let data = parseJson(jsonStr)
    if not data.hasKey("data"):
      raise newException(ParseError, "Missing required field: data")
    let contentData = data["data"]

    # Extract exposed IDs (required fields)
    if not contentData.hasKey("id"):
      raise newException(ParseError, "Missing required field: data.id")
    if not contentData.hasKey("owner_id"):
      raise newException(ParseError, "Missing required field: data.owner_id")

    result.contentId = ContentId(contentData["id"].getStr())
    result.ownerId = ChannelId(contentData["owner_id"].getStr())

    # Extract metadata
    result.videoType = contentData["type"].getStr()
    result.categoryId = contentData["category_id"].getStr()
    result.slug = contentData["slug"].getStr()
    result.title = contentData["title"].getStr()
    result.description = contentData["description"].getStr()
    result.visibility = contentData["visibility"].getStr()
    result.posterUrl = contentData["poster_url"].getStr()
    result.posterHdUrl = contentData["poster_hd_url"].getStr()
  except JsonParsingError as e:
    raise newException(ParseError, "Invalid JSON in content response: " & e.msg)
  except KeyError as e:
    raise newException(ParseError, "Missing field in content response: " & e.msg)

# Parse video upload response
proc parseVideoUploadResult*(jsonStr: string): VideoUploadResult =
  try:
    let data = parseJson(jsonStr)
    if not data.hasKey("body"):
      raise newException(ParseError, "Missing required field: body")
    let body = data["body"]

    # Extract exposed ID (required)
    if not body.hasKey("video_id"):
      raise newException(ParseError, "Missing required field: body.video_id")

    result.videoId = VideoId(body["video_id"].getStr())
    result.filename = body["filename"].getStr()
  except JsonParsingError as e:
    raise newException(ParseError, "Invalid JSON in video upload response: " & e.msg)
  except KeyError as e:
    raise newException(ParseError, "Missing field in video upload response: " & e.msg)

# Parse video status response
proc parseVideoStatus*(jsonStr: string): VideoStatusResult =
  try:
    let data = parseJson(jsonStr)
    if not data.hasKey("body"):
      raise newException(ParseError, "Missing required field: body")
    let body = data["body"]

    # Extract exposed ID (required)
    if not body.hasKey("video_id"):
      raise newException(ParseError, "Missing required field: body.video_id")

    result.videoId = VideoId(body["video_id"].getStr())
    result.filename = body["filename"].getStr()

    # Parse status (optional - when fully processed, no status field is returned)
    if body.hasKey("status"):
      let statusStr = body["status"].getStr()
      result.status = case statusStr
        of "uploading": StatusUploading
        of "in_progress": StatusInProgress
        of "processed": StatusProcessed
        of "failed": StatusFailed
        else: StatusUnknown

      # Progress (only during processing)
      if body.hasKey("progress"):
        result.progress = body["progress"].getInt()
    else:
      # No status field means video is fully processed
      result.status = StatusProcessed
      result.progress = 100

    # Optional fields when processed
    if body.hasKey("url"):
      result.url = some(body["url"].getStr())

    if body.hasKey("duration_sec"):
      result.durationSec = some(body["duration_sec"].getStr().parseFloat())

    if body.hasKey("width"):
      result.width = some(body["width"].getInt())

    if body.hasKey("height"):
      result.height = some(body["height"].getInt())

    if body.hasKey("loudness"):
      result.loudness = some(body["loudness"].getStr())

    if body.hasKey("thumb"):
      result.thumbBaseUrl = some(body["thumb"]["base_url"].getStr())
      result.thumbSizes = some(body["thumb"]["sizes"].getStr())
  except JsonParsingError as e:
    raise newException(ParseError, "Invalid JSON in video status response: " & e.msg)
  except KeyError as e:
    raise newException(ParseError, "Missing field in video status response: " & e.msg)

# Parse refresh token response
proc parseRefreshToken*(jsonStr: string): RefreshTokenResponse =
  try:
    let data = parseJson(jsonStr)
    if not data.hasKey("data"):
      raise newException(ParseError, "Missing required field: data")
    let responseData = data["data"]

    # Validate required fields
    if not responseData.hasKey("user_id"):
      raise newException(ParseError, "Missing required field: data.user_id")
    if not responseData.hasKey("token"):
      raise newException(ParseError, "Missing required field: data.token")
    if not responseData.hasKey("refresh_token"):
      raise newException(ParseError, "Missing required field: data.refresh_token")

    result.userId = responseData["user_id"].getStr()
    result.token = responseData["token"].getStr()
    result.refreshToken = responseData["refresh_token"].getStr()
  except JsonParsingError as e:
    raise newException(ParseError, "Invalid JSON in refresh token response: " & e.msg)
  except KeyError as e:
    raise newException(ParseError, "Missing field in refresh token response: " & e.msg)
