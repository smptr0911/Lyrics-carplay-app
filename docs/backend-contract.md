# App-owned lyrics backend contract

Status: implemented client contract; no backend or vendor agreement is provided. This is not a third-party API schema. Keep the default composition on MockLyricsProvider until a licensed backend is deployed. To integrate, inject `LicensedLyricsProvider(endpoint: URL(...))` in AppContainer using your own HTTPS service URL; never embed a confidential vendor key.

Request: `GET <configured HTTPS endpoint>?trackID=<percent-encoded source-qualified ID>`. Existing unrelated query parameters are preserved. The client requests application/json. Matching and vendor lookup belong to the backend. The backend must authenticate users if needed; client account/token support remains a later task. Query URLs contain track IDs and should be redacted from access logs where appropriate.

Successful response (200, Content-Type: application/json):

```json
{
  "trackID": "demo:open-road",
  "attribution": "Original demonstration lyrics",
  "lines": [
    { "startTime": 0, "text": "Morning light across the sky" },
    { "startTime": 5, "text": "Clouds like paper drifting by" }
  ],
  "cacheUntil": null
}
```

`cacheUntil` is optional/null by default. Only send a future ISO-8601 UTC deadline when the provider agreement explicitly allows app-side retention for that duration. The client uses an ephemeral session without URLCache/cookies, and the separate in-memory lyrics cache enforces the deadline. Plain lyrics omit startTime or use null. Timed lines must be nonnegative and finite. Mixed documents remain static. Attribution must be nonempty, and trackID must exactly match the requested ID. Empty lines arrays represent unavailable lyrics. Blank lines/text and malformed timestamps are rejected.

204/404 mean unavailable; 401/403 require authorization; 429 is a visible rate limit; other statuses indicate service failure. No automatic retries are performed. Requests time out; cancellation is propagated. The HTTP transport rejects bodies above 1 MB while streaming, and cross-origin redirects are refused. Debug simulator builds may use the explicitly configured localhost development endpoint; device and Release builds require HTTPS. Errors shown to users contain no response bodies, request URLs, or tokens.

Backend responsibilities: vendor licensing, territorial checks, exact/confident matching, provider attribution, rate limiting, deletion rules, credential storage, authentication, and monitoring without restricted lyric payloads. Test these against the selected provider before enabling live mode.

A runnable demo-only server is available in [backend/README.md](../backend/README.md). It contains only project-authored original lyrics and is not a production vendor integration.
