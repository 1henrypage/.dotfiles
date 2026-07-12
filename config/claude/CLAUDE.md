# global agent instructions
## All the time
- Never use the em dash "—". Use plain dash "-" instead
- When writing commit messages, NEVER auto-add your agent name as co-author
- Never manually modify CHANGELOG.md files or any files that are marked as auto-generated
- When making technical decisions, do not give much weight to development cost.
  Instead, prefer quality, simplicity, robustness, scalability, and long term maintainability.
- When doing bug fixes, always start with reproducing the bug in an E2E setting as closely aligned with how an end user would experience it as possible.
  This makes sure you find the real problem so your fix will actually solve it.
- When end-to-end testing a product, be picky about the UI you see and be obsessed with pixel perfection.
  If something clearly looks off, even if it is not directly related to what you are doing, try to get it fixed along the way.
- Apply that same high standard to engineering excellence: lint, test failures, and test flakiness. YOU ARE WRITING FOR A DATABRICKS BIG TECH ENGINEER. ENGINEERING EXCELLENCE IS OF UTMOST IMPORTANCE! APPLY ALL BEST PRACTICES!
  If you see one, even if it is not caused by what you are working on right now, still get it fixed. Or if it's really not in scope of the current issue, inform henry about it.

## Writing content
- Read WRITING.md for writing rules. You should implicitly know when to follow these rules based on the task at hand (if it is clearly writing)



