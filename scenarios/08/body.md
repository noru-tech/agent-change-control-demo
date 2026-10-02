**Scenario 08: a reviewer from the same vendor.** Claude Code wrote this change for @{{operator}}. A reviewing agent account from the same vendor approved it: the reviewer app is registered as `claude-code-review` (Anthropic). That is a vendor checking its own work, and no human approved. No model ran for this review; acc decides on who approved which commit, not on what the review says.

**Expected verdict: FAIL** on [ACC008](https://github.com/noru-tech/agent-change-control/blob/v0.6.0/docs/rules/ACC008.md) (same-vendor write and review) and [ACC001](https://github.com/noru-tech/agent-change-control/blob/v0.6.0/docs/rules/ACC001.md). [ACC007](https://github.com/noru-tech/agent-change-control/blob/v0.6.0/docs/rules/ACC007.md) records the agent approval as an observation (info).

*Part of [agent-change-control-demo](https://github.com/noru-tech/agent-change-control-demo/blob/main/README.md). This pull request stays open on purpose.*
