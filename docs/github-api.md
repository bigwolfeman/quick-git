# GitHub API Reference

> Reference documentation for the Quick-Git Noctalia plugin

## Overview

This document covers the GitHub APIs needed for the Quick-Git plugin:
1. **OAuth Device Flow** - CLI/desktop authentication
2. **Issues API** - List, create, update, and comment on issues
3. **Repository Contents API** - File operations
4. **Git Database API** - Raw Git operations

**Base URL:** `https://api.github.com`
**API Version:** `2022-11-28`

## OAuth Device Flow Authentication

The Device Flow is ideal for CLI and desktop applications because:
- No redirect URL required
- No client secret needed (more secure for desktop apps)
- User authenticates in their browser

### Flow Overview

1. App requests device and user codes
2. User visits `github.com/login/device` and enters code
3. App polls for authorization status
4. On success, app receives access token

### Step 1: Request Device Code

**Endpoint:** `POST https://github.com/login/device/code`

**Headers:**
```
Accept: application/json
Content-Type: application/json
```

**Request Body:**
```json
{
  "client_id": "YOUR_CLIENT_ID",
  "scope": "repo user"
}
```

**Scopes for Quick-Git:**
- `repo` - Full repository access (issues, commits, etc.)
- `user` - Read user profile
- `read:org` - (Optional) Read organization data

**Response (200 OK):**
```json
{
  "device_code": "3584d83530557fdd1f46af8289938c8ef79f9dc5",
  "user_code": "WDJB-MJHT",
  "verification_uri": "https://github.com/login/device",
  "expires_in": 900,
  "interval": 5
}
```

**Response Fields:**
| Field | Description |
|-------|-------------|
| `device_code` | 40-character verification code (for polling) |
| `user_code` | 8-character code for user to enter |
| `verification_uri` | URL where user enters code |
| `expires_in` | Seconds until codes expire (default: 900) |
| `interval` | Minimum seconds between poll requests |

### Step 2: Prompt User

Display to user:
```
Please visit: https://github.com/login/device
Enter code: WDJB-MJHT
```

Or open browser automatically:
```bash
xdg-open "https://github.com/login/device?user_code=WDJB-MJHT"
```

### Step 3: Poll for Authorization

**Endpoint:** `POST https://github.com/login/oauth/access_token`

**Headers:**
```
Accept: application/json
Content-Type: application/json
```

**Request Body:**
```json
{
  "client_id": "YOUR_CLIENT_ID",
  "device_code": "3584d83530557fdd1f46af8289938c8ef79f9dc5",
  "grant_type": "urn:ietf:params:oauth:grant-type:device_code"
}
```

**Poll at `interval` seconds until success or error.**

**Success Response (200 OK):**
```json
{
  "access_token": "gho_16C7e42F292c6912E7710c838347Ae178B4a",
  "token_type": "bearer",
  "scope": "repo,user"
}
```

**Error Responses:**

| Error | Meaning | Action |
|-------|---------|--------|
| `authorization_pending` | User hasn't entered code | Keep polling |
| `slow_down` | Too many requests | Add 5s to interval |
| `expired_token` | Codes expired | Restart flow |
| `access_denied` | User cancelled | Show error |
| `incorrect_client_credentials` | Invalid client_id | Check configuration |
| `incorrect_device_code` | Invalid device_code | Restart flow |
| `device_flow_disabled` | Not enabled in app settings | Enable in GitHub |

**Error Response Example:**
```json
{
  "error": "authorization_pending",
  "error_description": "The authorization request is still pending."
}
```

### Rate Limits

- 50 verification submissions per hour per application
- Respect `interval` between polls
- `slow_down` error adds 5 seconds to required interval

### Implementation Example (QML/JavaScript)

