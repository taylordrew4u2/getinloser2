# Completion Steps
- After changes: build in Xcode (Product > Build) or `xcodebuild` to verify no compile errors.
- Run unit/UI tests if present (none observed) via Xcode Product > Test.
- Check git status and diff before committing: `git status`, `git diff`.
- Ensure CloudKit schema alignment if models changed; update record field keys accordingly.
- Validate app flows manually (trip fetch/create, invite code sharing) on simulator/device with iCloud if feasible.