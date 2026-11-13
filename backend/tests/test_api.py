import json
import threading
import unittest
from urllib.error import HTTPError
from urllib.request import Request, build_opener, ProxyHandler

from backend.app import make_server, RateLimit
from backend.providers import UnconfiguredProvider, ProviderUnavailable


class APITests(unittest.TestCase):
    def setUp(self):
        self.server = make_server(0)
        self.thread = threading.Thread(target=self.server.serve_forever, kwargs={"poll_interval": 0.01}, daemon=True)
        self.thread.start()
        self.base = f"http://127.0.0.1:{self.server.server_port}"
        self.client = build_opener(ProxyHandler({}))

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)

    def request(self, path, method="GET"):
        try:
            response = self.client.open(Request(self.base + path, method=method), timeout=3)
        except HTTPError as error:
            response = error
        with response:
            return response.status, json.loads(response.read()), response.headers

    def test_original_lyrics_match_client_contract_and_forbid_http_caching(self):
        status, body, headers = self.request("/v1/lyrics?trackID=demo%3Aopen-road")
        self.assertEqual(status, 200)
        self.assertEqual(body["trackID"], "demo:open-road")
        self.assertEqual(len(body["lines"]), 6)
        self.assertIsNone(body["cacheUntil"])
        self.assertTrue(body["attribution"])
        self.assertEqual(headers["Cache-Control"], "no-store")

    def test_no_match(self):
        self.assertEqual(self.request("/v1/lyrics?trackID=appleMusic%3Aunknown")[0], 404)

    def test_spotify_is_blocked_before_provider_lookup(self):
        self.assertEqual(self.request("/v1/lyrics?trackID=spotify%3Atrack%3A123")[0], 403)

    def test_invalid_queries(self):
        for suffix in ["", "?trackID=", "?trackID=a&trackID=b", "?trackID=a&token=secret", "?trackID=" + "a" * 257]:
            with self.subTest(suffix=suffix):
                self.assertEqual(self.request("/v1/lyrics" + suffix)[0], 400)

    def test_health_and_method(self):
        self.assertEqual(self.request("/health")[1]["status"], "ok")
        status, _, headers = self.request("/v1/lyrics", method="POST")
        self.assertEqual(status, 405)
        self.assertEqual(headers["Allow"], "GET")


class PolicyTests(unittest.TestCase):
    def test_rate_limit_expires_without_sleep(self):
        limiter = RateLimit(limit=2, window=10)
        self.assertTrue(limiter.allow(now=0))
        self.assertTrue(limiter.allow(now=1))
        self.assertFalse(limiter.allow(now=2))
        self.assertTrue(limiter.allow(now=10))

    def test_unconfigured_provider_fails_closed(self):
        with self.assertRaises(ProviderUnavailable):
            UnconfiguredProvider().lyrics("appleMusic:1")



class FailureAPITests(unittest.TestCase):
    def response_for(self, provider, limiter=None):
        server = make_server(0, provider=provider, limiter=limiter)
        thread = threading.Thread(target=server.serve_forever, kwargs={"poll_interval": 0.01}, daemon=True)
        thread.start()
        try:
            try:
                response = build_opener(ProxyHandler({})).open(
                    f"http://127.0.0.1:{server.server_port}/v1/lyrics?trackID=demo%3Aopen-road", timeout=3)
            except HTTPError as error:
                response = error
            with response:
                return response.status, json.loads(response.read()), response.headers
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=2)

    def test_unconfigured_provider_is_503(self):
        self.assertEqual(self.response_for(UnconfiguredProvider())[0], 503)

    def test_vendor_failure_is_redacted(self):
        class BrokenProvider:
            def lyrics(self, track_id):
                raise RuntimeError("secret-vendor-key")
        status, body, _ = self.response_for(BrokenProvider())
        self.assertEqual(status, 502)
        self.assertEqual(body, {"error": "provider_failure"})
        self.assertNotIn("secret", json.dumps(body))

    def test_rate_limit_returns_retry_header(self):
        status, _, headers = self.response_for(UnconfiguredProvider(), RateLimit(limit=0))
        self.assertEqual(status, 429)
        self.assertEqual(headers["Retry-After"], "60")


if __name__ == "__main__":
    unittest.main()
