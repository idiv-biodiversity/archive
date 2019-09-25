use assert_fs::fixture::ChildPath;
use assert_fs::prelude::*;
use assert_fs::TempDir;
use std::error::Error;

pub fn setup() -> Result<(TempDir, ChildPath), Box<dyn Error>> {
    let temp = assert_fs::TempDir::new()?;

    let source = temp.child("src");
    source.create_dir_all().unwrap();

    source.child("foo").write_str("foo\n")?;
    source.child("bar").write_str("bar\n")?;
    source.child("baz").write_str("baz\n")?;

    Ok((temp, source))
}
