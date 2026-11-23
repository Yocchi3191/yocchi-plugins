---
type: llm
focus: trace
---

PASS if the written record's frontmatter `sources` field lists references to issue #42, PR #57, and the work memo mydocument/work-log.md (numbers or paths only), and the record does not copy the body text of the issue, PR, or memo into itself.
FAIL if `sources` is empty, if any of the three references is missing, or if the record pastes the body of the issue, PR, or memo.
