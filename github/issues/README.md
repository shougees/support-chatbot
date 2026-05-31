# GitHub Issue Import Notes

The canonical backlog is in `docs/ISSUES.md`.

When the repository is created on GitHub, these issues can be created manually from the Markdown file or scripted with the GitHub CLI.

Suggested next automation:

```sh
gh repo create <owner>/<repo-name> --public --source=. --remote=origin
gh issue create --title "Initialize Rails Application" --body-file <issue-body-file> --label "setup,rails,mvp" --milestone "Project Foundation"
```

Before automating issue creation, decide the repository name and whether the repo should be public or private during early development.

Current product direction: general support chatbot, OpenAI provider, background jobs from the beginning, keyword-first RAG, dynamic conversational uploads, and Render as the first documented deployment target.