```qml
import QtQuick
import Quickshell.Io

Item {
    id: auth

    property string accessToken: ""
    property bool isAuthenticated: accessToken !== ""

    signal authenticationComplete(string token)
    signal authenticationFailed(string error)

    property string deviceCode: ""
    property int pollInterval: 5

    function startAuth() {
        deviceCodeRequest.running = true
    }

    // Step 1: Request device code
    Process {
        id: deviceCodeRequest
        command: ["curl", "-s", "-X", "POST",
            "-H", "Accept: application/json",
            "-H", "Content-Type: application/json",
            "-d", JSON.stringify({
                client_id: "YOUR_CLIENT_ID",
                scope: "repo user"
            }),
            "https://github.com/login/device/code"
        ]

        stdout: StdioCollector {
            onCollected: text => {
                const response = JSON.parse(text)
                deviceCode = response.device_code
                pollInterval = response.interval

                // Show user the code
                showUserCode(response.user_code, response.verification_uri)

                // Start polling
                pollTimer.start()
            }
        }
    }

    // Step 3: Poll for token
    Timer {
        id: pollTimer
        interval: pollInterval * 1000
        repeat: true

        onTriggered: tokenRequest.running = true
    }

    Process {
        id: tokenRequest
        command: ["curl", "-s", "-X", "POST",
            "-H", "Accept: application/json",
            "-H", "Content-Type: application/json",
            "-d", JSON.stringify({
                client_id: "YOUR_CLIENT_ID",
                device_code: deviceCode,
                grant_type: "urn:ietf:params:oauth:grant-type:device_code"
            }),
            "https://github.com/login/oauth/access_token"
        ]

        stdout: StdioCollector {
            onCollected: text => {
                const response = JSON.parse(text)

                if (response.access_token) {
                    pollTimer.stop()
                    accessToken = response.access_token
                    authenticationComplete(accessToken)
                } else if (response.error === "slow_down") {
                    pollInterval += 5
                    pollTimer.interval = pollInterval * 1000
                } else if (response.error !== "authorization_pending") {
                    pollTimer.stop()
                    authenticationFailed(response.error_description)
                }
            }
        }
    }
}
```

## Issues API

### List Repository Issues

**Endpoint:** `GET /repos/{owner}/{repo}/issues`

**Headers:**
```
Authorization: Bearer {token}
Accept: application/vnd.github+json
X-GitHub-Api-Version: 2022-11-28
```

**Query Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `state` | string | `open`, `closed`, or `all` (default: `open`) |
| `labels` | string | Comma-separated label names |
| `sort` | string | `created`, `updated`, `comments` |
| `direction` | string | `asc` or `desc` |
| `since` | string | ISO 8601 timestamp |
| `per_page` | int | Results per page (max 100, default 30) |
| `page` | int | Page number |

**Response (200 OK):**
```json
[
  {
    "id": 1,
    "node_id": "MDU6SXNzdWUx",
    "number": 1347,
    "title": "Found a bug",
    "body": "I'm having a problem with this.",
    "state": "open",
    "state_reason": null,
    "locked": false,
    "user": {
      "login": "octocat",
      "id": 1,
      "avatar_url": "https://github.com/images/error/octocat_happy.gif"
    },
    "labels": [
      {
        "id": 208045946,
        "name": "bug",
        "color": "f29513"
      }
    ],
    "assignees": [],
    "milestone": null,
    "comments": 0,
    "created_at": "2011-04-22T13:33:48Z",
    "updated_at": "2011-04-22T13:33:48Z",
    "closed_at": null,
    "html_url": "https://github.com/octocat/Hello-World/issues/1347"
  }
]
```

### Get Single Issue

**Endpoint:** `GET /repos/{owner}/{repo}/issues/{issue_number}`

**Response:** Same as list item above.

### Create Issue

**Endpoint:** `POST /repos/{owner}/{repo}/issues`

**Request Body:**
```json
{
  "title": "Found a bug",
  "body": "I'm having a problem with this.",
  "assignees": ["octocat"],
  "labels": ["bug"],
  "milestone": 1
}
```

**Required:** `title`

**Response (201 Created):** Full issue object.

### Update Issue

**Endpoint:** `PATCH /repos/{owner}/{repo}/issues/{issue_number}`

**Request Body:**
```json
{
  "title": "Updated title",
  "body": "Updated description",
  "state": "closed",
  "state_reason": "completed",
  "labels": ["bug", "wontfix"],
  "assignees": ["octocat"]
}
```

**State Reasons:** `completed`, `not_planned`, `reopened`

**Response (200 OK):** Updated issue object.

### Lock/Unlock Issue

**Lock:** `PUT /repos/{owner}/{repo}/issues/{issue_number}/lock`
```json
{
  "lock_reason": "resolved"
}
```

Lock reasons: `off-topic`, `too heated`, `resolved`, `spam`

**Unlock:** `DELETE /repos/{owner}/{repo}/issues/{issue_number}/lock`

## Issue Comments API

### List Comments on Issue

**Endpoint:** `GET /repos/{owner}/{repo}/issues/{issue_number}/comments`

