import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'scripts'))
from check_pixel_fonts import violations


class PixelTypographyGuard(unittest.TestCase):
    def test_shared_fonts_and_symbol_sizes_are_allowed(self):
        source = '''
        Text("本文").font(pochiPixelFont(.body))
        label.font = pochiPixelUIFont(16)
        Image(systemName: "heart.fill")
            .font(.system(size: 19, weight: .bold))
        label.fontName = "PixelMplus12-Bold"
        '''
        self.assertEqual(violations(source), [])

    def test_text_and_container_system_fonts_are_rejected(self):
        for source in [
            'Text("本文").font(.body)',
            'Text("本文").font(\n .system(size: 14))',
            'HStack { Image(systemName: "heart"); Text("本文") }.font(.headline)',
            'label.font = .systemFont(ofSize: 15)',
            'let font = UIFont(name: "Helvetica", size: 12)',
            'Text("本文").fontDesign(.rounded)',
            'label.fontName = "Helvetica"',
            '.navigationTitle("設定")',
        ]:
            with self.subTest(source=source):
                self.assertTrue(violations(source))

    def test_comments_and_string_contents_do_not_trigger_or_bypass_check(self):
        self.assertEqual(violations('''
        // Text("old").font(.body)
        /* label.font = .systemFont(ofSize: 15) */
        Text("Example: .font(.body)").font(pochiPixelFont(14))
        '''), [])
        self.assertTrue(violations('Text("Image(systemName: icon)").font(.body)'))

    def test_unrelated_fonts_are_not_allowed_on_symbol_container(self):
        self.assertTrue(violations('VStack { Image(systemName: "star") }.font(.caption)'))


if __name__ == '__main__':
    unittest.main()
