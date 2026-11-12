# LabGo iOS Upload Handoff

Bundle identifier: `com.labgo.app`

The app is prepared for the client's Apple Developer account with automatic iOS signing enabled.

Important: an App Store upload cannot be made without the client's Apple Developer signing. Apple requires the archive or IPA to be signed by the Apple Developer team that owns the app. If you do not have access to that team, the client must do the final signing/upload from Xcode.

## What to send the client

Send this prepared folder:

`LabGo_iOS_FULL_UPLOAD_FOLDER`

This includes the Flutter app source, the iOS workspace, CocoaPods files, assets, app icon, and export options. It intentionally does not include backend files or local secret files.

Also included:

`archive/LabGo.xcarchive`

This archive was built without Apple code signing. The client can try opening it in Xcode Organizer and using Distribute App with their Apple Developer account. If Xcode refuses to distribute an unsigned archive, they should open `ios/Runner.xcworkspace`, select their team, then archive again.

## Client steps

1. First try opening `archive/LabGo.xcarchive`.
2. In Xcode Organizer, use Distribute App and sign/upload with their Apple Developer account.
3. If Xcode asks for project signing instead, open `ios/Runner.xcworkspace`.
4. Select the `Runner` target, then set their Apple Developer Team under Signing & Capabilities.
5. Confirm the bundle identifier is `com.labgo.app`.
6. In Apple Developer / App Store Connect, create or use an app record with bundle id `com.labgo.app`.
7. Archive from Xcode: Product > Archive.
8. Upload from Xcode Organizer to App Store Connect.

## Firebase note

The project uses Firebase. The client should add an iOS app in the Firebase project with bundle id `com.labgo.app`, then replace:

`ios/Runner/GoogleService-Info.plist`

with the plist downloaded from Firebase. This is especially important for push notifications.

## If they specifically ask for an IPA

They must provide Apple signing access or create the IPA themselves. A valid App Store IPA has to be signed by their Apple Developer account.
