
# Apple docs

## Info.plist

Example:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>English</string>
  <key>CFBundleDisplayName</key>
  <string>${PRODUCT_NAME}</string>
  <key>CFBundleExecutable</key>
  <string>${EXECUTABLE_NAME}</string>
  <key>CFBundleIconFile</key>
  <string></string>
  <key>CFBundleIdentifier</key>
  <string>com.yourcompany.${PRODUCT_NAME:rfc1034identifier}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${PRODUCT_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleSignature</key>
  <string>????</string>
  <key>CFBundleVersion</key>
  <string>1.0</string>
  <key>LSRequiresIPhoneOS</key>
  <true/>
  <key>UIStatusBarHidden</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
```

Put that in a ``Contents`` folder for Mac OS X apps. Doing that with the
above example causes the app to be shown in the Dock. ``LSUIElement`` seems
to prevent that (see below link to LaunchServicesKeys).

### References

* https://developer.apple.com/library/ios/documentation/General/Reference/InfoPlistKeyReference/Articles/LaunchServicesKeys.html

* https://developer.apple.com/library/mac/documentation/General/Reference/InfoPlistKeyReference/Articles/AboutInformationPropertyListFiles.html#//apple_ref/doc/uid/TP40009254-SW1

* https://www.chrisalvares.com/blog/7/creating-an-iphone-daemon-part-1/

* http://stackoverflow.com/questions/2154600/run-nsrunloop-in-a-cocoa-command-line-program

* https://en.wikibooks.org/wiki/Programming_Mac_OS_X_with_Cocoa_for_Beginners_2nd_Edition/Learning_From_Hello_World

# Experiences

## default Notification center

The Info.plists must contain a definition of ``CFBundleIdentifier``.

## ``nodecl`` in ``importc``'d proc defs

This caused an issue in ``createApp``, the pointer which we got from it was
truncated by 4 hex digits at the front.

e.g. 0x7f8978409620 was the correct pointer and we got 0x000078409620 or
0xffff78409620.

The ``nodecl`` pragma also causes the definitions of those procs not to be
present, so I am curious as to how the code compiled at all.