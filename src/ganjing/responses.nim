## Parse API responses and extract all IDs
## Each function returns structured data with exposed IDs

import std/[json, options, strutils]
import types

# Parse upload token response
proc parseUploadToken*(jsonStr: string): UploadTokenResponse =
  let data = parseJson(jsonStr)
  result.token = data["data"]["token"].getStr()

# Parse thumbnail upload response
proc parseThumbnailResult*(jsonStr: string): ThumbnailResult =
  let data = parseJson(jsonStr)
  let body = data["body"]

  echo body
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

  # Get all URLs
  if body.hasKey("image_url"):
    result.allUrls = @[]
    for urlNode in body["image_url"]:
      result.allUrls.add(urlNode.getStr())

    # Extract specific size URLs
    for url in result.allUrls:
      if "672.webp" in url:
        result.url672 = url
      elif "1280.webp" in url:
        result.url1280 = url
      elif "1920.webp" in url:
        result.url1920 = url

# Parse content creation response
proc parseContentResult*(jsonStr: string): ContentResult =
  let data = parseJson(jsonStr)
  let contentData = data["data"]

  # Extract exposed IDs
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
  result.createdAt = contentData["created_at"].getBiggestInt()
  result.timeScheduled = contentData["time_scheduled"].getBiggestInt()

  # Extract stats
  result.viewCount = contentData["view_count"].getInt()
  result.likeCount = contentData["like_count"].getInt()
  result.saveCount = contentData["save_count"].getInt()
  result.commentCount = contentData["comment_count"].getInt()

# Parse video upload response
proc parseVideoUploadResult*(jsonStr: string): VideoUploadResult =
  let data = parseJson(jsonStr)
  let body = data["body"]

  # Extract exposed ID
  result.videoId = VideoId(body["video_id"].getStr())
  result.filename = body["filename"].getStr()

# Parse video status response
proc parseVideoStatus*(jsonStr: string): VideoStatusResult =
  let data = parseJson(jsonStr)
  let body = data["body"]

  # Extract exposed ID
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
      else: StatusFailed

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

# Parse refresh token response
proc parseRefreshToken*(jsonStr: string): RefreshTokenResponse =
  let data = parseJson(jsonStr)
  let responseData = data["data"]

  result.userId = responseData["user_id"].getStr()
  result.token = responseData["token"].getStr()
  result.refreshToken = responseData["refresh_token"].getStr()
