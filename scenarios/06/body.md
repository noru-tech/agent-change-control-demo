**Scenario 06: authorship from commit trailers.** @{{operator}} opened this pull request with no declaration. Its commit carries the `Co-Authored-By: Claude <noreply@anthropic.com>` trailer that Claude Code writes, and acc reads it as `derived` evidence. One human authored every commit, so that human is the derived operator. @{{reviewer}} approved.

**Expected verdict: PASS** on `derived` evidence ([ACC001](https://github.com/noru-tech/agent-change-control/blob/v0.6.0/docs/rules/ACC001.md)). A team can start from what its agents already write, without new tooling.

*Part of [agent-change-control-demo](https://github.com/noru-tech/agent-change-control-demo/blob/main/README.md). This pull request stays open on purpose.*