**Query Parameters:**
- `since` - ISO 8601 timestamp
- `per_page` - Results per page
- `page` - Page number

**Response (200 OK):**
```json
[
  {
    "id": 1,
    "node_id": "MDEyOklzc3VlQ29tbWVudDE=",
    "body": "Me too",
    "user": {
      "login": "octocat",
      "id": 1,
      "avatar_url": "https://github.com/images/error/octocat_happy.gif"
    },
    "created_at": "2011-04-14T16:00:49Z",
    "updated_at": "2011-04-14T16:00:49Z",
    "html_url": "https://github.com/octocat/Hello-World/issues/1347#issuecomment-1",
    "author_association": "COLLABORATOR"
  }
]
```

### Create Comment

**Endpoint:** `POST /repos/{owner}/{repo}/issues/{issue_number}/comments`

**Request Body:**
```json
{
  "body": "This is a comment"
}
```

**Response (201 Created):** Comment object.

### Update Comment

**Endpoint:** `PATCH /repos/{owner}/{repo}/issues/comments/{comment_id}`

**Request Body:**
```json
{
  "body": "Updated comment"
}
```

### Delete Comment

**Endpoint:** `DELETE /repos/{owner}/{repo}/issues/comments/{comment_id}`

**Response:** 204 No Content

## Repository Contents API

### Get Repository Content

**Endpoint:** `GET /repos/{owner}/{repo}/contents/{path}`

**Query Parameters:**
- `ref` - Branch, tag, or commit SHA

**Response (File - 200 OK):**
```json
{
  "type": "file",
  "name": "README.md",
  "path": "README.md",
  "sha": "abc123...",
  "size": 1234,
  "encoding": "base64",
  "content": "IyBIZWxsbyBXb3JsZA==...",
  "html_url": "https://github.com/...",
  "download_url": "https://raw.githubusercontent.com/..."
}
```

**Response (Directory - 200 OK):**
```json
[
  {
    "type": "file",
    "name": "README.md",
    "path": "README.md",
    "sha": "abc123...",
    "size": 1234
  },
  {
    "type": "dir",
    "name": "src",
    "path": "src",
    "sha": "def456..."
  }
]
```

**Limits:**
- Max 1,000 files per directory
- Files > 100 MB: Use Git LFS
- Files 1-100 MB: Use raw media type

### Create/Update File

**Endpoint:** `PUT /repos/{owner}/{repo}/contents/{path}`

**Request Body (Create):**
```json
{
  "message": "Create README",
  "content": "IyBIZWxsbyBXb3JsZA==",
  "branch": "main"
}
```

**Request Body (Update):**
```json
{
  "message": "Update README",
  "content": "IyBVcGRhdGVkIENvbnRlbnQ=",
  "sha": "abc123...",
  "branch": "main"
}
```

Content must be Base64 encoded. `sha` required for updates.

### Delete File

**Endpoint:** `DELETE /repos/{owner}/{repo}/contents/{path}`

**Request Body:**
```json
{
  "message": "Delete file",
  "sha": "abc123...",
  "branch": "main"
}
```

## Git Database API

For advanced Git operations (creating commits, trees, etc.).

### Get Reference

**Endpoint:** `GET /repos/{owner}/{repo}/git/ref/{ref}`

Ref format: `heads/{branch}` or `tags/{tag}`

**Response:**
```json
{
  "ref": "refs/heads/main",
  "node_id": "...",
  "object": {
    "sha": "abc123...",
    "type": "commit"
  }
}
```

### Get Commit

**Endpoint:** `GET /repos/{owner}/{repo}/git/commits/{commit_sha}`

**Response:**
```json
{
  "sha": "abc123...",
  "message": "Commit message",
  "author": {
    "name": "Author Name",
    "email": "author@example.com",
    "date": "2024-01-15T10:00:00Z"
  },
  "committer": {
    "name": "Committer Name",
    "email": "committer@example.com",
    "date": "2024-01-15T10:00:00Z"
  },
  "tree": {
    "sha": "tree123..."
  },
  "parents": [
    {
      "sha": "parent123..."
    }
  ]
}
```

### Create Blob

**Endpoint:** `POST /repos/{owner}/{repo}/git/blobs`

**Request Body:**
```json
{
  "content": "Content goes here",
  "encoding": "utf-8"
}
```

Or Base64:
```json
{
  "content": "Q29udGVudCBnb2VzIGhlcmU=",
  "encoding": "base64"
}
```

### Create Tree

