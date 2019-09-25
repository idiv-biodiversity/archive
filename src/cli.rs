use atty::Stream;
use clap::{crate_description, crate_version};
use clap::{App, AppSettings, Arg};
use std::error::Error;
use std::fs;
use std::path::Path;

pub fn build() -> App<'static, 'static> {
    let color = if atty::is(Stream::Stdout) {
        AppSettings::ColoredHelp
    } else {
        AppSettings::ColorNever
    };

    // ------------------------------------------------------------------------
    // arguments
    // ------------------------------------------------------------------------

    let input = Arg::with_name("input")
        .help("input directory to archive")
        .long_help(
"Specify input directory which is to be archived. Example: `/path/to/dir`."
        )
        .required(true)
        .validator(is_dir);

    let output = Arg::with_name("output")
        .help("output archive file name")
        .long_help(
"Specify the output archive file name. Example: `/path/to/archive.tar.gz`, \
 defaults to `${input}.tar.gz`."
        )
        .validator(output_validator);

    // ------------------------------------------------------------------------
    // flags
    // ------------------------------------------------------------------------

    let dereference = Arg::with_name("dereference")
        .short("h")
        .long("dereference")
        .help("follow symlinks")
        .display_order(1);

    let force = Arg::with_name("force")
        .short("f")
        .long("force")
        .help("overwrite existing output")
        .display_order(1);

    let quiet = Arg::with_name("quiet")
        .short("q")
        .long("quiet")
        .help("disables verbose")
        .display_order(1);

    let verbose = Arg::with_name("verbose")
        .short("v")
        .long("verbose")
        .help("output every command as it executes")
        .display_order(1);

    // ------------------------------------------------------------------------
    // put it all together
    // ------------------------------------------------------------------------

    App::new("archive")
        .version(crate_version!())
        .about(crate_description!())
        .global_setting(color)
        .help_short("?")
        .help_message("show this help output")
        .version_message("show version")
        .arg(input)
        .arg(output)
        .arg(dereference)
        .arg(force)
        .arg(quiet)
        .arg(verbose)
}

// ----------------------------------------------------------------------------
// argument validator
// ----------------------------------------------------------------------------

fn is_dir(s: String) -> Result<(), String> {
    let path = Path::new(&s);

    if !path.exists() {
        Err(format!("does not exist: {}", s))
    } else if !path.is_dir() {
        Err(format!("not a directory: {}", s))
    } else if let Err(error) = fs::read_dir(path) {
        Err(error.description().to_string())
    } else {
        Ok(())
    }
}

fn output_validator(s: String) -> Result<(), String> {
    if s.ends_with(".tar.gz") {
        Ok(())
    } else {
        Err(format!("must end in .tar.gz: {:?}", s))
    }
}
