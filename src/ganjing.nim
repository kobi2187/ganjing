## GanJing World API Client Library
## 
## A Nim client for the GanJing World video platform API.
## All functions return results with exposed IDs for direct use.
##
## Example:
## ```nim
## import asyncdispatch, ganjing
## 
## proc main() {.async.} =
##   let client = newGanJingClient("your_access_token")
##   
##   let result = await client.uploadVideoComplete(
##     videoPath = "video.mp4",
##     thumbnailPath = "thumb.jpg",
##     channelId = ChannelId("your_channel_id"),
##     metadata = VideoMetadata(
##       title: "My Video",
##       description: "Description",
##       category: CategoryTechnology,
##       visibility: VisibilityPublic,
##       lang: "en-US"
##     )
##   )
##   
##   echo "Content ID: ", result.contentId
##   echo "Video ID: ", result.videoId
##   echo "Image ID: ", result.imageId
##   echo "URL: ", result.webUrl
##   
##   client.close()
## 
## waitFor main()
## ```

import types, client, upload, responses, videoutils

export types, client, upload, responses, videoutils
