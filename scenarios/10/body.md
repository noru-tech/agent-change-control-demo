**Scenario 10: four eyes with no human approval.** Claude Code wrote this change, and the writer workflow signed a provenance document naming the agent and its operator, @{{operator}}. An OpenAI model reviewed and approved it through the reviewer app, and the reviewer workflow signed a review document naming that reviewer and its operator, @{{reviewer}}. The two signatures come from different workflows. Under the `agent-review` policy, acc checks that the reviewer is independent of the author on operator, vendor and signing identity.

**Expected verdict: PASS** with no human approval on this pull request ([ACC009](https://github.com/noru-tech/agent-change-control/blob/v0.6.0/docs/rules/ACC009.md), [ACC001](https://github.com/noru-tech/agent-change-control/blob/v0.6.0/docs/rules/ACC001.md)). [ACC007](https://github.com/noru-tech/agent-change-control/blob/v0.6.0/docs/rules/ACC007.md) records the agent approval as an observation, so acc's table shows WARN while the check passes.

The trust assumptions and the limitation are in [the README](https://github.com/noru-tech/agent-change-control-demo/blob/main/README.md#scenario-10-four-eyes-with-no-human-approval).

*Part of [agent-change-control-demo](https://github.com/noru-tech/agent-change-control-demo/blob/main/README.md). This pull request stays open on purpose.*
