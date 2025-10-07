#!/usr/bin/env python3
"""
Create reference TAR files using Python's tarfile module for comparison testing
"""
import tarfile
import tempfile
import os
import sys

def create_reference_tar_files():
    """Create various TAR files using Python for MoonBit comparison"""
    
    # Test 1: Simple single file TAR
    print("Creating test1_simple.tar...")
    with tarfile.open("/Users/dii/git/zip.mbt/tar/test1_simple.tar", 'w') as tar:
        content = b"Hello TAR world!"
        info = tarfile.TarInfo(name="test.txt")
        info.size = len(content)
        info.mode = 0o644
        info.uid = 1000
        info.gid = 1000
        info.mtime = 1696694400
        tar.addfile(info, fileobj=tarfile.io.BytesIO(content))
    
    # Test 2: Multiple files with directory
    print("Creating test2_multiple.tar...")
    with tarfile.open("/Users/dii/git/zip.mbt/tar/test2_multiple.tar", 'w') as tar:
        # Add a file
        content1 = b"This is a README"
        info1 = tarfile.TarInfo(name="readme.txt")
        info1.size = len(content1)
        info1.mode = 0o644
        info1.uid = 1000
        info1.gid = 1000
        info1.mtime = 1696694400
        tar.addfile(info1, fileobj=tarfile.io.BytesIO(content1))
        
        # Add a directory
        info2 = tarfile.TarInfo(name="docs/")
        info2.type = tarfile.DIRTYPE
        info2.mode = 0o755
        info2.uid = 1000
        info2.gid = 1000
        info2.mtime = 1696694400
        tar.addfile(info2)
        
        # Add a file in the directory
        content3 = b"# User Guide\n\nContent here."
        info3 = tarfile.TarInfo(name="docs/guide.md")
        info3.size = len(content3)
        info3.mode = 0o644
        info3.uid = 1000
        info3.gid = 1000
        info3.mtime = 1696694400
        tar.addfile(info3, fileobj=tarfile.io.BytesIO(content3))
    
    # Test 3: Binary data file
    print("Creating test3_binary.tar...")
    with tarfile.open("/Users/dii/git/zip.mbt/tar/test3_binary.tar", 'w') as tar:
        binary_content = b"\x00\x01\x02Hello\xFF\xFE World\x03\x04"
        info = tarfile.TarInfo(name="binary.dat")
        info.size = len(binary_content)
        info.mode = 0o644
        info.uid = 1000
        info.gid = 1000
        info.mtime = 1696694400
        tar.addfile(info, fileobj=tarfile.io.BytesIO(binary_content))
    
    # Test 4: Empty archive
    print("Creating test4_empty.tar...")
    with tarfile.open("/Users/dii/git/zip.mbt/tar/test4_empty.tar", 'w') as tar:
        pass  # Empty archive
    
    print("\\nReference TAR files created. Analyzing structure...")
    
    # Analyze each file
    for filename in ["test1_simple.tar", "test2_multiple.tar", "test3_binary.tar", "test4_empty.tar"]:
        filepath = f"/Users/dii/git/zip.mbt/tar/{filename}"
        print(f"\\n=== {filename} ===")
        
        # Get file size
        size = os.path.getsize(filepath)
        print(f"Size: {size} bytes")
        
        # Read and analyze content
        with open(filepath, 'rb') as f:
            data = f.read()
            print(f"First 32 bytes: {data[:32].hex()}")
            if len(data) >= 512:
                null_byte = b'\\x00'
                print(f"Header name field: {data[0:100].rstrip(null_byte)}")
                print(f"Header mode field: {data[100:108].rstrip(null_byte)}")
                print(f"Header size field: {data[124:136].rstrip(null_byte)}")
                print(f"Header typeflag: {data[156]} ({chr(data[156]) if data[156] > 0 else 'null'})")
                print(f"Header magic: {data[257:262]}")
        
        # Parse with tarfile to verify structure
        try:
            with tarfile.open(filepath, 'r') as tar:
                members = tar.getmembers()
                print(f"Contains {len(members)} members:")
                for member in members:
                    print(f"  - {member.name} ({'dir' if member.isdir() else 'file'}, {member.size} bytes, mode={oct(member.mode)})")
        except Exception as e:
            print(f"Error parsing: {e}")

def print_test_expectations():
    """Print expected results for MoonBit tests"""
    print("\\n" + "="*50)
    print("EXPECTED RESULTS FOR MOONBIT TESTS")
    print("="*50)
    
    expectations = {
        "test1_simple.tar": {
            "size": 10240,
            "entries": 1,
            "content": "Hello TAR world!",
            "filename": "test.txt"
        },
        "test2_multiple.tar": {
            "size": 10240,
            "entries": 3,
            "files": ["readme.txt", "docs/", "docs/guide.md"]
        },
        "test3_binary.tar": {
            "size": 10240,
            "entries": 1,
            "binary_length": 14
        },
        "test4_empty.tar": {
            "size": 10240,
            "entries": 0
        }
    }
    
    for filename, expected in expectations.items():
        print(f"\\n{filename}:")
        for key, value in expected.items():
            print(f"  {key}: {value}")

if __name__ == "__main__":
    create_reference_tar_files()
    print_test_expectations()