**Scenario 05: the approval goes stale.** @{{reviewer}} approved the first commit. The agent then pushed another commit, and nobody approved the new head.

**Expected verdict: FAIL** on [ACC001](https://github.com/noru-tech/agent-change-control/blob/v0.6.0/docs/rules/ACC001.md): an approval counts only for the commit it was given on.

*Part of [agent-change-control-demo](https://github.com/noru-tech/agent-change-control-demo/blob/main/README.md). This pull request stays open on purpose.*
