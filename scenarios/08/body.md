**Scenario 08: a reviewer from the same vendor.** Claude Code wrote this change for @{{operator}}. A reviewing agent built on another Anthropic model approved it. That is a model checking its own vendor's work, and no human approved.

**Expected verdict: FAIL** on [ACC008](https://github.com/noru-tech/agent-change-control/blob/v0.6.0/docs/rules/ACC008.md) (same-vendor write and review) and [ACC001](https://github.com/noru-tech/agent-change-control/blob/v0.6.0/docs/rules/ACC001.md). [ACC007](https://github.com/noru-tech/agent-change-control/blob/v0.6.0/docs/rules/ACC007.md) records the agent approval as an observation (info).

*Part of [agent-change-control-demo](https://github.com/noru-tech/agent-change-control-demo/blob/main/README.md). This pull request stays open on purpose.*
