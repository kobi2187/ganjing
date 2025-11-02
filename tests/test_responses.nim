## Unit tests for API response parsing
## Tests verify we correctly parse all IDs and fields from actual API responses

import std/unittest
import std/options
import ganjing/[types, responses]

suite "API Response Parsing":
  
  test "Parse upload token response":
    let jsonStr = """
{
  "result": {
    "result_code": 201000,
    "message": "Ok"
  },
  "data": {
    "token": "upload_token_abc123"
  }
}"""
    
    let result = parseUploadToken(jsonStr)
    
    check result.token == "upload_token_abc123"
    echo "✓ Upload token parsed: ", result.token
  
  test "Parse thumbnail result with all URLs":
    let jsonStr = """
{
  "body": {
    "filename": "test.jpg",
    "image_id": "img123abc",
    "image_url": [
      "https://example.com/img123abc/140.webp",
      "https://example.com/img123abc/672.webp",
      "https://example.com/img123abc/1280.webp",
      "https://example.com/img123abc/1920.webp"
    ],
    "analyzed_score": {
      "raw_score": 0.85,
      "score": 4
    },
    "extension": "jpg,webp"
  },
  "header": {},
  "status_code": 200
}"""
    
    let result = parseThumbnailResult(jsonStr)
    
    check $result.imageId == "img123abc"
    check result.filename == "test.jpg"
    check result.allUrls.len == 4
    check result.url672 == "https://example.com/img123abc/672.webp"
    check result.url1280 == "https://example.com/img123abc/1280.webp"
    check result.url1920 == "https://example.com/img123abc/1920.webp"
    check result.analyzedScore == 0.85
    check result.extension == "jpg,webp"
    
    echo "✓ Thumbnail result parsed:"
    echo "  ImageId: ", result.imageId
    echo "  URLs: ", result.allUrls.len
    echo "  672: ", result.url672
    echo "  1280: ", result.url1280
  
  test "Parse content creation response":
    let jsonStr = """
{
  "result": {
    "result_code": 201000,
    "message": "Ok"
  },
  "data": {
    "id": "content789xyz",
    "owner_id": "channel456def",
    "type": "Video",
    "category_id": "cat13",
    "slug": "test-video",
    "title": "Test Video",
    "description": "Test Description",
    "visibility": "public",
    "poster_url": "https://example.com/poster.jpg",
    "poster_hd_url": "https://example.com/poster_hd.jpg",
    "created_at": 1744145604383,
    "time_scheduled": 1744145604384,
    "view_count": 0,
    "like_count": 0,
    "save_count": 0,
    "comment_count": 0
  }
}"""
    
    let result = parseContentResult(jsonStr)
    
    check $result.contentId == "content789xyz"
    check $result.ownerId == "channel456def"
    check result.videoType == "Video"
    check result.categoryId == "cat13"
    check result.title == "Test Video"
    check result.description == "Test Description"
    check result.visibility == "public"
    check result.slug == "test-video"
    check result.viewCount == 0
    
    echo "✓ Content result parsed:"
    echo "  ContentId: ", result.contentId
    echo "  OwnerId: ", result.ownerId
    echo "  Title: ", result.title
    echo "  Slug: ", result.slug
  
  test "Parse video upload response":
    let jsonStr = """
{
  "body": {
    "filename": "test.mp4",
    "video_id": "video321qwe"
  },
  "header": {},
  "status_code": 200
}"""
    
    let result = parseVideoUploadResult(jsonStr)
    
    check $result.videoId == "video321qwe"
    check result.filename == "test.mp4"
    
    echo "✓ Video upload result parsed:"
    echo "  VideoId: ", result.videoId
    echo "  Filename: ", result.filename
  
  test "Parse video status - in progress":
    let jsonStr = """
{
  "body": {
    "video_id": "video321qwe",
    "filename": "test.mp4",
    "progress": 45,
    "status": "in_progress"
  },
  "header": {},
  "status_code": 200
}"""
    
    let result = parseVideoStatus(jsonStr)
    
    check $result.videoId == "video321qwe"
    check result.filename == "test.mp4"
    check result.status == StatusInProgress
    check result.progress == 45
    check result.url.isNone()
    
    echo "✓ Video status (in progress) parsed:"
    echo "  VideoId: ", result.videoId
    echo "  Status: ", result.status
    echo "  Progress: ", result.progress, "%"
  
  test "Parse video status - processed":
    let jsonStr = """
{
  "body": {
    "video_id": "video321qwe",
    "status": "processed",
    "url": "https://video.example.com/master.m3u8",
    "duration_sec": "120.5",
    "filename": "test.mp4",
    "width": 1920,
    "height": 1080,
    "loudness": "-23.4 LUFS",
    "thumb": {
      "base_url": "https://example.com/thumbs/",
      "sizes": "360,480,720,1080"
    }
  },
  "header": {},
  "status_code": 200
}"""
    
    let result = parseVideoStatus(jsonStr)
    
    check $result.videoId == "video321qwe"
    check result.status == StatusProcessed
    check result.url.isSome()
    check result.url.get() == "https://video.example.com/master.m3u8"
    check result.durationSec.isSome()
    check result.durationSec.get() == 120.5
    check result.width.get() == 1920
    check result.height.get() == 1080
    check result.loudness.get() == "-23.4 LUFS"
    check result.thumbBaseUrl.isSome()
    check result.thumbSizes.isSome()
    
    echo "✓ Video status (processed) parsed:"
    echo "  VideoId: ", result.videoId
    echo "  Status: ", result.status
    echo "  URL: ", result.url.get()
    echo "  Duration: ", result.durationSec.get(), "s"
    echo "  Resolution: ", result.width.get(), "x", result.height.get()
  
  test "Parse refresh token response":
    let jsonStr = """
{
  "id": "1b6a46cf285959826eca5e35f085dcbc",
  "result": {
    "result_code": 201000,
    "message": "Ok"
  },
  "data": {
    "user_id": "user123",
    "token": "new_access_token",
    "refresh_token": "new_refresh_token"
  }
}"""
    
    let result = parseRefreshToken(jsonStr)
    
    check result.userId == "user123"
    check result.token == "new_access_token"
    check result.refreshToken == "new_refresh_token"
    
    echo "✓ Refresh token parsed:"
    echo "  UserId: ", result.userId
    echo "  New access token: ", result.token
    echo "  New refresh token: ", result.refreshToken

