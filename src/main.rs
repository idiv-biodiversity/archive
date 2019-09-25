mod cli;

use archive_sum::Result;
use clap::{crate_name, crate_version};
use libarchive::Archive;
use openssl::hash::{Hasher, MessageDigest};
use std::error::Error;
use std::fs::{File, OpenOptions};
use std::io::Write;
use std::path::{Path, PathBuf};

fn main() {
    let args = cli::build().get_matches();

    let input = args.value_of("input").unwrap();
    let input = Path::new(input).to_path_buf();

    let output = args
        .value_of("output")
        .map_or(input.with_extension("tar.gz"), |path| {
            Path::new(path).to_path_buf()
        });

    let force = args.is_present("force");

    if output.exists() && !force {
        eprintln!("{}: error: output already exists", crate_name!());
        std::process::exit(1);
    }

    let dereference = args.is_present("dereference");

    let last_quiet = args.indices_of("quiet").map(|indeces| indeces.last());
    let last_verbose =
        args.indices_of("verbose").map(|indeces| indeces.last());

    let out: Box<dyn Write> = match (last_quiet, last_verbose) {
        (Some(quiet), Some(verbose)) if quiet > verbose => {
            Box::new(std::io::sink())
        }
        (_, Some(_)) => Box::new(std::io::stdout()),
        _ => Box::new(std::io::sink()),
    };

    let result = run(input, output, dereference, out, std::io::stderr());

    if let Err(error) = result {
        eprintln!("{}: error: {}", crate_name!(), error.description());
        std::process::exit(1);
    }
}

// TODO sort order name! instead of inode
fn run(
    input: PathBuf,
    output: PathBuf,
    dereference: bool,
    mut out: impl Write,
    err: impl Write,
) -> Result<bool> {
    let digest = MessageDigest::md5();

    let output_file_name = output.file_name().unwrap().to_str().unwrap();
    let digest_file = output
        .parent()
        .unwrap()
        .join(format!("{}.md5", output_file_name));

    // TODO remove when my own dir walker?
    let parent_dir = input.parent().unwrap();
    std::env::set_current_dir(parent_dir)?;

    let cwd = std::env::current_dir()?;
    writeln!(out, "{} {}", crate_name!(), crate_version!())?;
    writeln!(out, "wd: {}", cwd.display())?;
    writeln!(out, "input: {}", input.display())?;
    writeln!(out, "output: {}", output.display())?;
    writeln!(out)?;

    // tar czf | tee >(md5sum) > output

    // TODO jetzt fehlt nur noch gzip!!!
    let hash_streamer = HashStreamer::new(&output, digest)?;

    let mut archive = tar::Builder::new(hash_streamer);
    archive.follow_symlinks(dereference);
    archive.mode(tar::HeaderMode::Deterministic);

    let input_name = input.file_name().unwrap();

    archive.append_dir_all(&input.file_name().unwrap(), input_name)?;

    // sync everything to disk before we continue with archive-sum
    archive.into_inner()?.finish()?;

    // archive-sum -c --append output.md5 output

    let archive = Archive::open(output)?;

    let digest_file = OpenOptions::new()
        .create(true)
        .append(true)
        .open(digest_file)?;

    archive_sum::verify(
        archive,
        digest,
        Some(input.parent().unwrap().to_path_buf()),
        digest_file,
        out,
        err,
    )
}

struct HashStreamer {
    output: File,
    output_file_name: String,
    digest: File,
    hasher: Hasher,
}

impl HashStreamer {
    fn new<P: AsRef<Path>>(
        output: P,
        digest: MessageDigest,
    ) -> Result<HashStreamer> {
        let hasher = Hasher::new(digest)?;

        let output = output.as_ref();
        let output_file_name = output.file_name().unwrap().to_str().unwrap();

        let archive = File::create(output)?;

        let digest = output
            .parent()
            .unwrap()
            .join(format!("{}.md5", output_file_name));

        let digest = File::create(digest)?;

        let hash_streamer = HashStreamer {
            output: archive,
            output_file_name: String::from(output_file_name),
            digest,
            hasher,
        };

        Ok(hash_streamer)
    }

    fn finish(&mut self) -> Result<()> {
        let hash = self.hasher.finish()?;
        let hash: String =
            hash.iter().map(|byte| format!("{:02x}", byte)).collect();

        writeln!(self.digest, "{}  {}", hash, self.output_file_name)?;

        Ok(())
    }
}

impl Write for HashStreamer {
    fn write(&mut self, buf: &[u8]) -> std::io::Result<usize> {
        self.hasher.update(buf)?;
        self.output.write(buf)
    }

    fn flush(&mut self) -> std::io::Result<()> {
        self.output.flush()
    }
}
