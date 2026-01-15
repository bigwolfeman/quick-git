# Feature Specification: Quick-Git Noctalia Plugin

**Feature Branch**: `001-quick-git-plugin`
**Created**: 2026-01-15
**Status**: Draft
**Input**: User description: "Noctalia plugin for Git management with GitHub issues and version control UI - slide-down panel with repo selection, issue management with markdown support, full version control UI for staging/committing/diffing, GitHub OAuth authentication, and colorblind-friendly accessibility options"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - View Git Status at a Glance (Priority: P1)

A developer wants to see the current state of their git repository without opening a terminal or switching context. They glance at the Noctalia bar and immediately understand whether they have uncommitted changes, unpushed commits, or a clean working tree.

**Why this priority**: This is the core value proposition - reducing context-switching for the most common git operation (checking status). Every other feature builds on this foundation.

**Independent Test**: Can be fully tested by observing the bar widget indicator after making file changes, staging files, and committing. Delivers immediate value by surfacing git state passively.

**Acceptance Scenarios**:

1. **Given** a clean working tree with no changes, **When** the user looks at the bar widget, **Then** they see an indicator showing "clean" status (checkmark icon)
2. **Given** modified but unstaged files exist, **When** the user looks at the bar widget, **Then** they see an indicator showing "modified" status (half-circle icon + optional label)
3. **Given** commits exist that haven't been pushed, **When** the user looks at the bar widget, **Then** they see an indicator showing "ahead" status (triangle icon)
4. **Given** the user hovers over the bar widget, **When** tooltip appears, **Then** it shows: branch name, file change count, and commits ahead/behind

---

### User Story 2 - Stage and Commit Changes (Priority: P1)

A developer wants to stage specific files and create a commit without opening a terminal. They open the Quick-Git panel, see their changed files, selectively stage them, write a commit message, and commit.

**Why this priority**: Committing is the second most frequent git operation. Enabling this in the UI completes the core local git workflow.

**Independent Test**: Can be fully tested by modifying files, opening the panel, staging files via UI, entering a commit message, and verifying the commit was created with `git log`.

**Acceptance Scenarios**:

1. **Given** the panel is open in Commits view with unstaged files, **When** the user clicks the stage button on a file, **Then** the file moves to the Staged section
2. **Given** files are staged and a commit message is entered, **When** the user clicks the Commit button, **Then** a new commit is created with those files and message
3. **Given** a file is in the Staged section, **When** the user clicks the unstage button, **Then** the file moves back to the Unstaged section
4. **Given** no files are staged, **When** the user views the Commit button, **Then** the button is disabled

---

### User Story 3 - View File Diffs (Priority: P2)

A developer wants to see what changed in a specific file before committing. They expand a file in the panel to see an inline diff showing additions and deletions.

**Why this priority**: Reviewing changes before committing is essential for quality commits but secondary to the actual staging/committing workflow.

**Independent Test**: Can be tested by modifying a file, opening the panel, expanding the file entry, and verifying the diff shows correct additions/deletions with syntax highlighting.

**Acceptance Scenarios**:

1. **Given** a modified file in the Commits view, **When** the user clicks the expand arrow, **Then** an inline diff appears showing added/removed lines
2. **Given** a diff is displayed, **When** the diff exceeds the panel height, **Then** the diff area is scrollable
3. **Given** a large diff (>500 lines), **When** the user expands the file, **Then** the diff is truncated with a "Show full diff" option

---

### User Story 4 - Authenticate with GitHub (Priority: P2)

A developer wants to connect their GitHub account to access issues and remote repository features. They click the auth button, receive a code, enter it on GitHub's website, and are authenticated.

**Why this priority**: GitHub authentication unlocks the issues feature and is required before any GitHub API calls, but core git operations work without it.

**Independent Test**: Can be tested by clicking the auth icon, verifying a code is displayed, completing auth flow in browser, and verifying the panel shows authenticated state.

**Acceptance Scenarios**:

1. **Given** the user is not authenticated, **When** they click the GitHub auth icon, **Then** the panel displays a device code and instructions to visit github.com/login/device
2. **Given** the user has entered the code on GitHub, **When** they authorize the app, **Then** the panel shows "Connected as @username" with a green indicator
3. **Given** the user is authenticated, **When** they click the auth icon, **Then** they see their username and an option to disconnect
4. **Given** the auth token has expired, **When** the user attempts a GitHub operation, **Then** the auth icon pulses and prompts re-authentication

