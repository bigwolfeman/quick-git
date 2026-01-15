# Tasks: Quick-Git Noctalia Plugin

**Input**: Design documents from `/specs/001-quick-git-plugin/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Not explicitly requested - manual testing via QML live reload

**Organization**: Tasks grouped by user story for independent implementation and testing

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1-US7)
- File paths relative to repository root (quick-git/)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Initialize Noctalia plugin structure and core dependencies

- [x] T001 Create plugin directory structure per plan.md (Components/, Services/, Assets/, i18n/)
- [x] T002 Create manifest.json with plugin metadata, entry points, and settings schema
- [x] T003 [P] Create Main.qml with service initialization and IPC handlers
- [x] T004 [P] Create empty i18n/en.json with translation keys for all UI strings
- [x] T005 [P] Add placeholder icons to Assets/icons/ (status icons, GitHub logo)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core services that ALL user stories depend on

**CRITICAL**: No user story work can begin until this phase is complete

- [x] T006 Create Services/SettingsService.qml singleton with load/save and reactive properties
- [x] T007 Create Services/GitService.qml singleton skeleton with reactive properties (branch, status, isRepo)
- [x] T008 Implement GitService.setRepository(path) to switch repos and validate .git/ exists
- [x] T009 Implement GitService.refresh() using Process to run `git status --porcelain`
- [x] T010 Implement GitService branch detection using `git rev-parse --abbrev-ref HEAD`
- [x] T011 Implement GitService ahead/behind count using `git rev-list --left-right --count`
- [x] T012 [P] Create Components/StatusIndicator.qml with shape-based icons for all states
- [x] T013 Create Panel.qml slide-down container with view toggle and header layout
- [x] T014 Create BarWidget.qml skeleton that registers with Noctalia bar

**Checkpoint**: Foundation ready - GitService can detect repo state, Panel slides down

---

## Phase 3: User Story 1 - View Git Status at a Glance (Priority: P1)

**Goal**: Developer sees repo status in bar widget without opening terminal

**Independent Test**: Modify files in a repo, observe bar widget indicator changes, hover for tooltip

### Implementation for User Story 1

- [x] T015 [US1] Implement BarWidget.qml status indicator binding to GitService.status
- [x] T016 [US1] Add hover tooltip to BarWidget showing branch, file count, ahead/behind
- [x] T017 [US1] Implement file watcher in Main.qml using FileView for .git/HEAD and .git/index
- [x] T018 [US1] Add Timer-based polling fallback (configurable via SettingsService.refreshInterval)
- [x] T019 [US1] Connect BarWidget click to PanelService.toggle() to open panel
- [x] T020 [US1] Style StatusIndicator for clean/modified/ahead states with colorblind-safe shapes

**Checkpoint**: Bar widget shows live repo status, click opens panel

---

## Phase 4: User Story 2 - Stage and Commit Changes (Priority: P1)

**Goal**: Developer can stage files and create commits via panel UI

**Independent Test**: Modify files, open panel, stage via UI, enter message, commit, verify with `git log`

### Implementation for User Story 2

- [x] T021 [US2] Create Components/CommitsView.qml with file list grouped by Staged/Unstaged/Untracked
- [x] T022 [US2] Implement file item delegate with stage [+] and unstage [-] buttons
- [x] T023 [US2] Implement GitService.stage(filePath) using `git add <path>`
- [x] T024 [US2] Implement GitService.unstage(filePath) using `git reset HEAD <path>`
- [x] T025 [US2] Implement GitService.stageAll() using `git add -A`
- [x] T026 [US2] Add commit message TextArea with character count in CommitsView
- [x] T027 [US2] Implement GitService.commit(message) using `git commit -m`
- [x] T028 [US2] Add Commit button with disabled state when no staged files
- [x] T029 [US2] Implement GitService.push() using `git push`
- [x] T030 [US2] Add Push button visible when ahead > 0
- [x] T031 [US2] Wire CommitsView into Panel.qml as default view

**Checkpoint**: Full staging/commit/push workflow functional

---

## Phase 5: User Story 3 - View File Diffs (Priority: P2)

**Goal**: Developer can expand a file to see inline diff before committing

**Independent Test**: Modify a file, expand in panel, verify diff shows correct additions/deletions

### Implementation for User Story 3

- [x] T032 [US3] Create Components/DiffViewer.qml with ListView for diff lines
- [x] T033 [US3] Implement GitService.getDiff(filePath) using `git diff` and `git diff --cached`
- [x] T034 [US3] Implement diff parser in JavaScript (parse unified diff format into hunks/lines)
- [x] T035 [US3] Style DiffViewer with add (green), remove (red), context colors
- [x] T036 [US3] Add expand/collapse toggle to file items in CommitsView
- [x] T037 [US3] Embed DiffViewer inline when file is expanded
- [x] T038 [US3] Handle large diffs (>500 lines) with truncation and "Show full diff" option
- [x] T039 [US3] Handle binary files with "Binary file" placeholder

**Checkpoint**: File diffs display inline with proper styling

---

## Phase 6: User Story 4 - Authenticate with GitHub (Priority: P2)

**Goal**: Developer can connect GitHub account via OAuth Device Flow

**Independent Test**: Click auth icon, get code, enter on github.com/login/device, verify connected state

### Implementation for User Story 4

- [x] T040 [US4] Create Services/GitHubService.qml singleton with auth state properties
- [x] T041 [US4] Implement startAuth() - POST to /login/device/code via curl Process
- [x] T042 [US4] Implement polling Timer for token retrieval at specified interval
- [x] T043 [US4] Implement token storage using secret-tool (libsecret) via Process
- [x] T044 [US4] Implement loadStoredToken() on startup to restore session
- [x] T045 [US4] Implement logout() to clear token from keyring
- [x] T046 [US4] Add auth UI to Panel.qml showing device code and instructions during flow
- [x] T047 [US4] Add GitHub icon button in Panel footer with auth state indicator
- [x] T048 [US4] Show "Connected as @username" with avatar when authenticated
- [x] T049 [US4] Handle auth errors (expired, denied, rate limited) with user-friendly messages

**Checkpoint**: GitHub OAuth Device Flow fully functional

---

## Phase 7: User Story 5 - Browse and Manage GitHub Issues (Priority: P2)

**Goal**: Developer can view, create, and comment on GitHub issues

**Independent Test**: Authenticate, switch to Issues view, expand issue, add comment, verify on github.com

**Depends on**: US4 (authentication)

### Implementation for User Story 5

- [x] T050 [US5] Create Components/IssuesView.qml with issue list and search/filter
- [x] T051 [US5] Implement GitHubService.listIssues(owner, repo) using GitHub REST API
- [x] T052 [US5] Implement issue list delegate with number, title, status indicator, labels
- [x] T053 [US5] Create Components/IssueEditor.qml for expanded issue view with markdown body
- [x] T054 [US5] Implement markdown rendering using TextEdit.MarkdownText for issue body
- [x] T055 [US5] Implement GitHubService.getIssue() to fetch issue with comments
- [x] T056 [US5] Display comment thread in IssueEditor with author avatars
- [x] T057 [US5] Implement GitHubService.addComment() for posting new comments
- [x] T058 [US5] Add comment input TextArea with markdown preview toggle
- [x] T059 [US5] Implement "New Issue" button opening create form in IssueEditor
- [x] T060 [US5] Implement GitHubService.createIssue() with title, body, labels
- [x] T061 [US5] Implement GitHubService.closeIssue() and reopenIssue()
- [x] T062 [US5] Add close/reopen buttons to expanded issue view
- [x] T063 [US5] Implement pagination for issue lists (load more on scroll)
- [x] T064 [US5] Wire IssuesView into Panel.qml view toggle
- [x] T065 [US5] Handle offline/unauthenticated state with appropriate messaging

**Checkpoint**: Full issue management workflow functional

---

## Phase 8: User Story 6 - Switch Between Repositories (Priority: P3)

**Goal**: Developer can switch between multiple local repositories

**Independent Test**: Add repos to recent list, use dropdown to switch, verify panel updates

### Implementation for User Story 6

- [x] T066 [US6] Create Components/RepoSelector.qml dropdown component
- [x] T067 [US6] Implement recent repos list from SettingsService.recentRepos
- [x] T068 [US6] Add repo selection handler that calls GitService.setRepository()
- [x] T069 [US6] Implement path input for adding new repos to recent list
- [x] T070 [US6] Validate repo path (must contain .git/) before adding
- [x] T071 [US6] Implement SettingsService.addRecentRepo() with deduplication and limit
- [x] T072 [US6] Wire RepoSelector into Panel.qml header
- [x] T073 [US6] Update GitHubService to parse owner/repo from git remote URL
- [x] T074 [US6] Auto-detect current working directory on plugin load

**Checkpoint**: Multi-repo switching functional

---

## Phase 9: User Story 7 - Use Colorblind-Friendly Indicators (Priority: P3)

**Goal**: Colorblind users can distinguish all status states via shapes and labels

**Independent Test**: Enable colorblind mode in settings, verify all indicators show shapes + text labels

### Implementation for User Story 7

- [x] T075 [US7] Create Settings.qml panel component with preferences UI
- [x] T076 [US7] Add colorblind mode toggle binding to SettingsService.colorblindMode
- [x] T077 [US7] Add palette selector dropdown (Shapes+Labels, High Contrast, Deuteranopia, Protanopia)
- [x] T078 [US7] Update StatusIndicator to show text labels when colorblindMode enabled
- [x] T079 [US7] Define color palettes for each accessibility option in StatusIndicator
- [x] T080 [US7] Apply colorblind palette to DiffViewer add/remove colors
- [x] T081 [US7] Apply colorblind palette to issue status indicators
- [x] T082 [US7] Add settings gear icon to Panel footer opening Settings.qml
- [x] T083 [US7] Add refreshInterval setting control in Settings.qml
- [x] T084 [US7] Add defaultView setting control in Settings.qml

**Checkpoint**: Accessibility settings fully functional

---

## Phase 10: Polish & Cross-Cutting Concerns

**Purpose**: Edge cases, error handling, and final polish

- [x] T085 Handle "no git repository" state in BarWidget and Panel with guidance message
- [x] T086 Handle merge conflicts - show warning icon, display conflict markers in diff
- [x] T087 Handle large files (>1MB) - show "File too large" with external editor option
- [x] T088 Handle offline mode - cache GitHub data, show "Offline" badge
- [x] T089 Handle GitHub rate limiting - show cached data with "Rate limited" message
- [x] T090 Handle empty repository (no commits) with first commit guidance
- [x] T091 Handle expired auth token - pulse auth icon, prompt re-authentication
- [x] T092 Add keyboard shortcut support (document in quickstart.md)
- [x] T093 Performance optimization - virtualize file/issue lists for 100+ items
- [x] T094 [P] Update i18n/en.json with all final UI strings
- [ ] T095 [P] Create preview.png screenshot for plugin registry
- [x] T096 Run quickstart.md validation - verify all steps work

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1 (Setup) → Phase 2 (Foundational) → User Stories → Phase 10 (Polish)
                           ↓
              ┌────────────┼────────────┐
              ↓            ↓            ↓
           Phase 3      Phase 4      Phase 6
            (US1)        (US4)        (US6)
              ↓            ↓            ↓
           Phase 4      Phase 5      Phase 7
            (US2)        (US5)        (US7)
              ↓
           Phase 5
            (US3)
```

