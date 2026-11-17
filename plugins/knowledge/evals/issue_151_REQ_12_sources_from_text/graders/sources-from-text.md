---
type: llm
focus: trace
---

PASS if the written record's frontmatter `sources` field lists issue #42 and the pull request 57 (as the number or the URL https://github.com/example/app/pull/57), and does not list #99.
FAIL if `sources` is empty, if #42 or PR 57 is missing, or if #99 is listed (it was only mentioned and has nothing to do with this decision).
