use assert_cmd::prelude::*;
use assert_fs::prelude::*;
use predicates::prelude::*;
use std::error::Error;
use std::process::Command;

mod util;

#[test]
fn success() -> Result<(), Box<dyn Error>> {
    let (temp, input) = util::setup()?;

    let output = temp.child("archive.tar.gz");

    Command::cargo_bin("archive")?
        .arg(input.path())
        .arg(output.path())
        .assert()
        .success();

    Command::new("bsdtar")
        .arg("-tzf")
        .arg(output.path())
        .assert()
        .success()
        .stdout(predicate::str::contains("src/foo"))
        .stdout(predicate::str::contains("src/bar"))
        .stdout(predicate::str::contains("src/baz"));

    let hashes = temp.child("archive.tar.gz.md5");

    hashes.assert(predicate::str::contains("archive.tar.gz"));

    hashes.assert(predicate::str::contains(
        "d3b07384d113edec49eaa6238ad5ff00  src/foo",
    ));

    hashes.assert(predicate::str::contains(
        "c157a79031e1c40f85931829bc5fc552  src/bar",
    ));

    hashes.assert(predicate::str::contains(
        "258622b1688250cb619f3c9ccaefb7eb  src/baz",
    ));

    temp.close()?;

    Ok(())
}