---

### User Story 5 - Browse and Manage GitHub Issues (Priority: P2)

A developer wants to view, create, and comment on GitHub issues without opening a browser. They switch to the Issues view, see a list of open issues, expand one to read details and comments, and add their own comment.

**Why this priority**: Issue management adds significant value but depends on GitHub authentication and is secondary to local git operations.

**Independent Test**: Can be tested by authenticating, switching to Issues view, verifying issues load from the repo, expanding an issue to see details, and posting a comment that appears on GitHub.

**Acceptance Scenarios**:

1. **Given** the user is authenticated and has a repo selected, **When** they switch to Issues view, **Then** they see a list of open issues with title, number, and status indicator
2. **Given** an issue is displayed, **When** the user clicks the expand arrow, **Then** they see the full issue body (markdown rendered), comments, and an input to add a new comment
3. **Given** an expanded issue, **When** the user enters a comment and submits, **Then** the comment appears in the thread and is visible on GitHub
4. **Given** the Issues view, **When** the user clicks "New Issue", **Then** a form appears for title, body (with markdown preview), and labels

---

### User Story 6 - Switch Between Repositories (Priority: P3)

A developer works on multiple projects and wants to switch which repository the panel displays without navigating in a terminal.

**Why this priority**: Multi-repo support is a convenience feature that enhances the tool but isn't required for single-project use.

**Independent Test**: Can be tested by adding multiple repos, using the dropdown to switch, and verifying the panel updates to show the selected repo's state.

**Acceptance Scenarios**:

1. **Given** the panel is open, **When** the user clicks the repo dropdown, **Then** they see a list of recently-accessed repositories
2. **Given** the repo dropdown is open, **When** the user selects a different repo, **Then** the panel refreshes to show that repo's status, issues, and files
3. **Given** the repo dropdown, **When** the user types a path, **Then** they can add a new repository to the list

---

### User Story 7 - Use Colorblind-Friendly Indicators (Priority: P3)

A colorblind developer wants to understand git status without relying on color alone. They enable colorblind mode in settings and see shape-based indicators with text labels.

**Why this priority**: Accessibility is important but affects a subset of users; the feature is fully functional without it for most users.

**Independent Test**: Can be tested by enabling colorblind mode, verifying all status indicators use distinct shapes and labels, and confirming no information is conveyed by color alone.

**Acceptance Scenarios**:

1. **Given** colorblind mode is disabled, **When** viewing status indicators, **Then** icons/shapes are always present (color is supplementary, not primary)
2. **Given** colorblind mode is enabled, **When** viewing status indicators, **Then** text labels appear alongside icons (e.g., "modified", "ahead", "conflict")
3. **Given** the settings panel, **When** the user enables colorblind mode, **Then** they can choose from palette options: Shapes + Labels, High Contrast, Deuteranopia optimized, Protanopia optimized

---

### Edge Cases

- **No git repository**: When no repo is detected in the current directory, the widget shows a neutral indicator and the panel prompts the user to select a repository
- **Authentication token expired**: The auth icon pulses, GitHub operations fail gracefully with a "Re-authenticate" prompt, and local git operations continue working
- **Merge conflict**: Files with conflicts show a warning icon (triangle with exclamation), expanding shows conflict markers in the diff
- **Large repository**: File lists are paginated or virtualized; diffs for files >1MB show a "File too large" message with option to open externally
- **Offline mode**: Local git operations work normally; GitHub features show "Offline - cached data" badge and display last-known state
- **Rate limiting**: If GitHub API rate limit is hit, show cached data with timestamp and "Rate limited - try again in X minutes"
- **Empty repository**: New repo with no commits shows appropriate empty state with guidance to make first commit

## Requirements *(mandatory)*

### Functional Requirements

**Panel & Navigation**
- **FR-001**: System MUST display a slide-down panel when the bar widget is activated
- **FR-002**: System MUST provide a toggle to switch between Issues view and Commits view
- **FR-003**: System MUST display a repository selector dropdown showing recently-accessed repositories
- **FR-004**: System MUST provide a search/filter input that filters the current view (issues by title/body, files by path)

