# Documentation maintenance

Living docs must describe the current `main` branch, not an old ticket snapshot.

When a feature changes:
1. update the relevant feature doc
2. update architecture docs if boundaries/schema/routes changed
3. update implementation status and roadmap
4. update setup/testing docs when developer workflow changes
5. add a changelog entry for meaningful milestones

Historical patch notes should not be rewritten into current-state docs. They may carry a note that the product was later renamed to Groovefolio, but their technical content remains historical.

The product name is Groovefolio; `vinyl_app` and `VinylApp-###` may still appear when referring to technical or historical identifiers.
