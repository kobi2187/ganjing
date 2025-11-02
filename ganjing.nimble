# Package
version       = "0.1.0"
author        = "GanJing Client Contributors"
description   = "Idiomatic Nim client for GanJing World API"
license       = "MIT"
srcDir        = "src"

# Dependencies
requires "nim >= 2.0.0"

# Tasks
task test, "Run unit tests":
  exec "nim c --path:src -r tests/test_responses.nim"

task integration, "Run integration tests (requires credentials)":
  exec "nim c --path:src -d:ssl -r tests/test_integration.nim"

task docs, "Generate documentation":
  exec "nim doc --project --index:on --outdir:docs src/ganjing.nim"
