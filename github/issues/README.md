# GitHub Issue Import Notes

The canonical backlog is in `docs/ISSUES.md`.

When the repository is created on GitHub, these issues can be created manually from the Markdown file or imported with the script in `scripts/import_github_issues.rb`.

Recommended flow:

```sh
gh auth login -h github.com
ruby scripts/import_github_issues.rb --dry-run
ruby scripts/import_github_issues.rb
```

If the script cannot infer the repository from `origin`, pass it directly:

```sh
ruby scripts/import_github_issues.rb --repo shougees/support-chatbot --dry-run
ruby scripts/import_github_issues.rb --repo shougees/support-chatbot
```

The script creates suggested labels, milestones, and issues from `docs/ISSUES.md`. Existing issue titles are skipped.

Suggested next automation:

```sh
gh repo create <owner>/<repo-name> --public --source=. --remote=origin
gh issue create --title "Initialize Rails Application" --body-file <issue-body-file> --label "setup,rails,mvp" --milestone "Project Foundation"
```

Before automating issue creation, decide the repository name and whether the repo should be public or private during early development.

Current product direction: general support chatbot, OpenAI provider, background jobs from the beginning, keyword-first RAG, dynamic conversational uploads, and Render as the first documented deployment target.
