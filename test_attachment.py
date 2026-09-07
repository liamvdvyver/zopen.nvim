import importlib.machinery
from pathlib import Path
import sqlite3
import tempfile
import unittest

app = importlib.machinery.SourceFileLoader('attachment', './zotero-attachment').load_module()


class AttachmentTests(unittest.TestCase):
    def test_wal_snapshot_and_resolution(self):
        with tempfile.TemporaryDirectory() as directory:
            data = Path(directory)
            database = data / 'zotero.sqlite'
            db = sqlite3.connect(database)
            self.addCleanup(db.close)
            db.executescript('''
                PRAGMA journal_mode=WAL;
                CREATE TABLE libraries (libraryID, type);
                CREATE TABLE items (itemID, libraryID, key);
                CREATE TABLE deletedItems (itemID);
                CREATE TABLE fieldsCombined (fieldID, fieldName);
                CREATE TABLE itemData (itemID, fieldID, valueID);
                CREATE TABLE itemDataValues (valueID, value);
                CREATE TABLE itemAttachments (itemID, parentItemID, linkMode, contentType, path);
                INSERT INTO libraries VALUES (1, 'user');
                INSERT INTO items VALUES (1, 1, 'PARENT'), (2, 1, 'PDFKEY'), (3, 1, 'LINKKEY');
                INSERT INTO fieldsCombined VALUES (1, 'citationKey');
                INSERT INTO itemData VALUES (1, 1, 1);
                INSERT INTO itemDataValues VALUES (1, 'fan2009');
                INSERT INTO itemAttachments VALUES (2, 1, 0, 'application/pdf', 'storage:paper.pdf');
                INSERT INTO itemAttachments VALUES (3, 1, 2, 'text/plain', 'attachments:notes.txt');
            ''')
            pdf = data / 'storage/PDFKEY/paper.pdf'
            pdf.parent.mkdir(parents=True)
            pdf.touch()
            notes = data / 'notes.txt'
            notes.touch()
            originals = {p: p.read_bytes() for p in data.glob('zotero.sqlite*')}
            with app.snapshot(database) as copy:
                self.assertEqual(app.attachment_paths(copy, '@fan2009', data, data), [pdf, notes])
                self.assertEqual(app.attachment_paths(copy, 'PDFKEY', data, data), [pdf])
                with self.assertRaises(sqlite3.OperationalError):
                    copy.execute('DELETE FROM items')
                with self.assertRaises(ValueError):
                    app.attachment_paths(copy, "@missing' OR 1=1 --", data, data)
            self.assertEqual(originals, {p: p.read_bytes() for p in data.glob('zotero.sqlite*')})


if __name__ == '__main__':
    unittest.main()
