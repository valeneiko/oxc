use std::{env, path::Path};

use ignore::gitignore::Gitignore;
use oxc_allocator::Allocator;
use oxc_parser::Parser;
use oxc_span::{SourceType, VALID_EXTENSIONS};
use rayon::prelude::{IntoParallelRefIterator, ParallelIterator};

use crate::{
    command::FormatOptions,
    result::{CliRunResult, ParseResult},
    walk::{Extensions, Walk},
    Runner,
};

pub struct ParseRunner {
    options: FormatOptions,
}

impl Runner for ParseRunner {
    type Options = FormatOptions;

    fn new(options: Self::Options) -> Self {
        Self { options }
    }

    fn run(self) -> CliRunResult {
        let FormatOptions { paths, ignore_options, .. } = self.options;

        let mut paths = paths;

        // The ignore crate whitelists explicit paths, but priority
        // should be given to the ignore file. Many users lint
        // automatically and pass a list of changed files explicitly.
        // To accommodate this, unless `--no-ignore` is passed,
        // pre-filter the paths.
        if !paths.is_empty() && !ignore_options.no_ignore {
            let (ignore, _err) = Gitignore::new(&ignore_options.ignore_path);
            paths.retain(|p| if p.is_dir() { true } else { !ignore.matched(p, false).is_ignore() });
        }

        if paths.is_empty() {
            if let Ok(cwd) = env::current_dir() {
                paths.push(cwd);
            } else {
                return CliRunResult::InvalidOptions {
                    message: "Failed to get current working directory.".to_string(),
                };
            }
        }

        let extensions = VALID_EXTENSIONS.to_vec();

        let now = std::time::Instant::now();

        let paths =
            Walk::new(&paths, &ignore_options).with_extensions(Extensions(extensions)).paths();

        let total_duration = paths.par_iter().map(|path| Self::parse(path)).sum();

        CliRunResult::ParseResult(ParseResult {
            parse_duration: total_duration,
            duration: now.elapsed(),
            number_of_files: paths.len(),
        })
    }
}

impl ParseRunner {
    fn parse(path: &Path) -> std::time::Duration {
        let source_text = std::fs::read_to_string(path).unwrap();
        let allocator = Allocator::default();
        let source_type = SourceType::from_path(path).unwrap();
        let now = std::time::Instant::now();
        let _ = Parser::new(&allocator, &source_text, source_type).preserve_parens(false).parse();
        now.elapsed()
    }
}
