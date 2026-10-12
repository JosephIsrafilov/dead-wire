import hashlib,importlib.util,json,sys,zipfile,unittest
from pathlib import Path
root=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(root/'tools'))
import package_windows_beta as pkg
suite=unittest.defaultTestLoader.discover(str(root/'tools'),pattern='package_windows_beta_test.py')
tests=unittest.TextTestRunner(verbosity=1).run(suite)
source=root/'builds/windows-beta/export_2026-10-12_p12'
pck=source/pkg.SOURCE_PACK
entries=pkg.read_pck_directory(pck)
pkg.verify_pck_payloads(pck,entries)
pkg.check_pck_exclusions(pck,entries)
pkg.check_pck_has_class_scripts(pck,root/'.godot/global_script_class_cache.cfg')
manifest=pkg.check_manifest(source)
zip_path=root/'builds/windows-beta/dead-wire-windows-beta-f82939d9995e-2ed1b969852f.zip'
with zipfile.ZipFile(zip_path) as z:
    names=z.namelist(); bad=z.testzip()
    exe=next(n for n in names if n.endswith('/'+pkg.SOURCE_EXECUTABLE))
    pack=next(n for n in names if n.endswith('/'+pkg.SOURCE_PACK))
    exact=(z.read(exe)==(source/pkg.SOURCE_EXECUTABLE).read_bytes() and z.read(pack)==pck.read_bytes())
result=dict(packager_tests=tests.testsRun,failures=len(tests.failures),errors=len(tests.errors),PCK_entries=len(entries),PCK_payloads_classes_exclusions='PASS',zip_crc=bad,zip_count=len(names),zip_exe_pck_equal_export=exact,zip_sha256=hashlib.sha256(zip_path.read_bytes()).hexdigest(),runtime_manifest=[p.name for p in manifest],zip_names=names)
(Path(__file__).parent/'package_review.json').write_text(json.dumps(result,indent=2),encoding='utf8')
print(json.dumps(result,indent=2))
