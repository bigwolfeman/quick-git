/**
 * GitHubService.qml - GitHub API Operations Singleton
 *
 * Manages GitHub OAuth Device Flow authentication and API operations.
 * Uses curl via Quickshell.Io.Process for HTTP requests and secret-tool
 * (libsecret) for secure token storage in the system keyring.
 *
 * Tasks Implemented:
 * - T040: Singleton skeleton with auth state properties
 * - T041: startAuth() - POST to /login/device/code
 * - T042: Polling Timer for token retrieval
 * - T043: Token storage using secret-tool (libsecret)
 * - T044: loadStoredToken() on startup
 * - T045: logout() to clear token from keyring
 * - T051: listIssues() - GET /repos/{owner}/{repo}/issues
 * - T055: getIssue() - GET issue with comments
 * - T057: addComment() - POST comment to issue
 * - T060: createIssue() - POST new issue with title, body, labels
 * - T061: closeIssue()/reopenIssue() - PATCH issue state
 *
 * OAuth Device Flow:
 * 1. POST https://github.com/login/device/code -> device_code, user_code
 * 2. User visits verification_uri and enters user_code
 * 3. Poll https://github.com/login/oauth/access_token at interval
 * 4. On success, validate token via /user endpoint
 * 5. Store token in system keyring via secret-tool
 *
 * GitHub Issues API:
 * - All requests include headers for rate limit tracking
 * - Responses parsed for errors and rate limit info
 * - Pull requests filtered from issue listings
 * - Comments fetched separately and attached to issue data
 *
 * @see specs/001-quick-git-plugin/contracts/github-service.md
 * @see docs/github-api.md
 */
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: gitHubService

    // =========================================================================
    // CONFIGURATION
    // =========================================================================

    /**
     * GitHub OAuth App Client ID
     * Users must register their own OAuth App at:
     * https://github.com/settings/developers
     *
     * Settings for OAuth App:
     * - Application name: Quick-Git Noctalia
     * - Homepage URL: https://github.com/your-username/quick-git
     * - Device Flow: Enabled
     * - Callback URL: (not needed for Device Flow)
     */
    readonly property string clientId: "GITHUB_CLIENT_ID"

    /**
     * OAuth scopes requested
     * - repo: Full repository access (issues, commits, etc.)
     * - user: Read user profile
     */
    readonly property string scopes: "repo user"

    /**
     * User-Agent for API requests
     */
    readonly property string userAgent: "Quick-Git-Noctalia/1.0"

    /**
     * GitHub API version header
     */
    readonly property string apiVersion: "2022-11-28"

    /**
     * Base URL for GitHub API
     */
    readonly property string apiBaseUrl: "https://api.github.com"

    // =========================================================================
    // REACTIVE PROPERTIES (T040)
    // =========================================================================

    /** User is logged in with valid token */
    property bool isAuthenticated: false

    /** Authenticated user's GitHub login */
    property string username: ""

    /** User's avatar image URL */
    property string avatarUrl: ""

    /**
     * Current authentication state
     * Values: "idle" | "awaiting_code" | "polling" | "authenticated" | "error"
     */
    property string authState: "idle"

    /** Current device code during auth flow (internal use) */
    property string deviceCode: ""

    /** User code to enter on GitHub */
    property string userCode: ""

    /** URL for user to visit (https://github.com/login/device) */
    property string verificationUrl: ""

    /** Last error message */
    property string error: ""

    /** API request in progress */
    property bool isLoading: false

    /** Remaining API requests before rate limit */
    property int rateLimitRemaining: 5000

    /** Timestamp when rate limit resets (epoch seconds) */
    property real rateLimitReset: 0

    // =========================================================================
    // PRIVATE STATE
    // =========================================================================

    /** Stored access token (kept in memory after retrieval from keyring) */
    property string _accessToken: ""

    /** Polling interval in seconds (from device code response) */
    property int _pollInterval: 5

    /** Device code expiration time (epoch ms) */
    property real _codeExpiresAt: 0

    /** Flag to track if we're currently storing a token */
    property bool _storingToken: false

    /** Pending API callback storage */
    property var _pendingCallbacks: ({})

    // =========================================================================
    // SIGNALS
    // =========================================================================

    /** Emitted when authentication state changes */
    signal authStateChanged(string state)

    /** Emitted when successfully authenticated */
    signal authenticated(string username)

    /** Emitted when authentication fails */
    signal authFailed(string error)

    /** Emitted when issues list is loaded */
    signal issuesLoaded(var issues)

    /** Emitted when an issue is created or updated */
    signal issueUpdated(var issue)

    /** Emitted when a comment is added */
    signal commentAdded(var comment)

    /** Emitted when any API error occurs */
    signal errorOccurred(string message)

    /** Emitted when rate limit is hit */
    signal rateLimited(real reset)

    /** Emitted when a single issue is loaded (with comments) */
    signal issueLoaded(var issue)

    /** Emitted when comments are loaded for an issue */
    signal commentsLoaded(int issueNumber, var comments)

    // =========================================================================
    // AUTHENTICATION METHODS
    // =========================================================================

    /**
     * Begin OAuth Device Flow authentication (T041)
     *
     * Requests a device code from GitHub, then prompts user to visit
     * verification URL and enter the user code. Starts polling for
     * authorization.
     *
     * State transitions: idle -> awaiting_code -> polling -> authenticated
     *                                        \-> error
     */
    function startAuth() {
        if (authState !== "idle" && authState !== "error") {
            console.log("[GitHubService] Auth already in progress, state:", authState)
            return
        }

        console.log("[GitHubService] Starting OAuth Device Flow authentication")

        // Reset state
        error = ""
        deviceCode = ""
        userCode = ""
        verificationUrl = ""
        _accessToken = ""

        _setAuthState("awaiting_code")
        isLoading = true

        // Build request body
        deviceCodeProcess._requestBody = JSON.stringify({
            client_id: clientId,
            scope: scopes
        })

        // Start device code request
        deviceCodeProcess.running = true
    }

    /**
     * Cancel in-progress authentication
     *
     * Stops polling timer, clears device code, resets state to idle
     */
    function cancelAuth() {
        console.log("[GitHubService] Cancelling authentication")

        pollTimer.stop()
        deviceCode = ""
        userCode = ""
        verificationUrl = ""
        error = ""
        isLoading = false

        _setAuthState("idle")
    }

    /**
     * Disconnect from GitHub (T045)
     *
     * Clears token from keyring, resets all auth state
     */
    function logout() {
        console.log("[GitHubService] Logging out")

        pollTimer.stop()

        // Clear token from keyring
        tokenClearProcess.running = true

        // Reset all state
        _accessToken = ""
        isAuthenticated = false
        username = ""
        avatarUrl = ""
        deviceCode = ""
        userCode = ""
        verificationUrl = ""
        error = ""

        _setAuthState("idle")
    }

    /**
     * Load stored token from keyring on startup (T044)
     *
     * Retrieves token from secret-tool and validates it by calling /user
     * Returns true if token retrieval was started (actual result comes async)
     */
    function loadStoredToken() {
        console.log("[GitHubService] Loading stored token from keyring")
        isLoading = true
        tokenLoadProcess.running = true
        return true
    }

    // =========================================================================
    // GITHUB ISSUES API METHODS (Phase 7)
    // =========================================================================

    /**
     * Fetch issues for a repository (T051)
     *
     * @param owner - Repository owner
     * @param repo - Repository name
     * @param options - { state?: 'open'|'closed'|'all', page?: number, perPage?: number }
     *
     * Emits: issuesLoaded(issues) on success
     *        errorOccurred(message) on failure
     */
    function listIssues(owner, repo, options) {
        if (!isAuthenticated) {
            console.warn("[GitHubService] Not authenticated - cannot list issues")
            errorOccurred("Not authenticated")
            return
        }

        options = options || {}
        const state = options.state || "open"
        const page = options.page || 1
        const perPage = options.perPage || 30

        console.log("[GitHubService] listIssues:", owner + "/" + repo,
                   "state:", state, "page:", page, "perPage:", perPage)

        // Configure and start the process
        listIssuesProcess.owner = owner
        listIssuesProcess.repo = repo
        listIssuesProcess.state = state
        listIssuesProcess.page = page
        listIssuesProcess.perPage = perPage

        isLoading = true
        listIssuesProcess.running = true
    }

    /**
     * Fetch a single issue with comments (T055)
     *
     * @param owner - Repository owner
     * @param repo - Repository name
     * @param number - Issue number
     * @param options - { includeComments?: boolean } (default: true)
     *
     * Emits: issueLoaded(issue) on success (issue.comments is array if includeComments)
     *        errorOccurred(message) on failure
     */
    function getIssue(owner, repo, number, options) {
        if (!isAuthenticated) {
            console.warn("[GitHubService] Not authenticated - cannot get issue")
            errorOccurred("Not authenticated")
            return
        }

        options = options || {}
        const includeComments = options.includeComments !== false

        console.log("[GitHubService] getIssue:", owner + "/" + repo + "#" + number,
                   "includeComments:", includeComments)

        // Configure and start the process
        getIssueProcess.owner = owner
        getIssueProcess.repo = repo
        getIssueProcess.issueNumber = number
        getIssueProcess.includeComments = includeComments

        isLoading = true
        getIssueProcess.running = true
    }

    /**
     * Create a new issue (T060)
     *
     * @param owner - Repository owner
     * @param repo - Repository name
     * @param title - Issue title (required)
     * @param body - Issue body markdown (optional)
     * @param labels - Array of label names (optional)
     *
     * Emits: issueUpdated(issue) on success
     *        errorOccurred(message) on failure
     */
    function createIssue(owner, repo, title, body, labels) {
        if (!isAuthenticated) {
            console.warn("[GitHubService] Not authenticated - cannot create issue")
            errorOccurred("Not authenticated")
            return
        }

        if (!title || title.trim().length === 0) {
            console.error("[GitHubService] createIssue: title is required")
            errorOccurred("Issue title is required")
            return
        }

        console.log("[GitHubService] createIssue:", owner + "/" + repo, "title:", title)

        // Build request body
        let requestBody = { title: title.trim() }
        if (body && body.trim().length > 0) {
            requestBody.body = body.trim()
        }
        if (labels && Array.isArray(labels) && labels.length > 0) {
            requestBody.labels = labels
        }

        // Configure and start the process
        createIssueProcess.owner = owner
        createIssueProcess.repo = repo
        createIssueProcess._requestBody = JSON.stringify(requestBody)

        isLoading = true
        createIssueProcess.running = true
    }

    /**
     * Update an existing issue
     *
     * @param owner - Repository owner
     * @param repo - Repository name
     * @param number - Issue number
     * @param updates - { title?, body?, state?, state_reason?, labels? }
     *
     * Emits: issueUpdated(issue) on success
     *        errorOccurred(message) on failure
     */
    function updateIssue(owner, repo, number, updates) {
        if (!isAuthenticated) {
            console.warn("[GitHubService] Not authenticated - cannot update issue")
            errorOccurred("Not authenticated")
            return
        }

        if (!updates || Object.keys(updates).length === 0) {
            console.error("[GitHubService] updateIssue: no updates provided")
            errorOccurred("No updates provided")
            return
        }

        console.log("[GitHubService] updateIssue:", owner + "/" + repo + "#" + number)

        // Build request body from provided updates
        const requestBody = JSON.stringify(updates)

        // Configure and start the process
        updateIssueProcess.owner = owner
        updateIssueProcess.repo = repo
        updateIssueProcess.issueNumber = number
        updateIssueProcess._requestBody = requestBody

        isLoading = true
        updateIssueProcess.running = true
    }

    /**
     * Close an issue (T061)
     *
     * @param owner - Repository owner
     * @param repo - Repository name
     * @param number - Issue number
     * @param reason - 'completed' | 'not_planned' (default: 'completed')
     *
     * Emits: issueUpdated(issue) on success
     *        errorOccurred(message) on failure
     */
    function closeIssue(owner, repo, number, reason) {
        if (!isAuthenticated) {
            console.warn("[GitHubService] Not authenticated - cannot close issue")
            errorOccurred("Not authenticated")
            return
        }

        reason = reason || "completed"
        console.log("[GitHubService] closeIssue:", owner + "/" + repo + "#" + number,
                   "reason:", reason)

        // Build request body for closing
        const requestBody = JSON.stringify({
            state: "closed",
            state_reason: reason
        })

        // Configure and start the process
        updateIssueProcess.owner = owner
        updateIssueProcess.repo = repo
        updateIssueProcess.issueNumber = number
        updateIssueProcess._requestBody = requestBody

        isLoading = true
        updateIssueProcess.running = true
    }

    /**
     * Reopen a closed issue (T061)
     *
     * @param owner - Repository owner
     * @param repo - Repository name
     * @param number - Issue number
     *
     * Emits: issueUpdated(issue) on success
     *        errorOccurred(message) on failure
     */
    function reopenIssue(owner, repo, number) {
        if (!isAuthenticated) {
            console.warn("[GitHubService] Not authenticated - cannot reopen issue")
            errorOccurred("Not authenticated")
            return
        }

        console.log("[GitHubService] reopenIssue:", owner + "/" + repo + "#" + number)

        // Build request body for reopening
        const requestBody = JSON.stringify({
            state: "open",
            state_reason: "reopened"
        })

        // Configure and start the process
        updateIssueProcess.owner = owner
        updateIssueProcess.repo = repo
        updateIssueProcess.issueNumber = number
        updateIssueProcess._requestBody = requestBody

        isLoading = true
        updateIssueProcess.running = true
    }

    /**
     * Add a comment to an issue (T057)
     *
     * @param owner - Repository owner
     * @param repo - Repository name
     * @param number - Issue number
     * @param body - Comment body (markdown)
     *
     * Emits: commentAdded(comment) on success
     *        errorOccurred(message) on failure
     */
    function addComment(owner, repo, number, body) {
        if (!isAuthenticated) {
            console.warn("[GitHubService] Not authenticated - cannot add comment")
            errorOccurred("Not authenticated")
            return
        }

        if (!body || body.trim().length === 0) {
            console.error("[GitHubService] addComment: body is required")
            errorOccurred("Comment body is required")
            return
        }

        console.log("[GitHubService] addComment:", owner + "/" + repo + "#" + number)

        // Build request body
        const requestBody = JSON.stringify({
            body: body.trim()
        })

        // Configure and start the process
        addCommentProcess.owner = owner
        addCommentProcess.repo = repo
        addCommentProcess.issueNumber = number
        addCommentProcess._requestBody = requestBody

        isLoading = true
        addCommentProcess.running = true
    }

    /**
     * Get comments for an issue
     *
     * @param owner - Repository owner
     * @param repo - Repository name
     * @param number - Issue number
     * @param options - { page?: number, perPage?: number } (pagination not yet implemented)
     *
     * Emits: commentsLoaded(issueNumber, comments) on success
     *        errorOccurred(message) on failure
     */
    function getComments(owner, repo, number, options) {
        if (!isAuthenticated) {
            console.warn("[GitHubService] Not authenticated - cannot get comments")
            errorOccurred("Not authenticated")
            return
        }

        console.log("[GitHubService] getComments:", owner + "/" + repo + "#" + number)

        // Configure and start the process (without parent issue - standalone request)
        getCommentsProcess.owner = owner
        getCommentsProcess.repo = repo
        getCommentsProcess.issueNumber = number
        getCommentsProcess._parentIssue = null

        isLoading = true
        getCommentsProcess.running = true
    }

    // =========================================================================
    // HELPER METHODS
    // =========================================================================

    /**
     * Set auth state and emit signal
     * @param state - New auth state
     */
    function _setAuthState(state) {
        if (authState !== state) {
            authState = state
            console.log("[GitHubService] Auth state:", state)
            authStateChanged(state)
        }
    }

    /**
     * Handle successful token retrieval
     * @param token - Access token
     */
    function _handleTokenReceived(token) {
        console.log("[GitHubService] Token received, validating...")

        _accessToken = token
        pollTimer.stop()

        // Validate token by fetching user info
        _validateToken()
    }

    /**
     * Validate token by fetching user info from /user endpoint
     */
    function _validateToken() {
        isLoading = true
        userValidateProcess.running = true
    }

    /**
     * Handle successful user validation
     * @param userData - User object from /user endpoint
     */
    function _handleUserValidated(userData) {
        username = userData.login || ""
        avatarUrl = userData.avatar_url || ""
        isAuthenticated = true
        isLoading = false

        console.log("[GitHubService] Authenticated as:", username)

        _setAuthState("authenticated")
        authenticated(username)

        // Store token in keyring if not already stored
        if (!_storingToken && deviceCode !== "") {
            _storeToken(_accessToken)
        }

        // Clear device code data
        deviceCode = ""
        userCode = ""
        verificationUrl = ""
    }

    /**
     * Store token in system keyring via secret-tool (T043)
     * @param token - Access token to store
     */
    function _storeToken(token) {
        console.log("[GitHubService] Storing token in keyring")
        _storingToken = true

        // secret-tool store reads from stdin
        tokenStoreProcess._token = token
        tokenStoreProcess.running = true
    }

    /**
     * Handle auth error
     * @param message - Error message
     */
    function _handleAuthError(message) {
        console.error("[GitHubService] Auth error:", message)

        pollTimer.stop()
        error = message
        isLoading = false

        _setAuthState("error")
        authFailed(message)
    }

    /**
     * Parse rate limit headers from response
     * @param text - Response body (we check headers in stderr for curl -i)
     */
    function _parseRateLimitHeaders(headers) {
        // Headers come from curl -D- output
        const remainingMatch = headers.match(/x-ratelimit-remaining:\s*(\d+)/i)
        const resetMatch = headers.match(/x-ratelimit-reset:\s*(\d+)/i)

        if (remainingMatch) {
            rateLimitRemaining = parseInt(remainingMatch[1], 10)
        }
        if (resetMatch) {
            rateLimitReset = parseInt(resetMatch[1], 10)
        }
    }

    /**
     * Build curl command array for authenticated API request
     * @param method - HTTP method
     * @param url - Full URL
     * @param body - Request body (optional)
     * @param includeHeaders - Include response headers in output (default: false)
     */
    function _buildCurlCommand(method, url, body, includeHeaders) {
        let cmd = [
            "curl", "-s",
            "-X", method,
            "-H", "Accept: application/vnd.github+json",
            "-H", "X-GitHub-Api-Version: " + apiVersion,
            "-H", "User-Agent: " + userAgent
        ]

        // Include headers in output for rate limit tracking
        if (includeHeaders) {
            cmd.splice(2, 0, "-i")  // Insert -i after curl -s
        }

        if (_accessToken) {
            cmd.push("-H", "Authorization: Bearer " + _accessToken)
        }

        if (body) {
            cmd.push("-H", "Content-Type: application/json")
            cmd.push("-d", body)
        }

        cmd.push(url)
        return cmd
    }

    /**
     * Parse HTTP response with headers (from curl -i output)
     * Separates headers from body and extracts rate limit info
     * @param responseText - Raw curl output with headers
     * @returns { headers: string, body: string, statusCode: number }
     */
    function _parseHttpResponse(responseText) {
        // curl -i output format: headers\r\n\r\nbody
        // Headers end with empty line
        const headerEndIndex = responseText.indexOf("\r\n\r\n")
        if (headerEndIndex === -1) {
            // Try Unix line endings
            const unixIndex = responseText.indexOf("\n\n")
            if (unixIndex === -1) {
                return { headers: "", body: responseText, statusCode: 0 }
            }
            const headers = responseText.substring(0, unixIndex)
            const body = responseText.substring(unixIndex + 2)
            return {
                headers: headers,
                body: body,
                statusCode: _extractStatusCode(headers)
            }
        }

        const headers = responseText.substring(0, headerEndIndex)
        const body = responseText.substring(headerEndIndex + 4)

        return {
            headers: headers,
            body: body,
            statusCode: _extractStatusCode(headers)
        }
    }

    /**
     * Extract HTTP status code from headers
     * @param headers - HTTP headers string
     */
    function _extractStatusCode(headers) {
        // First line is like: HTTP/1.1 200 OK or HTTP/2 200
        const match = headers.match(/^HTTP\/[\d.]+\s+(\d+)/)
        return match ? parseInt(match[1], 10) : 0
    }

    /**
     * Handle API response and check for errors
     * @param responseText - Raw response (with or without headers)
     * @param includeHeaders - Whether response includes headers
     * @returns { success: boolean, data: object|null, error: string|null }
     */
    function _handleApiResponse(responseText, includeHeaders) {
        let body = responseText
        let statusCode = 200

        if (includeHeaders) {
            const parsed = _parseHttpResponse(responseText)
            body = parsed.body
            statusCode = parsed.statusCode

            // Update rate limit from headers
            _parseRateLimitHeaders(parsed.headers)
        }

        // Parse JSON body
        let data
        try {
            data = JSON.parse(body)
        } catch (e) {
            return { success: false, data: null, error: "Invalid JSON response" }
        }

        // Check for error responses
        if (data.message) {
            // GitHub API error format
            if (statusCode === 401 || data.message.includes("Bad credentials")) {
                return { success: false, data: null, error: "Authentication failed - please log in again" }
            }
            if (statusCode === 403 && data.message.includes("rate limit")) {
                rateLimited(rateLimitReset)
                return { success: false, data: null, error: "Rate limit exceeded" }
            }
            if (statusCode === 404) {
                return { success: false, data: null, error: "Not found: " + data.message }
            }
            if (statusCode >= 400) {
                return { success: false, data: null, error: data.message }
            }
        }

        return { success: true, data: data, error: null }
    }

    // =========================================================================
    // PROCESSES
    // =========================================================================

    /**
     * Process: Request device code (T041)
     * POST https://github.com/login/device/code
     */
    Process {
        id: deviceCodeProcess
        running: false

        property string _requestBody: ""
        property string stdoutText: ""
        property string stderrText: ""

        command: ["curl", "-s", "-X", "POST",
            "-H", "Accept: application/json",
            "-H", "Content-Type: application/json",
            "-d", _requestBody,
            "https://github.com/login/device/code"
        ]

        stdout: StdioCollector {
            onCollected: text => {
                deviceCodeProcess.stdoutText = text
            }
        }

        stderr: StdioCollector {
            onCollected: text => {
                deviceCodeProcess.stderrText = text
            }
        }

        onExited: (exitCode, exitStatus) => {
            isLoading = false

            if (exitCode !== 0) {
                _handleAuthError("Network error - check connection")
                return
            }

            let response
            try {
                response = JSON.parse(stdoutText)
            } catch (e) {
                _handleAuthError("Invalid response from GitHub")
                return
            }

            if (response.error) {
                _handleAuthError(response.error_description || response.error)
                return
            }

            // Extract response fields
            deviceCode = response.device_code || ""
            userCode = response.user_code || ""
            verificationUrl = response.verification_uri || "https://github.com/login/device"
            _pollInterval = response.interval || 5
            _codeExpiresAt = Date.now() + (response.expires_in || 900) * 1000

            console.log("[GitHubService] Device code received")
            console.log("[GitHubService] User code:", userCode)
            console.log("[GitHubService] Verification URL:", verificationUrl)
            console.log("[GitHubService] Poll interval:", _pollInterval, "seconds")

            // Transition to polling state
            _setAuthState("polling")

            // Start polling timer
            pollTimer.interval = _pollInterval * 1000
            pollTimer.start()

            // Clean up
            stdoutText = ""
            stderrText = ""
            _requestBody = ""
        }
    }

    /**
     * Timer: Poll for authorization (T042)
     * Polls at the interval specified by GitHub
     */
    Timer {
        id: pollTimer
        interval: 5000
        repeat: true
        running: false

        onTriggered: {
            // Check if device code has expired
            if (Date.now() > _codeExpiresAt) {
                stop()
                _handleAuthError("Code expired - please try again")
                return
            }

            // Start token request
            tokenPollProcess.running = true
        }
    }

    /**
     * Process: Poll for access token (T042)
     * POST https://github.com/login/oauth/access_token
     */
    Process {
        id: tokenPollProcess
        running: false

        property string stdoutText: ""
        property string stderrText: ""

        command: ["curl", "-s", "-X", "POST",
            "-H", "Accept: application/json",
            "-H", "Content-Type: application/json",
            "-d", JSON.stringify({
                client_id: clientId,
                device_code: deviceCode,
                grant_type: "urn:ietf:params:oauth:grant-type:device_code"
            }),
            "https://github.com/login/oauth/access_token"
        ]

        stdout: StdioCollector {
            onCollected: text => {
                tokenPollProcess.stdoutText = text
            }
        }

        stderr: StdioCollector {
            onCollected: text => {
                tokenPollProcess.stderrText = text
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                console.warn("[GitHubService] Poll request failed, will retry")
                stdoutText = ""
                stderrText = ""
                return
            }

            let response
            try {
                response = JSON.parse(stdoutText)
            } catch (e) {
                console.warn("[GitHubService] Invalid poll response, will retry")
                stdoutText = ""
                stderrText = ""
                return
            }

            // Check for access token (success)
            if (response.access_token) {
                console.log("[GitHubService] Access token received!")
                _handleTokenReceived(response.access_token)
                stdoutText = ""
                stderrText = ""
                return
            }

            // Handle error responses
            if (response.error) {
                switch (response.error) {
                    case "authorization_pending":
                        // User hasn't entered code yet - keep polling
                        console.log("[GitHubService] Authorization pending...")
                        break

                    case "slow_down":
                        // Too many requests - increase interval
                        console.log("[GitHubService] Slow down requested")
                        _pollInterval += 5
                        pollTimer.interval = _pollInterval * 1000
                        break

                    case "expired_token":
                        _handleAuthError("Code expired - please try again")
                        break

                    case "access_denied":
                        _handleAuthError("Access denied by user")
                        break

                    case "incorrect_client_credentials":
                        _handleAuthError("Invalid client ID - check configuration")
                        break

                    case "incorrect_device_code":
                        _handleAuthError("Invalid device code - please restart")
                        break

                    case "device_flow_disabled":
                        _handleAuthError("Device flow not enabled for this OAuth app")
                        break

                    default:
                        _handleAuthError(response.error_description || response.error)
                        break
                }
            }

            stdoutText = ""
            stderrText = ""
        }
    }

    /**
     * Process: Validate token via /user endpoint
     * GET https://api.github.com/user
     */
    Process {
        id: userValidateProcess
        running: false

        property string stdoutText: ""
        property string stderrText: ""

        command: ["curl", "-s",
            "-H", "Accept: application/vnd.github+json",
            "-H", "X-GitHub-Api-Version: " + apiVersion,
            "-H", "User-Agent: " + userAgent,
            "-H", "Authorization: Bearer " + _accessToken,
            apiBaseUrl + "/user"
        ]

        stdout: StdioCollector {
            onCollected: text => {
                userValidateProcess.stdoutText = text
            }
        }

        stderr: StdioCollector {
            onCollected: text => {
                userValidateProcess.stderrText = text
            }
        }

        onExited: (exitCode, exitStatus) => {
            isLoading = false

            if (exitCode !== 0) {
                _handleAuthError("Network error validating token")
                _accessToken = ""
                stdoutText = ""
                stderrText = ""
                return
            }

            let response
            try {
                response = JSON.parse(stdoutText)
            } catch (e) {
                _handleAuthError("Invalid response from GitHub API")
                _accessToken = ""
                stdoutText = ""
                stderrText = ""
                return
            }

            // Check for error response
            if (response.message) {
                if (response.message.includes("Bad credentials") ||
                    response.message.includes("Unauthorized")) {
                    _handleAuthError("Session expired - please log in again")
                    _accessToken = ""
                } else {
                    _handleAuthError(response.message)
                }
                stdoutText = ""
                stderrText = ""
                return
            }

            // Success - we have a valid user
            _handleUserValidated(response)

            stdoutText = ""
            stderrText = ""
        }
    }

    /**
     * Process: Load token from keyring (T044)
     * secret-tool lookup application quick-git type github-token
     */
    Process {
        id: tokenLoadProcess
        running: false

        property string stdoutText: ""
        property string stderrText: ""

        command: ["secret-tool", "lookup",
            "application", "quick-git",
            "type", "github-token"
        ]

        stdout: StdioCollector {
            onCollected: text => {
                tokenLoadProcess.stdoutText = text
            }
        }

        stderr: StdioCollector {
            onCollected: text => {
                tokenLoadProcess.stderrText = text
            }
        }

        onExited: (exitCode, exitStatus) => {
            const token = stdoutText.trim()
            stdoutText = ""
            stderrText = ""

            if (exitCode !== 0 || token.length === 0) {
                console.log("[GitHubService] No stored token found")
                isLoading = false
                return
            }

            console.log("[GitHubService] Found stored token, validating...")
            _accessToken = token
            _validateToken()
        }
    }

    /**
     * Process: Store token in keyring (T043)
     * echo -n TOKEN | secret-tool store --label="Quick-Git" application quick-git type github-token
     */
    Process {
        id: tokenStoreProcess
        running: false

        property string _token: ""
        property string stderrText: ""

        // Use bash to pipe the token to secret-tool
        command: ["bash", "-c",
            "echo -n '" + _token + "' | secret-tool store --label='Quick-Git GitHub Token' application quick-git type github-token"
        ]

        stderr: StdioCollector {
            onCollected: text => {
                tokenStoreProcess.stderrText = text
            }
        }

        onExited: (exitCode, exitStatus) => {
            _storingToken = false
            _token = ""

            if (exitCode === 0) {
                console.log("[GitHubService] Token stored in keyring")
            } else {
                console.error("[GitHubService] Failed to store token:", stderrText)
            }

            stderrText = ""
        }
    }

    /**
     * Process: Clear token from keyring (T045)
     * secret-tool clear application quick-git type github-token
     */
    Process {
        id: tokenClearProcess
        running: false

        property string stderrText: ""

        command: ["secret-tool", "clear",
            "application", "quick-git",
            "type", "github-token"
        ]

        stderr: StdioCollector {
            onCollected: text => {
                tokenClearProcess.stderrText = text
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                console.log("[GitHubService] Token cleared from keyring")
            } else {
                console.warn("[GitHubService] Failed to clear token (may not exist):", stderrText)
            }

            stderrText = ""
        }
    }

    // =========================================================================
    // GITHUB ISSUES API PROCESSES (Phase 7)
    // =========================================================================

    /**
     * Process: List Issues (T051)
     * GET /repos/{owner}/{repo}/issues
     */
    Process {
        id: listIssuesProcess
        running: false

        property string owner: ""
        property string repo: ""
        property string state: "open"
        property int page: 1
        property int perPage: 30
        property string stdoutText: ""
        property string stderrText: ""

        command: ["curl", "-s", "-i",
            "-H", "Accept: application/vnd.github+json",
            "-H", "X-GitHub-Api-Version: " + apiVersion,
            "-H", "User-Agent: " + userAgent,
            "-H", "Authorization: Bearer " + _accessToken,
            apiBaseUrl + "/repos/" + owner + "/" + repo + "/issues" +
                "?state=" + state +
                "&page=" + page +
                "&per_page=" + perPage
        ]

        stdout: StdioCollector {
            onCollected: text => {
                listIssuesProcess.stdoutText = text
            }
        }

        stderr: StdioCollector {
            onCollected: text => {
                listIssuesProcess.stderrText = text
            }
        }

        onExited: (exitCode, exitStatus) => {
            isLoading = false

            if (exitCode !== 0) {
                console.error("[GitHubService] listIssues network error")
                errorOccurred("Network error - check connection")
                stdoutText = ""
                stderrText = ""
                return
            }

            const result = _handleApiResponse(stdoutText, true)
            stdoutText = ""
            stderrText = ""

            if (!result.success) {
                console.error("[GitHubService] listIssues error:", result.error)
                errorOccurred(result.error)
                return
            }

            // Filter out pull requests (they come mixed with issues)
            const issues = result.data.filter(item => !item.pull_request)

            console.log("[GitHubService] listIssues loaded:", issues.length, "issues")
            issuesLoaded(issues)
        }
    }

    /**
     * Process: Get Single Issue (T055)
     * GET /repos/{owner}/{repo}/issues/{issue_number}
     */
    Process {
        id: getIssueProcess
        running: false

        property string owner: ""
        property string repo: ""
        property int issueNumber: 0
        property bool includeComments: true
        property string stdoutText: ""
        property string stderrText: ""

        // Internal: store issue data while fetching comments
        property var _issueData: null

        command: ["curl", "-s", "-i",
            "-H", "Accept: application/vnd.github+json",
            "-H", "X-GitHub-Api-Version: " + apiVersion,
            "-H", "User-Agent: " + userAgent,
            "-H", "Authorization: Bearer " + _accessToken,
            apiBaseUrl + "/repos/" + owner + "/" + repo + "/issues/" + issueNumber
        ]

        stdout: StdioCollector {
            onCollected: text => {
                getIssueProcess.stdoutText = text
            }
        }

        stderr: StdioCollector {
            onCollected: text => {
                getIssueProcess.stderrText = text
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                isLoading = false
                console.error("[GitHubService] getIssue network error")
                errorOccurred("Network error - check connection")
                stdoutText = ""
                stderrText = ""
                return
            }

            const result = _handleApiResponse(stdoutText, true)
            stdoutText = ""
            stderrText = ""

            if (!result.success) {
                isLoading = false
                console.error("[GitHubService] getIssue error:", result.error)
                errorOccurred(result.error)
                return
            }

            // Store issue data
            _issueData = result.data

            // If comments requested and issue has comments, fetch them
            if (includeComments && result.data.comments > 0) {
                console.log("[GitHubService] Issue has", result.data.comments, "comments, fetching...")
                getCommentsProcess.owner = owner
                getCommentsProcess.repo = repo
                getCommentsProcess.issueNumber = issueNumber
                getCommentsProcess._parentIssue = _issueData
                getCommentsProcess.running = true
            } else {
                // No comments to fetch, emit issue with empty comments array
                isLoading = false
                _issueData.commentsData = []
                console.log("[GitHubService] getIssue loaded:", owner + "/" + repo + "#" + issueNumber)
                issueLoaded(_issueData)
                _issueData = null
            }
        }
    }

    /**
     * Process: Get Issue Comments (T055 helper)
     * GET /repos/{owner}/{repo}/issues/{issue_number}/comments
     */
    Process {
        id: getCommentsProcess
        running: false

        property string owner: ""
        property string repo: ""
        property int issueNumber: 0
        property var _parentIssue: null
        property string stdoutText: ""
        property string stderrText: ""

        command: ["curl", "-s", "-i",
            "-H", "Accept: application/vnd.github+json",
            "-H", "X-GitHub-Api-Version: " + apiVersion,
            "-H", "User-Agent: " + userAgent,
            "-H", "Authorization: Bearer " + _accessToken,
            apiBaseUrl + "/repos/" + owner + "/" + repo + "/issues/" + issueNumber + "/comments"
        ]

        stdout: StdioCollector {
            onCollected: text => {
                getCommentsProcess.stdoutText = text
            }
        }

        stderr: StdioCollector {
            onCollected: text => {
                getCommentsProcess.stderrText = text
            }
        }

        onExited: (exitCode, exitStatus) => {
            isLoading = false

            if (exitCode !== 0) {
                console.error("[GitHubService] getComments network error")
                // Still emit issue with empty comments
                if (_parentIssue) {
                    _parentIssue.commentsData = []
                    issueLoaded(_parentIssue)
                }
                errorOccurred("Failed to load comments")
                stdoutText = ""
                stderrText = ""
                _parentIssue = null
                return
            }

            const result = _handleApiResponse(stdoutText, true)
            stdoutText = ""
            stderrText = ""

            let comments = []
            if (result.success && Array.isArray(result.data)) {
                comments = result.data
            } else if (!result.success) {
                console.warn("[GitHubService] getComments error:", result.error)
            }

            // Emit issue with comments if we have a parent issue
            if (_parentIssue) {
                _parentIssue.commentsData = comments
                console.log("[GitHubService] getIssue loaded with", comments.length, "comments:",
                           owner + "/" + repo + "#" + issueNumber)
                issueLoaded(_parentIssue)
                _parentIssue = null
            } else {
                // Standalone comments request
                console.log("[GitHubService] getComments loaded:", comments.length, "comments")
                commentsLoaded(issueNumber, comments)
            }
        }
    }

    /**
     * Process: Create Issue (T060)
     * POST /repos/{owner}/{repo}/issues
     */
    Process {
        id: createIssueProcess
        running: false

        property string owner: ""
        property string repo: ""
        property string _requestBody: ""
        property string stdoutText: ""
        property string stderrText: ""

        command: ["curl", "-s", "-i",
            "-X", "POST",
            "-H", "Accept: application/vnd.github+json",
            "-H", "X-GitHub-Api-Version: " + apiVersion,
            "-H", "User-Agent: " + userAgent,
            "-H", "Authorization: Bearer " + _accessToken,
            "-H", "Content-Type: application/json",
            "-d", _requestBody,
            apiBaseUrl + "/repos/" + owner + "/" + repo + "/issues"
        ]

        stdout: StdioCollector {
            onCollected: text => {
                createIssueProcess.stdoutText = text
            }
        }

        stderr: StdioCollector {
            onCollected: text => {
                createIssueProcess.stderrText = text
            }
        }

        onExited: (exitCode, exitStatus) => {
            isLoading = false
            _requestBody = ""

            if (exitCode !== 0) {
                console.error("[GitHubService] createIssue network error")
                errorOccurred("Network error - check connection")
                stdoutText = ""
                stderrText = ""
                return
            }

            const result = _handleApiResponse(stdoutText, true)
            stdoutText = ""
            stderrText = ""

            if (!result.success) {
                console.error("[GitHubService] createIssue error:", result.error)
                errorOccurred(result.error)
                return
            }

            console.log("[GitHubService] Issue created:", owner + "/" + repo + "#" + result.data.number)
            issueUpdated(result.data)
        }
    }

    /**
     * Process: Update Issue - close/reopen (T061)
     * PATCH /repos/{owner}/{repo}/issues/{issue_number}
     */
    Process {
        id: updateIssueProcess
        running: false

        property string owner: ""
        property string repo: ""
        property int issueNumber: 0
        property string _requestBody: ""
        property string stdoutText: ""
        property string stderrText: ""

        command: ["curl", "-s", "-i",
            "-X", "PATCH",
            "-H", "Accept: application/vnd.github+json",
            "-H", "X-GitHub-Api-Version: " + apiVersion,
            "-H", "User-Agent: " + userAgent,
            "-H", "Authorization: Bearer " + _accessToken,
            "-H", "Content-Type: application/json",
            "-d", _requestBody,
            apiBaseUrl + "/repos/" + owner + "/" + repo + "/issues/" + issueNumber
        ]

        stdout: StdioCollector {
            onCollected: text => {
                updateIssueProcess.stdoutText = text
            }
        }

        stderr: StdioCollector {
            onCollected: text => {
                updateIssueProcess.stderrText = text
            }
        }

        onExited: (exitCode, exitStatus) => {
            isLoading = false
            _requestBody = ""

            if (exitCode !== 0) {
                console.error("[GitHubService] updateIssue network error")
                errorOccurred("Network error - check connection")
                stdoutText = ""
                stderrText = ""
                return
            }

            const result = _handleApiResponse(stdoutText, true)
            stdoutText = ""
            stderrText = ""

            if (!result.success) {
                console.error("[GitHubService] updateIssue error:", result.error)
                errorOccurred(result.error)
                return
            }

            const stateAction = result.data.state === "closed" ? "closed" : "reopened"
            console.log("[GitHubService] Issue", stateAction + ":", owner + "/" + repo + "#" + issueNumber)
            issueUpdated(result.data)
        }
    }

    /**
     * Process: Add Comment (T057)
     * POST /repos/{owner}/{repo}/issues/{issue_number}/comments
     */
    Process {
        id: addCommentProcess
        running: false

        property string owner: ""
        property string repo: ""
        property int issueNumber: 0
        property string _requestBody: ""
        property string stdoutText: ""
        property string stderrText: ""

        command: ["curl", "-s", "-i",
            "-X", "POST",
            "-H", "Accept: application/vnd.github+json",
            "-H", "X-GitHub-Api-Version: " + apiVersion,
            "-H", "User-Agent: " + userAgent,
            "-H", "Authorization: Bearer " + _accessToken,
            "-H", "Content-Type: application/json",
            "-d", _requestBody,
            apiBaseUrl + "/repos/" + owner + "/" + repo + "/issues/" + issueNumber + "/comments"
        ]

        stdout: StdioCollector {
            onCollected: text => {
                addCommentProcess.stdoutText = text
            }
        }

        stderr: StdioCollector {
            onCollected: text => {
                addCommentProcess.stderrText = text
            }
        }

        onExited: (exitCode, exitStatus) => {
            isLoading = false
            _requestBody = ""

            if (exitCode !== 0) {
                console.error("[GitHubService] addComment network error")
                errorOccurred("Network error - check connection")
                stdoutText = ""
                stderrText = ""
                return
            }

            const result = _handleApiResponse(stdoutText, true)
            stdoutText = ""
            stderrText = ""

            if (!result.success) {
                console.error("[GitHubService] addComment error:", result.error)
                errorOccurred(result.error)
                return
            }

            console.log("[GitHubService] Comment added to:", owner + "/" + repo + "#" + issueNumber)
            commentAdded(result.data)
        }
    }

    // =========================================================================
    // INITIALIZATION
    // =========================================================================

    Component.onCompleted: {
        console.log("[GitHubService] Singleton initialized")
        console.log("[GitHubService] Client ID:", clientId === "GITHUB_CLIENT_ID" ?
                   "(not configured - replace GITHUB_CLIENT_ID)" : "(configured)")

        // Try to load stored token on startup
        loadStoredToken()
    }

    Component.onDestruction: {
        console.log("[GitHubService] Singleton destroyed")
        pollTimer.stop()
    }
}
