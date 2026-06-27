# Workspace Customization Rules

Before working on any task or editing code in this workspace, the agent MUST:
1. Read the central knowledge base at [brain.md](file:///c:/Users/Ganesh%20shah/last/brain.md) using the `view_file` tool.
2. Align all frontend UI changes with the existing Next.js Base UI trigger pattern (`render={<Element />}`).
3. Verify that the mobile app changes conform to the responsive layout structures and `Wrap` designs.
4. Proactively run verification checks (`npx tsc --noEmit` and `flutter analyze`) to check for regressions.
