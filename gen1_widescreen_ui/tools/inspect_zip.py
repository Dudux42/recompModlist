"""Print ZIP metadata relevant to PhysFS compatibility."""

import sys
import zipfile


for archive_path in sys.argv[1:]:
    print(f"--- {archive_path}")
    with zipfile.ZipFile(archive_path) as archive:
        for info in archive.infolist():
            print(
                repr(info.filename),
                "create_system=", info.create_system,
                "flags=", hex(info.flag_bits),
                "method=", info.compress_type,
                "external=", hex(info.external_attr),
                "extract=", info.extract_version,
            )
