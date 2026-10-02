**Scenario 09: another vendor's agent approves, unsigned.** Claude Code wrote this change for @{{operator}}, and a reviewing agent from another vendor approved it: the reviewer app, registered as an OpenAI agent. No model ran for this review; acc decides on who approved, not on what the review says. The label `agent-review` lets an agent approval satisfy independence under this repository's policy, but only when the review is signed. This one is not.

**Expected verdict: FAIL.** [ACC010](https://github.com/noru-tech/agent-change-control/blob/v0.6.0/docs/rules/ACC010.md) warns that the agent approval has no signed identity, and [ACC001](https://github.com/noru-tech/agent-change-control/blob/v0.6.0/docs/rules/ACC001.md) fails because no approval qualifies.

*Part of [agent-change-control-demo](https://github.com/noru-tech/agent-change-control-demo/blob/main/README.md). This pull request stays open on purpose.*
