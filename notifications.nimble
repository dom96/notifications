# Package

version       = "0.1.0"
author        = "Dominik Picheta"
description   = "GUI notifications for Mac OS X\'s Notification Center"
license       = "MIT"

# Dependencies

requires "nim >= 0.12.0"

task tests, "Run tests":
  exec "nim c tests/alltests"
  cpFile "tests/alltests", "alltests"
  exec "chmod +x alltests"
  exec "./alltests"
  rmFile "alltests"