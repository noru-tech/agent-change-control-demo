**Scenario 02: the operator approves their own agent's change.** Claude Code wrote this change for @{{operator}}, and @{{operator}} approved it. GitHub sees two accounts, the writer app and a human, but only one person made a judgment.

**Expected verdict: FAIL** on [ACC001](https://github.com/noru-tech/agent-change-control/blob/v0.6.0/docs/rules/ACC001.md) (no independent approval) and [ACC002](https://github.com/noru-tech/agent-change-control/blob/v0.6.0/docs/rules/ACC002.md) (the effective human approved their own change).

*Part of [agent-change-control-demo](https://github.com/noru-tech/agent-change-control-demo/blob/main/README.md). This pull request stays open on purpose.*
