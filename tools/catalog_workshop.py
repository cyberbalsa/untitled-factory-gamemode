"""Read GMA directory metadata without extracting or loading addon code/assets."""
import argparse
import json
import lzma
import struct
from pathlib import Path


def cstring(stream):
    result = bytearray()
    for _ in range(1_048_576):
        char = stream.read(1)
        if char == b"\0":
            return result.decode("utf-8", errors="replace")
        if not char:
            raise ValueError("Truncated GMA string")
        result.extend(char)
    raise ValueError("GMA string exceeds metadata limit")


def catalog(path):
    opener = lzma.open if path.suffix == ".bin" else open
    with opener(path, "rb") as stream:
        if stream.read(4) != b"GMAD":
            raise ValueError("Not an uncompressed GMA")
        version = stream.read(1)[0]
        stream.read(16)  # Steam ID and timestamp; neither is needed in the inventory.
        if version > 1:
            while cstring(stream):
                pass
        title, description, _author = cstring(stream), cstring(stream), cstring(stream)
        stream.read(4)
        models = []
        lua_count = 0
        while struct.unpack("<I", stream.read(4))[0]:
            filename = cstring(stream)
            stream.read(12)  # uint64 payload length + uint32 CRC
            if filename.endswith(".mdl"):
                models.append(filename)
            if filename.endswith(".lua"):
                lua_count += 1
        return {"workshop_id": path.parent.name, "title": title,
                "description": description, "models": models, "lua_files": lua_count}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("workshop", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    results = []
    archives = list(args.workshop.rglob("*.gma")) + list(args.workshop.rglob("*_legacy.bin"))
    for path in sorted(archives):
        try:
            result = catalog(path)
            results.append(result)
            print(f"{result['workshop_id']}: {result['title']} ({len(result['models'])} models)")
        except (OSError, ValueError, struct.error, IndexError, lzma.LZMAError) as error:
            print(f"Skipped {path.name}: {error}")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(results, indent=2), encoding="utf-8")
