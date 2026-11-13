"""Provider boundary. Only project-authored demo lyrics are bundled."""
from copy import deepcopy
import json
from pathlib import Path
from typing import Protocol


class LyricsProvider(Protocol):
    def lyrics(self, track_id: str) -> dict | None: ...


class DemoProvider:
    def __init__(self):
        self._document = json.loads((Path(__file__).parent / "fixtures/demo.json").read_text(encoding="utf-8"))

    def lyrics(self, track_id: str) -> dict | None:
        return deepcopy(self._document) if track_id == self._document["trackID"] else None


class UnconfiguredProvider:
    def lyrics(self, track_id: str) -> dict | None:
        raise ProviderUnavailable("A licensed provider is not configured")


class ProviderUnavailable(Exception):
    pass
