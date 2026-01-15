# GitHubService Contract

> Internal service contract for GitHub API operations and authentication

## Overview

`GitHubService` is a QML Singleton that manages GitHub OAuth authentication and API operations. It uses `curl` via `Quickshell.Io.Process` for HTTP requests and `secret-tool` for secure token storage.

---

## Properties (Reactive)

| Property | Type | Description |
|----------|------|-------------|
| `isAuthenticated` | boolean | User is logged in with valid token |
| `username` | string | Authenticated user's GitHub login |
| `avatarUrl` | string | User's avatar image URL |
| `authState` | enum | `idle`, `awaiting_code`, `polling`, `authenticated`, `error` |
| `deviceCode` | string | Current device code (during auth flow) |
| `userCode` | string | User code to enter on GitHub |
| `verificationUrl` | string | URL for user to visit |
| `error` | string | Last error message |
| `isLoading` | boolean | API request in progress |
| `rateLimitRemaining` | number | Remaining API requests |
| `rateLimitReset` | timestamp | When rate limit resets |

---

## Authentication Methods

### startAuth()

Begin OAuth Device Flow authentication.

```
Input:  none
Output: none (updates authState, deviceCode, userCode)

Flow:
1. POST https://github.com/login/device/code
   Body: { client_id, scope: "repo user" }
2. Display userCode to user
3. Start polling timer
4. Poll until success or timeout
```

**State Transitions**:
```
idle → awaiting_code → polling → authenticated
                   └→ error (on timeout/rejection)
```

---

### cancelAuth()

Cancel in-progress authentication.

```
Input:  none
Output: none
```

**Side Effects**: Stops polling timer, clears device code

---

### logout()

Disconnect from GitHub.

```
Input:  none
Output: none
```

**Side Effects**:
- Clears token from keyring (`secret-tool`)
- Clears username, avatarUrl
- Sets `authState` to `idle`

---

### loadStoredToken()

Load token from secure storage on startup.

```
Input:  none
Output: boolean - true if valid token found
Command: secret-tool lookup application quick-git type github-token
```

**Side Effects**: If token found, validates with `/user` endpoint

---

## Issues Methods

### listIssues(owner: string, repo: string, options?: object): Issue[]

Fetch issues for a repository.

```
Input:
  owner   - Repository owner
  repo    - Repository name
  options - { state?: 'open'|'closed'|'all', page?: number, perPage?: number }

Output: Issue[] (see data-model.md)

API: GET /repos/{owner}/{repo}/issues
```

**Default Options**:
- `state`: `'open'`
- `page`: `1`
- `perPage`: `30`

---

### getIssue(owner: string, repo: string, number: number): Issue

Fetch a single issue with comments.

```
Input:
  owner  - Repository owner
  repo   - Repository name
  number - Issue number

Output: Issue with comments populated

API: GET /repos/{owner}/{repo}/issues/{number}
     GET /repos/{owner}/{repo}/issues/{number}/comments
```

---

### createIssue(owner: string, repo: string, title: string, body?: string, labels?: string[]): Issue

Create a new issue.

```
Input:
  owner  - Repository owner
  repo   - Repository name
  title  - Issue title (required)
  body   - Issue body markdown (optional)
  labels - Label names (optional)

Output: Created Issue object

API: POST /repos/{owner}/{repo}/issues
Body: { title, body, labels }
```

**Validation**:
- `title` must be non-empty

---

### updateIssue(owner: string, repo: string, number: number, updates: object): Issue

Update an existing issue.

```
Input:
  owner   - Repository owner
  repo    - Repository name
  number  - Issue number
  updates - { title?, body?, state?, state_reason?, labels? }

Output: Updated Issue object

API: PATCH /repos/{owner}/{repo}/issues/{number}
```

---

### closeIssue(owner: string, repo: string, number: number, reason?: string): Issue

Close an issue.

```
Input:
  owner  - Repository owner
  repo   - Repository name
  number - Issue number
  reason - 'completed' | 'not_planned' (default: 'completed')

Output: Updated Issue object

API: PATCH /repos/{owner}/{repo}/issues/{number}
Body: { state: 'closed', state_reason }
```

---

### reopenIssue(owner: string, repo: string, number: number): Issue

Reopen a closed issue.

```
Input:
  owner  - Repository owner
  repo   - Repository name
  number - Issue number

Output: Updated Issue object

API: PATCH /repos/{owner}/{repo}/issues/{number}
Body: { state: 'open' }
```

---

### addComment(owner: string, repo: string, number: number, body: string): Comment

Add a comment to an issue.

```
Input:
  owner  - Repository owner
  repo   - Repository name
  number - Issue number
  body   - Comment body (markdown)

Output: Created Comment object

API: POST /repos/{owner}/{repo}/issues/{number}/comments
Body: { body }
```

**Validation**:
- `body` must be non-empty

---

## Signals

| Signal | Parameters | Description |
|--------|------------|-------------|
| `authStateChanged` | enum state | Authentication state changed |
| `authenticated` | string username | Successfully authenticated |
| `authFailed` | string error | Authentication failed |
| `issuesLoaded` | Issue[] issues | Issues list fetched |
| `issueUpdated` | Issue issue | Issue created/updated |
| `commentAdded` | Comment comment | Comment added |
| `errorOccurred` | string message | API error occurred |
| `rateLimited` | timestamp reset | Rate limit hit |

---

## API Endpoints Used

| Operation | Method | Endpoint |
|-----------|--------|----------|
| Device code | POST | `https://github.com/login/device/code` |
| Access token | POST | `https://github.com/login/oauth/access_token` |
| Get user | GET | `/user` |
| List issues | GET | `/repos/{owner}/{repo}/issues` |
| Get issue | GET | `/repos/{owner}/{repo}/issues/{number}` |
| Create issue | POST | `/repos/{owner}/{repo}/issues` |
| Update issue | PATCH | `/repos/{owner}/{repo}/issues/{number}` |
| List comments | GET | `/repos/{owner}/{repo}/issues/{number}/comments` |
| Add comment | POST | `/repos/{owner}/{repo}/issues/{number}/comments` |

---

## Error Handling

| Error Code | HTTP Status | Condition | User Message |
|------------|-------------|-----------|--------------|
| `UNAUTHORIZED` | 401 | Invalid/expired token | "Session expired - please log in again" |
| `FORBIDDEN` | 403 | Insufficient permissions | "Permission denied - check token scopes" |
| `NOT_FOUND` | 404 | Repo/issue doesn't exist | "Not found" |
| `RATE_LIMITED` | 403 | Rate limit exceeded | "Rate limited - try again in X minutes" |
| `VALIDATION_FAILED` | 422 | Invalid request | GitHub error message |
| `NETWORK_ERROR` | - | curl failed | "Network error - check connection" |
| `AUTH_PENDING` | - | User hasn't entered code | (continue polling) |
| `AUTH_EXPIRED` | - | Device code expired | "Code expired - try again" |
| `AUTH_DENIED` | - | User denied access | "Access denied by user" |

---

## Request Headers

All API requests include:

```
Authorization: Bearer {token}
Accept: application/vnd.github+json
X-GitHub-Api-Version: 2022-11-28
User-Agent: Quick-Git-Noctalia/1.0
```

---

## Token Storage

| Operation | Command |
|-----------|---------|
| Store | `echo -n TOKEN \| secret-tool store --label="Quick-Git" application quick-git type github-token` |
| Retrieve | `secret-tool lookup application quick-git type github-token` |
| Delete | `secret-tool clear application quick-git type github-token` |
