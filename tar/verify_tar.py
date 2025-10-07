#!/usr/bin/env python3
"""
TAR format verification script to understand Python's tarfile behavior
"""
import tarfile
import os
import tempfile

def verify_tar_format():
    print("=== TAR Format Verification ===")
    
    # Test 1: Empty TAR archive
    print("\n1. Empty TAR archive:")
    with tempfile.NamedTemporaryFile() as tmp:
        with tarfile.open(tmp.name, 'w') as tar:
            pass  # Empty archive
        
        tmp.seek(0)
        data = tmp.read()
        print(f"Empty TAR size: {len(data)} bytes")
        print(f"First 32 bytes: {data[:32].hex()}")
        print(f"Last 32 bytes: {data[-32:].hex()}")
    
    # Test 2: Single file TAR
    print("\n2. Single file TAR:")
    with tempfile.NamedTemporaryFile() as tmp:
        with tarfile.open(tmp.name, 'w') as tar:
            info = tarfile.TarInfo(name="test.txt")
            info.size = 11
            info.mode = 0o644
            info.uid = 1000
            info.gid = 1000
            info.mtime = 1696694400  # Fixed timestamp
            tar.addfile(info, fileobj=tarfile.io.BytesIO(b"Hello World"))
        
        tmp.seek(0)
        data = tmp.read()
        print(f"Single file TAR size: {len(data)} bytes")
        print(f"Header (first 512 bytes):")
        header = data[:512]
        
        # Parse header components
        name = header[0:100].rstrip(b'\x00').decode('ascii', errors='ignore')
        mode = header[100:108].rstrip(b'\x00').decode('ascii', errors='ignore')
        uid = header[108:116].rstrip(b'\x00').decode('ascii', errors='ignore')
        gid = header[116:124].rstrip(b'\x00').decode('ascii', errors='ignore')
        size = header[124:136].rstrip(b'\x00').decode('ascii', errors='ignore')
        mtime = header[136:148].rstrip(b'\x00').decode('ascii', errors='ignore')
        checksum = header[148:156].rstrip(b'\x00').decode('ascii', errors='ignore')
        typeflag = chr(header[156]) if header[156] != 0 else '0'
        magic = header[257:263].decode('ascii', errors='ignore')
        version = header[263:265]
        
        print(f"  Name: '{name}'")
        print(f"  Mode: '{mode}' (octal)")
        print(f"  UID: '{uid}'")
        print(f"  GID: '{gid}'")
        print(f"  Size: '{size}'")
        print(f"  MTime: '{mtime}'")
        print(f"  Checksum: '{checksum}'")
        print(f"  Type flag: '{typeflag}'")
        print(f"  Magic: '{magic}'")
        print(f"  Version: {version.hex()}")
        
        # Show actual file data
        file_data = data[512:512+11]
        print(f"  File data: {file_data}")
        
        # Show structure
        print(f"\nStructure breakdown:")
        print(f"  Header: 0-511 (512 bytes)")
        print(f"  Data: 512-522 (11 bytes)")
        print(f"  Padding: 523-1023 (501 bytes zeros)")
        print(f"  End marker: 1024-2047 (1024 bytes zeros)")
    
    # Test 3: Directory TAR
    print("\n3. Directory TAR:")
    with tempfile.NamedTemporaryFile() as tmp:
        with tarfile.open(tmp.name, 'w') as tar:
            info = tarfile.TarInfo(name="mydir/")
            info.type = tarfile.DIRTYPE
            info.mode = 0o755
            info.uid = 1000
            info.gid = 1000
            info.mtime = 1696694400
            tar.addfile(info)
        
        tmp.seek(0)
        data = tmp.read()
        print(f"Directory TAR size: {len(data)} bytes")
        header = data[:512]
        name = header[0:100].rstrip(b'\x00').decode('ascii', errors='ignore')
        typeflag = chr(header[156]) if header[156] != 0 else '0'
        print(f"  Name: '{name}'")
        print(f"  Type flag: '{typeflag}' (should be '5' for directory)")

    # Test 4: Calculate checksum manually
    print("\n4. Checksum calculation:")
    with tempfile.NamedTemporaryFile() as tmp:
        with tarfile.open(tmp.name, 'w') as tar:
            info = tarfile.TarInfo(name="test.txt")
            info.size = 5
            tar.addfile(info, fileobj=tarfile.io.BytesIO(b"hello"))
        
        tmp.seek(0)
        data = tmp.read()
        header = bytearray(data[:512])
        
        # Calculate checksum (sum of all header bytes, with checksum field as spaces)
        header_for_checksum = bytearray(header)
        header_for_checksum[148:156] = b'        '  # Replace checksum with spaces
        calculated_checksum = sum(header_for_checksum)
        
        stored_checksum = int(header[148:155].rstrip(b'\x00'), 8)  # Octal
        print(f"  Calculated checksum: {calculated_checksum}")
        print(f"  Stored checksum: {stored_checksum}")
        print(f"  Match: {calculated_checksum == stored_checksum}")

if __name__ == "__main__":
    verify_tar_format()