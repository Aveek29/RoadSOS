"""A tiny, dependency-free, in-memory rate limiter.

Intended to protect the (comparatively expensive) ML inference endpoint from
accidental request storms. It is intentionally simple: a sliding window of
timestamps per client key. For multi-process deployments put a real gateway
(e.g. nginx / API gateway) in front and treat this as defence-in-depth.
"""
from __future__ import annotations

import threading
import time
from collections import defaultdict, deque


class RateLimiter:
    def __init__(self, max_requests: int, window_seconds: float):
        self.max_requests = int(max_requests)
        self.window = float(window_seconds)
        self._hits: dict = defaultdict(deque)
        self._lock = threading.Lock()

    def allow(self, key: str) -> bool:
        if self.max_requests <= 0:
            return True
        now = time.monotonic()
        with self._lock:
            bucket = self._hits[key]
            cutoff = now - self.window
            while bucket and bucket[0] < cutoff:
                bucket.popleft()
            if len(bucket) >= self.max_requests:
                return False
            bucket.append(now)
            return True

    def retry_after(self, key: str) -> int:
        with self._lock:
            bucket = self._hits.get(key)
            if not bucket:
                return 0
            return max(1, int(self.window - (time.monotonic() - bucket[0])) + 1)