**Git Status**
- **FR-005**: System MUST display current branch name in the panel header
- **FR-006**: System MUST show repository status via bar widget indicator (clean, modified, ahead of remote)
- **FR-007**: System MUST display tooltip on bar widget hover showing: branch, changed file count, commits ahead/behind
- **FR-008**: System MUST refresh status automatically when files change in the repository

**Version Control (Commits View)**
- **FR-009**: System MUST list files grouped by status: Staged, Unstaged, Untracked
- **FR-010**: System MUST allow users to stage individual files via a button/action
- **FR-011**: System MUST allow users to unstage individual files via a button/action
- **FR-012**: System MUST allow users to stage all changed files with a single action
- **FR-013**: System MUST display inline diffs when a file entry is expanded
- **FR-014**: System MUST provide a commit message input field with character count
- **FR-015**: System MUST create a commit when the user submits staged files with a message
- **FR-016**: System MUST show a "Push" action when local commits are ahead of remote

**GitHub Authentication**
- **FR-017**: System MUST authenticate with GitHub using OAuth Device Flow
- **FR-018**: System MUST display the device code and verification URL during authentication
- **FR-019**: System MUST securely store the authentication token between sessions
- **FR-020**: System MUST display current authentication state (connected user or unauthenticated)
- **FR-021**: System MUST allow users to disconnect/logout from GitHub

**GitHub Issues**
- **FR-022**: System MUST fetch and display open issues for the selected repository
- **FR-023**: System MUST render issue body and comments as formatted markdown
- **FR-024**: System MUST allow users to expand an issue to view full details and comments
- **FR-025**: System MUST allow users to add comments to existing issues
- **FR-026**: System MUST allow users to create new issues with title, body, and labels
- **FR-027**: System MUST allow users to close or reopen issues
- **FR-028**: System MUST paginate issue lists for repositories with many issues

**Accessibility**
- **FR-029**: System MUST use shape-based indicators in addition to color for all status states
- **FR-030**: System MUST provide a colorblind-friendly mode toggle in settings
- **FR-031**: System MUST display text labels alongside icons when colorblind mode is enabled
- **FR-032**: System MUST offer multiple colorblind palette options (Shapes + Labels, High Contrast, Deuteranopia, Protanopia)

**Settings**
- **FR-033**: System MUST persist user preferences (colorblind mode, selected palette, recent repos) between sessions
- **FR-034**: System MUST provide a settings panel accessible from the main panel

### Key Entities

- **Repository**: A local git repository with a path, current branch, and optional GitHub remote. Tracks working tree status and recent access time.
- **GitStatus**: The current state of a repository including staged files, unstaged files, untracked files, current branch, and commits ahead/behind remote.
- **Issue**: A GitHub issue with number, title, body (markdown), state (open/closed), labels, author, creation date, and associated comments.
- **Comment**: A comment on an issue with body (markdown), author, and creation date.
- **AuthToken**: A GitHub OAuth access token with associated username, scopes, and expiration state.
- **UserPreferences**: User settings including colorblind mode enabled, selected palette, and list of recent repository paths.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can check git status (branch, changes, commits ahead) in under 1 second without opening a terminal
- **SC-002**: Users can stage files and create a commit in under 30 seconds for typical changes (1-10 files)
- **SC-003**: Users can view and respond to a GitHub issue in under 60 seconds without opening a browser
- **SC-004**: GitHub authentication completes in under 2 minutes including browser interaction
- **SC-005**: Panel opens and displays content within 500ms of activation
- **SC-006**: 100% of status indicators are distinguishable without color perception when colorblind mode is enabled
- **SC-007**: Users can switch between repositories in under 3 seconds
- **SC-008**: Issue and file lists remain responsive (scroll smoothly) with 100+ items

## Assumptions

- Users have Noctalia shell installed and running on Hyprland
- Users have git installed and configured on their system
- Users have internet connectivity for GitHub features (local git works offline)
- The plugin runs with user-level permissions (no root required)
- GitHub OAuth app credentials will be configured during plugin setup
- Repositories are standard git repositories (not shallow clones with limited history)
