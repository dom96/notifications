# Notifications

This is a simple Nim library for displaying notifications
(aka alerts, toasts and probably many other names).

![](http://picheta.me/private/images/notification.png)

**Note**: This library is still under development, so things may change
and features already implemented may not work correctly. Please
let me know if you find any bugs!

This library currently supports Mac OS X only, but support for at least
Windows is also planned.

The API for displaying Mac OS X notifications through the notification
center is implemented in the ``macosx`` module under the ``notifications``
directory.

## Installation

Before you can start using this library you need to download it.
This can be easily done with the
[Nimble package manager](https://github.com/nim-lang/nimble), like so:

```bash
$ nimble install notifications
```

## Using the Mac OS X module

Start by importing the ``macosx`` module by writing
``import notifications/macosx`` at the top of your Nim source code.

The ``macosx`` module ties into the Nim async event loop (defined in the
``asyncdispatch`` module), so you should import the ``asyncdispatch`` module
also.

The following code snippet shows how to display a simple notification:

```nim
import asyncdispatch

import notifications/macosx

var center = newNotificationCenter()

waitFor center.show("Title", "Hello World")
echo("Notification has been displayed!")
```

You will also need a ``Info.plist`` file beside your executable. Make sure
to replace ``{YourBundleIdentifier}`` with your bundle identifier, for example
``com.organisation.appName``.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>{YourBundleIdentifier}</string>
    <key>LSUIElement</key>
    <string>1</string>
</dict>
</plist>
```

## Getting help

You can find me (and other Nim developers) on
[Freenode#nim](https://webchat.freenode.net/?channels=nim),
[the Nim Forum](http://forum.nim-lang.org),
and [twitter](twitter.com/d0m96). Feel free to ask for help on either of those
if you're stuck!

## License

MIT. See license.txt for details.