suite "Type Conversions":
  
  test "ID to string conversions":
    let contentId = ContentId("content123")
    let videoId = VideoId("video456")
    let imageId = ImageId("image789")
    let channelId = ChannelId("channel000")
    
    check $contentId == "content123"
    check $videoId == "video456"
    check $imageId == "image789"
    check $channelId == "channel000"
    
    echo "✓ ID conversions work correctly"
  
  test "Web URL generation":
    let contentId = ContentId("abc123xyz")
    let url = getWebUrl(contentId)
    
    check url == "https://www.ganjingworld.com/video/abc123xyz"
    
    echo "✓ Web URL: ", url

suite "Enum Values":
  
  test "Category enum values":
    check $CategoryNews == "cat1"
    check $CategoryTechnology == "cat6"
    check $CategoryOther == "cat13"
    
    echo "✓ Category enums:"
    echo "  News: ", $CategoryNews
    echo "  Technology: ", $CategoryTechnology
    echo "  Other: ", $CategoryOther
  
  test "Visibility enum values":
    check $VisibilityPublic == "public"
    check $VisibilityPrivate == "private"
    check $VisibilityUnlisted == "unlisted"
    
    echo "✓ Visibility enums:"
    echo "  Public: ", $VisibilityPublic
    echo "  Private: ", $VisibilityPrivate
  
  test "Processing status enum values":
    check $StatusInProgress == "in_progress"
    check $StatusProcessed == "processed"
    
    echo "✓ Status enums:"
    echo "  In Progress: ", $StatusInProgress
    echo "  Processed: ", $StatusProcessed
