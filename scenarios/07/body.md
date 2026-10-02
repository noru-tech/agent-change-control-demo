**Scenario 07: authorship from an Agent Trace record.** @{{operator}} opened this pull request with no declaration. The record under `traces/` is in [Agent Trace](https://agent-trace.dev) format and is bound to the first commit by `vcs.revision`. acc reads it as `derived` evidence that Claude Code wrote that code. @{{reviewer}} approved.

**Expected verdict: PASS** on `derived` evidence ([ACC001](https://github.com/noru-tech/agent-change-control/blob/v0.6.0/docs/rules/ACC001.md)).

*Part of [agent-change-control-demo](https://github.com/noru-tech/agent-change-control-demo/blob/main/README.md). This pull request stays open on purpose.*
