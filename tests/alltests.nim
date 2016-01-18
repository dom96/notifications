import asyncdispatch

import notifications/macosx

proc onNotificationClick(info: ClickInfo) =
  echo("Notification clicked: ", info)

var center = newNotificationCenter(onNotificationClick)

waitFor center.show("Nim", "Version 1.0 has been released!",
    @[("#1", "Kill All Humans"), ("#2", "Kill John Locke"),
     ("#3", "Join Star Helix")],
    actionButtonTitle="Action", otherButtonTitle="Other")
echo("First done!")

waitFor center.show("Sept 1st", "Hello World")
echo("Second done!")

waitFor center.show("Please reply", "What's your name, stranger?",
  hasReplyButton = true)
echo("Third done!")