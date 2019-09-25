use assert_cmd::prelude::*;
use assert_fs::prelude::*;
use predicates::prelude::*;
use std::error::Error;
use std::process::Command;

#[test]
fn input_must_be_dir() -> Result<(), Box<dyn Error>> {
    let temp = assert_fs::TempDir::new()?;

    let input = temp.child("input");
    input.touch()?;

    let output = temp.child("archive.tar.gz");

    Command::cargo_bin("archive")?
        .arg(input.path())
        .arg(output.path())
        .assert()
        .failure()
        .stderr(predicate::str::contains("not a directory"));

    temp.close()?;

    Ok(())
}

#[test]
fn output_must_have_valid_extension() -> Result<(), Box<dyn Error>> {
    let temp = assert_fs::TempDir::new()?;

    let input = temp.child("input");
    input.create_dir_all()?;

    let output = temp.child("archive.tar.xz");

    Command::cargo_bin("archive")?
        .arg(input.path())
        .arg(output.path())
        .assert()
        .failure()
        .stderr(predicate::str::contains("must end in .tar.gz"));

    temp.close()?;

    Ok(())
}

#[test]
fn without_force_bail_if_output_exists() -> Result<(), Box<dyn Error>> {
    let temp = assert_fs::TempDir::new()?;

    let input = temp.child("input");
    input.create_dir_all()?;

    let output = temp.child("archive.tar.gz");
    output.touch()?;

    Command::cargo_bin("archive")?
        .arg(input.path())
        .arg(output.path())
        .assert()
        .failure()
        .stderr(predicate::str::contains("output already exists"));

    temp.close()?;

    Ok(())
}
