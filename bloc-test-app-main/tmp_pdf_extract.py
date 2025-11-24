from pathlib import Path
from pypdf import PdfReader
import re
path = Path('304-Spec2000_AIDCCh9v2020dot1.pdf')
reader = PdfReader(path.open('rb'))
pattern = re.compile('Record Descriptor', re.I)
print('pages', len(reader.pages))
for idx, page in enumerate(reader.pages):
    text = page.extract_text() or ''
    if pattern.search(text):
        print('--- page', idx+1, '---')
        print(text)
        print('==============================')
