from pathlib import Path
import tomllib
import unittest


ROOT = Path(__file__).resolve().parents[1]


class ReportTemplateBoundaryTest(unittest.TestCase):
    def test_manifest_declares_empty_licensed_library(self) -> None:
        with (ROOT / "template-manifest.toml").open("rb") as stream:
            manifest = tomllib.load(stream)
        self.assertEqual(manifest["schema"], "aimora-report-template-library-v1")
        self.assertEqual(manifest["licence"], "PolyForm-Noncommercial-1.0.0")
        self.assertEqual(manifest["template_ids"], [])


if __name__ == "__main__":
    unittest.main()
