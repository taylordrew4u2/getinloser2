# Suggested Commands
- Build/test in Xcode GUI: open `getinloser2.xcodeproj` and use Product > Build / Test.
- CLI builds (if desired): `xcodebuild -project getinloser2.xcodeproj -scheme getinloser2 -sdk iphoneos -configuration Debug build`
- List git status: `git status`
- Format Swift (if using swift-format, not present): `swift-format` (not configured here).
- Search files: `grep -R "pattern" .`
- List files: `ls`, `find . -maxdepth 2`
- JSON lint (manual): `python -m json.tool file.json`
- Note: No dedicated lint/test scripts found; rely on Xcode build/test.