import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("configure", Path(__file__).resolve().parents[1] / "scripts/configure.py")
config = importlib.util.module_from_spec(spec)
spec.loader.exec_module(config)


class WebsiteConfigurationTests(unittest.TestCase):
    def test_normalizes_https_origin(self):
        self.assertEqual(config.website_url(" https://3377test.erg3be.workers.dev "), config.DEFAULT_URL)

    def test_rejects_unsafe_or_ambiguous_addresses(self):
        for url in ["http://example.com", "https://user:secret@example.com", "file:///tmp/a",
                    "https://example.com/path", "https://example.com/?token=secret",
                    "https://example.com/#x", "https://localhost", "https://example.com:8443",
                    "https://example.com/\nBAD", "javascript:alert(1)"]:
            with self.subTest(url=url), self.assertRaises(ValueError):
                config.website_url(url)


if __name__ == "__main__":
    unittest.main()