**Endpoint:** `POST /repos/{owner}/{repo}/git/trees`

**Request Body:**
```json
{
  "base_tree": "base_tree_sha",
  "tree": [
    {
      "path": "file.txt",
      "mode": "100644",
      "type": "blob",
      "sha": "blob_sha"
    }
  ]
}
```

Modes:
- `100644` - File (blob)
- `100755` - Executable (blob)
- `040000` - Subdirectory (tree)
- `160000` - Submodule (commit)
- `120000` - Symlink (blob)

### Create Commit

**Endpoint:** `POST /repos/{owner}/{repo}/git/commits`

**Request Body:**
```json
{
  "message": "Commit message",
  "tree": "tree_sha",
  "parents": ["parent_sha"],
  "author": {
    "name": "Author Name",
    "email": "author@example.com",
    "date": "2024-01-15T10:00:00Z"
  }
}
```

### Update Reference

**Endpoint:** `PATCH /repos/{owner}/{repo}/git/refs/{ref}`

**Request Body:**
```json
{
  "sha": "new_commit_sha",
  "force": false
}
```

## Media Types

Request different response formats:

| Accept Header | Response Format |
|---------------|-----------------|
| `application/vnd.github+json` | Standard JSON |
| `application/vnd.github.raw+json` | Raw markdown in `body` |
| `application/vnd.github.text+json` | Plain text in `body_text` |
| `application/vnd.github.html+json` | HTML in `body_html` |
| `application/vnd.github.full+json` | All formats |

## Rate Limits

**Authenticated Requests:**
- 5,000 requests/hour (standard)
- 15,000 requests/hour (GitHub Enterprise)

**Check Rate Limit:**
```
GET /rate_limit
```

**Response Headers:**
```
X-RateLimit-Limit: 5000
X-RateLimit-Remaining: 4999
X-RateLimit-Reset: 1372700873
X-RateLimit-Used: 1
```

## Pagination

**Query Parameters:**
- `per_page` - Results per page (max 100, default 30)
- `page` - Page number (1-indexed)

**Link Header:**
```
Link: <https://api.github.com/...?page=2>; rel="next",
      <https://api.github.com/...?page=5>; rel="last"
```

## Error Handling

**Common Error Responses:**

| Status | Meaning |
|--------|---------|
| 400 | Bad Request |
| 401 | Unauthorized (invalid/missing token) |
| 403 | Forbidden (rate limited or insufficient permissions) |
| 404 | Not Found |
| 422 | Validation Failed |
| 503 | Service Unavailable |

**Error Response Format:**
```json
{
  "message": "Validation Failed",
  "errors": [
    {
      "resource": "Issue",
      "field": "title",
      "code": "missing_field"
    }
  ],
  "documentation_url": "https://docs.github.com/..."
}
```

## Quick-Git Implementation Notes

### Required Scopes

For full functionality:
- `repo` - Repository access (issues, contents, commits)
- `user` - User profile for displaying author info

### Recommended Endpoints

1. **Status Bar Widget:**
   - `GET /user` - Current user info
   - `GET /notifications` - Unread notifications count

2. **Issues Panel:**
   - `GET /repos/{owner}/{repo}/issues` - List issues
   - `POST /repos/{owner}/{repo}/issues` - Create issue
   - `PATCH /repos/{owner}/{repo}/issues/{number}` - Update issue
   - `GET /repos/{owner}/{repo}/issues/{number}/comments` - List comments
   - `POST /repos/{owner}/{repo}/issues/{number}/comments` - Add comment

3. **Repository Info:**
   - `GET /repos/{owner}/{repo}` - Repository details
   - `GET /repos/{owner}/{repo}/branches` - List branches
   - `GET /repos/{owner}/{repo}/commits` - Commit history

### Token Storage

Store OAuth token securely:
```qml
// In Settings.qml - mark as secure
manifest.settings.githubToken = token
saveSettings()
```

Consider using system keyring for production.

## References

- [GitHub REST API Documentation](https://docs.github.com/en/rest)
- [OAuth Device Flow](https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps#device-flow)
- [Issues API](https://docs.github.com/en/rest/issues)
- [Issue Comments API](https://docs.github.com/en/rest/issues/comments)
- [Repository Contents API](https://docs.github.com/en/rest/repos/contents)
- [Git Database API](https://docs.github.com/en/rest/git)
- [Rate Limiting](https://docs.github.com/en/rest/overview/rate-limits-for-the-rest-api)