### User Story Dependencies

| Story | Priority | Depends On | Can Start After |
|-------|----------|------------|-----------------|
| US1 - Git Status | P1 | Foundational | Phase 2 |
| US2 - Stage/Commit | P1 | US1 (status updates) | Phase 3 |
| US3 - File Diffs | P2 | US2 (file list exists) | Phase 4 |
| US4 - GitHub Auth | P2 | Foundational | Phase 2 |
| US5 - Issues | P2 | US4 (authentication) | Phase 6 |
| US6 - Multi-Repo | P3 | Foundational | Phase 2 |
| US7 - Accessibility | P3 | US1 (indicators exist) | Phase 3 |

### Parallel Opportunities

**Within Phase 1 (Setup):**
```
T003 Main.qml  |  T004 i18n/en.json  |  T005 Assets/icons/
```

**Within Phase 2 (Foundational):**
```
T006 SettingsService  |  T012 StatusIndicator  (different files)
```

**After Phase 2 completes - Stories can run in parallel:**
```
Developer A: US1 → US2 → US3 (core git workflow)
Developer B: US4 → US5 (GitHub features)
Developer C: US6 → US7 (convenience/accessibility)
```

**Within each story - Models/Services marked [P] can parallelize**

---

## Parallel Example: Phase 2 (Foundational)

