///|
/// White-box end-to-end test: create a real directory tree with sample files,
/// scan it, and check the counts.

///|
async fn cleanup_dir(dir : String) -> Unit {
  if @fs.exists(dir) {
    @fs.rmdir(dir, recursive=true, allow_missing=true)
  }
}

///|
async test "scan a real directory tree" {
  let dir = "test_scan_tmp"
  cleanup_dir(dir)
  @fs.mkdir(dir, recursive=true)
  @fs.write_text(
    dir + "/main.mbt",
    "fn main {\n  // hello\n  println(\"world\")\n}\n",
  )
  @fs.write_text(
    dir + "/util.py",
    "import os\n# a comment\nx = 1\n\n\ndef f():\n    return x\n",
  )
  @fs.mkdir(dir + "/sub")
  @fs.write_text(dir + "/sub/data.json", "{\n  \"key\": \"value\"\n}\n")
  @fs.write_text(
    dir + "/sub/skip.ts",
    "// ignored by language filter\nconst a = 1\n",
  )
  let options = CountOptions::default()
  let (counts, errors) = scan_directory(dir, options)
  cleanup_dir(dir)
  assert_eq(errors.length(), 0)
  assert_eq(counts.length(), 4)
  let mbt = counts.filter(fn(f : FileCount) { f.language == "MoonBit" })[0]
  assert_eq(mbt.code, 3)
  assert_eq(mbt.comment, 1)
  assert_eq(mbt.blank, 0)
  let py = counts.filter(fn(f : FileCount) { f.language == "Python" })[0]
  assert_eq(py.code, 4)
  assert_eq(py.comment, 1)
  assert_eq(py.blank, 2)
  let ts = counts.filter(fn(f : FileCount) { f.language == "TypeScript" })[0]
  assert_eq(ts.code, 1)
  assert_eq(ts.comment, 1)
}

///|
async test "language filter limits results" {
  let dir = "test_scan_tmp2"
  cleanup_dir(dir)
  @fs.mkdir(dir, recursive=true)
  @fs.write_text(dir + "/a.mbt", "fn main {\n}\n")
  @fs.write_text(dir + "/b.rs", "fn main() {}\n")
  let options = CountOptions::default().with_languages(["MoonBit"])
  let (counts, errors) = scan_directory(dir, options)
  cleanup_dir(dir)
  assert_eq(errors.length(), 0)
  assert_eq(counts.length(), 1)
  assert_eq(counts[0].language, "MoonBit")
}

///|
async test "exclude patterns are honored" {
  let dir = "test_scan_tmp3"
  cleanup_dir(dir)
  @fs.mkdir(dir, recursive=true)
  @fs.write_text(dir + "/keep.mbt", "fn main {\n}\n")
  @fs.mkdir(dir + "/target")
  @fs.write_text(dir + "/target/gen.mbt", "fn main {\n}\n")
  let options = CountOptions::default()
  let (counts, errors) = scan_directory(dir, options)
  cleanup_dir(dir)
  assert_eq(errors.length(), 0)
  assert_eq(counts.length(), 1)
  assert_eq(counts[0].path.has_suffix("keep.mbt"), true)
}

///|
async test "hidden files are skipped by default" {
  let dir = "test_scan_tmp4"
  cleanup_dir(dir)
  @fs.mkdir(dir, recursive=true)
  @fs.write_text(dir + "/visible.mbt", "fn main {\n}\n")
  @fs.write_text(dir + "/.hidden.py", "x = 1\n")
  let options = CountOptions::default()
  let (counts, errors) = scan_directory(dir, options)
  cleanup_dir(dir)
  assert_eq(errors.length(), 0)
  assert_eq(counts.length(), 1)
  assert_eq(counts[0].language, "MoonBit")
}

///|
async test "unreadable text file is reported, not fatal" {
  let dir = "test_scan_tmp5"
  cleanup_dir(dir)
  @fs.mkdir(dir, recursive=true)
  @fs.write_text(dir + "/ok.mbt", "fn main {\n}\n")
  // invalid UTF-8 bytes: the scan must skip the file, not abort.
  @fs.write_binary(dir + "/bad.md", b"\xFF\xFE\x00\x01")
  let (counts, errors) = scan_directory(dir, CountOptions::default())
  cleanup_dir(dir)
  assert_eq(counts.length(), 1)
  assert_eq(counts[0].language, "MoonBit")
  assert_eq(errors.length(), 1)
}
