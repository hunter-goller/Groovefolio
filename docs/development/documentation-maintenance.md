# Documentation maintenance

Living docs must describe the current `main` branch, not an old ticket snapshot.

When a feature changes:

1. update the relevant feature doc
2. update architecture docs if boundaries/schema/routes changed
3. update implementation status and roadmap
4. update setup/testing docs when developer workflow changes
5. add a changelog entry for meaningful milestones

Historical overlay notes live in `docs/archive/apply-notes/` and patch notes in `docs/Patch_Notes/`. Do not use their old apply instructions on current `main`. Historical patch notes should not be rewritten into current-state docs. They may carry a note that the product was later renamed to Groovefolio, but their technical content remains historical.

The product name is Groovefolio; `vinyl_app` and `VinylApp-###` may still appear when referring to technical or historical identifiers.

## Keep the guide and source connected

The [developer guide](../developer-guide.md) is the cross-repository entry point. Update its workflow, source/test map, configuration, migration, and deployment-status sections when their contracts change. Keep detailed feature contracts in the narrower pages and link to them rather than maintaining contradictory copies.

Use Dart `///` comments for a public operation's purpose, inputs (including null/empty meaning), return/error contract, and side effects. Use `//` for non-obvious implementation ordering or tradeoffs. Explain why a transaction, cooldown reservation, or cleanup step exists instead of narrating each line. Do not hand-document generated files.

For documentation-only changes, check Markdown file links and heading anchors, compare commands with the actual scripts, and make destructive command effects explicit. Confirm that Dart edits change comments only. When behavior does change, update its source, meaningful tests, guide, and implementation status together.