```bash
# Can run in parallel (different files):
Task: "T006 Create Services/SettingsService.qml"
Task: "T012 Create Components/StatusIndicator.qml"

# Must run sequentially (same file or dependencies):
T007 → T008 → T009 → T010 → T011 (GitService evolution)
```

## Parallel Example: User Story 2

```bash
# Models/setup can parallel:
Task: "T021 Create Components/CommitsView.qml"  # [P] new file

# Then sequential service implementation:
T023 → T024 → T025 → T027 → T029 (GitService methods build on each other)

# UI wiring last:
T031 Wire CommitsView into Panel.qml
```

---

## Implementation Strategy

### MVP First (User Stories 1 + 2)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1 (Git Status)
4. Complete Phase 4: User Story 2 (Stage/Commit)
5. **STOP and VALIDATE**: Full local git workflow functional
6. Deploy/demo - users can check status and commit without terminal

### Incremental Delivery

| Milestone | Stories Included | Value Delivered |
|-----------|------------------|-----------------|
| MVP | US1 + US2 | Local git status and commit workflow |
| +Diffs | US3 | Review changes before committing |
| +GitHub | US4 + US5 | Issue management without browser |
| +Polish | US6 + US7 | Multi-repo, accessibility |

### Suggested MVP Scope

**Minimum**: Phase 1 + Phase 2 + Phase 3 (US1) + Phase 4 (US2)
- ~31 tasks
- Delivers: Bar widget status indicator + stage/commit UI
- Tests with: `git log`, observe bar widget

---

## Summary

| Metric | Count |
|--------|-------|
| **Total Tasks** | 96 |
| **Setup Tasks** | 5 |
| **Foundational Tasks** | 9 |
| **US1 Tasks** | 6 |
| **US2 Tasks** | 11 |
| **US3 Tasks** | 8 |
| **US4 Tasks** | 10 |
| **US5 Tasks** | 16 |
| **US6 Tasks** | 9 |
| **US7 Tasks** | 10 |
| **Polish Tasks** | 12 |
| **Parallelizable [P]** | 14 |

---

## Notes

- [P] tasks = different files, no dependencies on incomplete tasks
- [US#] label maps task to specific user story
- QML live reload enables rapid iteration - no restart needed
- Test manually via Noctalia + test git repos
- Commit after each logical task group
- Stop at any checkpoint to validate story independently
