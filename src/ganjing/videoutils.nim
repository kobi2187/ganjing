## Video utility functions
## Extract thumbnails from videos using ffmpeg

import std/[os, osproc, strformat, strutils]

proc extractFirstFrame*(
  videoPath: string,
  outputPath: string = "",
  timeOffset: float = 1.0
): string =
  ## Extract a frame from video as thumbnail using ffmpeg
  ## 
  ## Args:
  ##   videoPath: Path to video file
  ##   outputPath: Output path for thumbnail (default: videoPath_thumb.jpg)
  ##   timeOffset: Time in seconds to extract frame (default: 1.0)
  ## 
  ## Returns: Path to extracted thumbnail
  ## 
  ## Requires: ffmpeg installed and in PATH
  
  if not fileExists(videoPath):
    raise newException(IOError, "Video file not found: " & videoPath)
  
  # Determine output path
  let outPath = if outputPath == "":
    let (dir, name, _) = splitFile(videoPath)
    dir / (name & "_thumb.jpg")
  else:
    outputPath
  
  # Build ffmpeg command
  # -i: input file
  # -ss: seek to position (in seconds)
  # -vframes 1: extract one frame
  # -q:v 2: high quality (1-31, lower is better)
  let cmd = &"ffmpeg -ss {timeOffset} -i {quoteShell(videoPath)} -vframes 1 -q:v 2 {quoteShell(outPath)} -y"
  
  echo &"→ Extracting thumbnail from video..."
  echo &"  Command: {cmd}"
  
  # Execute ffmpeg
  let (output, exitCode) = execCmdEx(cmd)
  
  if exitCode != 0:
    raise newException(OSError, 
      &"ffmpeg failed with exit code {exitCode}\nOutput: {output}")
  
  if not fileExists(outPath):
    raise newException(IOError, 
      "Thumbnail was not created: " & outPath)
  
  echo &"✓ Thumbnail extracted: {outPath}"
  return outPath

proc hasFfmpeg*(): bool =
  ## Check if ffmpeg is available
  try:
    let (output, exitCode) = execCmdEx("ffmpeg -version")
    return exitCode == 0
  except:
    return false
