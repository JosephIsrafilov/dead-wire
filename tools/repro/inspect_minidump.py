"""Read exception/module metadata from a minidump, not a symbolized stack trace."""
import argparse
import json
import struct
from pathlib import Path

def inspect(path):
    data = Path(path).read_bytes()
    def unpack(fmt, offset):
        return struct.unpack_from("<" + fmt, data, offset)
    signature, version, count, directory = unpack("IIII", 0)
    if signature != 0x504D444D:
        raise ValueError("Not a MINIDUMP")
    streams = {}
    for index in range(count):
        kind, size, rva = unpack("III", directory + index * 12)
        streams[kind] = (size, rva)
    def string(rva):
        length, = unpack("I", rva)
        return data[rva + 4:rva + 4 + length].decode("utf-16-le", errors="replace")
    modules = []
    if 4 in streams:
        _, rva = streams[4]
        count, = unpack("I", rva)
        for index in range(count):
            offset = rva + 4 + index * 108
            base, size, checksum, timestamp, name = unpack("QIIII", offset)
            modules.append({"base": base, "size": size, "name": string(name)})
    result = {"path": str(path), "streams": sorted(streams), "modules": modules}
    if 6 in streams:
        _, rva = streams[6]
        thread, alignment = unpack("II", rva)
        code, flags, record, address, parameter_count, unused = unpack("IIQQII", rva + 8)
        parameters = unpack("15Q", rva + 40)
        module = next((m for m in modules if m["base"] <= address < m["base"] + m["size"]), None)
        result["exception"] = {"thread_id": thread, "code": f"0x{code:08X}",
            "address": f"0x{address:X}", "parameters": list(parameters[:parameter_count]),
            "module": module["name"] if module else None,
            "module_offset": f"0x{address - module['base']:X}" if module else None}
    result["caveat"] = "No symbolized call stack. This dump is not linked to the latest probe without separate provenance."
    return result

if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("path")
    p.add_argument("--out", type=Path, required=True)
    args = p.parse_args()
    result = inspect(args.path)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, indent=2), encoding="utf8")
    print(json.dumps(result.get("exception", {})))
