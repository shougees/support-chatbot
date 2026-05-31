#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "open3"
require "shellwords"

ROOT = File.expand_path("..", __dir__)
ISSUES_FILE = File.join(ROOT, "docs", "ISSUES.md")

LABEL_COLORS = {
  "ai" => "7B61FF",
  "analytics" => "0E8A16",
  "architecture" => "5319E7",
  "backend" => "1D76DB",
  "chat" => "FBCA04",
  "content" => "C5DEF5",
  "database" => "006B75",
  "deployment" => "0E8A16",
  "docs" => "0075CA",
  "frontend" => "D876E3",
  "github" => "24292F",
  "knowledge-base" => "BFDADC",
  "jobs" => "5319E7",
  "mvp" => "FBCA04",
  "operator" => "C2E0C6",
  "quality" => "D93F0B",
  "rails" => "CC0000",
  "release" => "0E8A16",
  "search" => "BFD4F2",
  "security" => "D73A4A",
  "setup" => "C5DEF5",
  "support-ops" => "7057FF",
  "testing" => "A2EEEF",
  "ui" => "D4C5F9",
  "uploads" => "F9D0C4"
}.freeze

def usage
  puts <<~TEXT
    Usage:
      ruby scripts/import_github_issues.rb --repo OWNER/REPO --dry-run
      ruby scripts/import_github_issues.rb --repo OWNER/REPO

    Defaults:
      --repo is inferred from the GitHub remote when possible.

    Safety:
      --dry-run prints what would be created.
      Existing issue titles are skipped.
      Existing labels and milestones are reused.
  TEXT
end

def parse_args(argv)
  args = {
    repo: nil,
    dry_run: false
  }

  until argv.empty?
    arg = argv.shift
    case arg
    when "--repo"
      args[:repo] = argv.shift
    when "--dry-run"
      args[:dry_run] = true
    when "-h", "--help"
      usage
      exit 0
    else
      warn "Unknown argument: #{arg}"
      usage
      exit 1
    end
  end

  args
end

def run(*command, dry_run: false)
  printable = command.shelljoin
  if dry_run
    puts "$ #{printable}"
    return ""
  end

  stdout, stderr, status = Open3.capture3(*command)
  return stdout if status.success?

  raise "Command failed: #{printable}\n#{stderr}"
end

def infer_repo
  stdout, = Open3.capture2("git", "remote", "get-url", "origin", chdir: ROOT)
  remote = stdout.strip

  case remote
  when %r{\Agit@github\.com:(.+?)(?:\.git)?\z}
    Regexp.last_match(1)
  when %r{\Ahttps://github\.com/(.+?)(?:\.git)?\z}
    Regexp.last_match(1)
  end
end

def parse_issues(markdown)
  current_milestone = nil
  issues = []
  current = nil

  markdown.each_line do |line|
    if line.match?(/\A## Suggested /)
      issues << current if current
      current = nil
      next
    end

    if (match = line.match(/\A## Milestone \d+:\s*(.+?)\s*\z/))
      current_milestone = match[1]
      next
    end

    if (match = line.match(/\A### Issue \d+:\s*(.+?)\s*\z/))
      issues << current if current
      current = {
        title: match[1],
        milestone: current_milestone,
        labels: [],
        body_lines: []
      }
      next
    end

    next unless current
    next if line.match?(/\A---\s*\z/)

    if (match = line.match(/\A\*\*Labels:\*\*\s*(.+?)\s*\z/))
      current[:labels] = match[1].scan(/`([^`]+)`/).flatten
      next
    end

    current[:body_lines] << line
  end

  issues << current if current

  issues.each do |issue|
    issue[:body] = issue[:body_lines].join.strip
    issue.delete(:body_lines)
  end

  issues
end

def parse_suggested_list(markdown, heading)
  section = markdown.split("## #{heading}", 2)[1]
  return [] unless section

  section = section.split(/\n## /, 2)[0]
  section.scan(/^- `?([^`\n]+?)`?\s*$/).flatten.map(&:strip)
end

def existing_issue_titles(repo)
  json = run(
    "gh", "issue", "list",
    "--repo", repo,
    "--state", "all",
    "--limit", "1000",
    "--json", "title"
  )
  JSON.parse(json).map { |item| item.fetch("title") }
end

def existing_milestones(repo)
  json = run(
    "gh", "api",
    "repos/#{repo}/milestones",
    "-f", "state=all",
    "--paginate"
  )
  JSON.parse(json).map { |item| item.fetch("title") }
end

def ensure_labels(repo, labels, dry_run)
  labels.each do |label|
    color = LABEL_COLORS.fetch(label, "EDEDED")
    command = ["gh", "label", "create", label, "--repo", repo, "--color", color]

    if dry_run
      run(*command, dry_run: true)
      next
    end

    _stdout, stderr, status = Open3.capture3(*command)
    next if status.success?
    next if stderr.include?("already exists")

    raise "Could not create label #{label}: #{stderr}"
  end
end

def ensure_milestones(repo, milestones, dry_run)
  existing = dry_run ? [] : existing_milestones(repo)

  milestones.each do |milestone|
    next if existing.include?(milestone)

    run(
      "gh", "api",
      "repos/#{repo}/milestones",
      "-f", "title=#{milestone}",
      dry_run: dry_run
    )
  end
end

def create_issues(repo, issues, dry_run)
  existing_titles = dry_run ? [] : existing_issue_titles(repo)

  issues.each do |issue|
    if existing_titles.include?(issue[:title])
      puts "Skipping existing issue: #{issue[:title]}"
      next
    end

    command = [
      "gh", "issue", "create",
      "--repo", repo,
      "--title", issue[:title],
      "--body", issue[:body]
    ]

    issue[:labels].each do |label|
      command += ["--label", label]
    end

    command += ["--milestone", issue[:milestone]] if issue[:milestone]

    run(*command, dry_run: dry_run)
  end
end

args = parse_args(ARGV)
repo = args[:repo] || infer_repo

unless repo
  warn "Could not infer GitHub repo. Pass --repo OWNER/REPO."
  exit 1
end

unless File.exist?(ISSUES_FILE)
  warn "Could not find #{ISSUES_FILE}"
  exit 1
end

markdown = File.read(ISSUES_FILE)
issues = parse_issues(markdown)
labels = parse_suggested_list(markdown, "Suggested Labels")
milestones = parse_suggested_list(markdown, "Suggested Milestones")

puts "Repository: #{repo}"
puts "Issues: #{issues.length}"
puts "Labels: #{labels.length}"
puts "Milestones: #{milestones.length}"
puts

ensure_labels(repo, labels, args[:dry_run])
ensure_milestones(repo, milestones, args[:dry_run])
create_issues(repo, issues, args[:dry_run])

puts
puts args[:dry_run] ? "Dry run complete." : "GitHub issue import complete."
