**Scenario 04: the agent is known, its operator is not.** The writer app is mapped to Claude Code in the workflow (`agent-account`), but nothing here names the human who directed it. @{{reviewer}} approved the head, yet acc cannot tell whether that reviewer was independent of an operator it does not know.

**Expected verdict: WARN** on [ACC006](https://github.com/noru-tech/agent-change-control/blob/v0.6.0/docs/rules/ACC006.md) (operator unknown). [ACC001](https://github.com/noru-tech/agent-change-control/blob/v0.6.0/docs/rules/ACC001.md) is `unknown`, not pass and not fail. Unknown is reported as unknown. The check stays green because ACC006 is a warning under the default policy.

*Part of [agent-change-control-demo](https://github.com/noru-tech/agent-change-control-demo/blob/main/README.md). This pull request stays open on purpose.*
