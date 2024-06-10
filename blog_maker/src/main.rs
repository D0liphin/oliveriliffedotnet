//! I am pretty much using Rust as a scripting language here -- so don't think
//! that this is some example of high-quality, robust Rust code.

use std::{fs, io::Write, path::Path};

const TEMPLATE: &str = include_str!("template.html");

#[derive(Debug, Clone)]
struct NamedFile {
    name: String,
    contents: String,
}

fn all_files_with_ext(dir: impl AsRef<Path>, ext: &str) -> Vec<NamedFile> {
    let mut files = vec![];
    let entries = fs::read_dir(dir).unwrap();
    for entry in entries {
        let Ok(entry) = entry else {
            continue;
        };
        let path = entry.path();
        let Some(pathstr) = path.to_str() else {
            continue;
        };
        if !pathstr.ends_with(ext) {
            continue;
        }
        let Ok(contents) = fs::read_to_string(pathstr) else {
            continue;
        };
        files.push(NamedFile {
            name: pathstr.into(),
            contents,
        });
    }
    files
}

fn convert_to_html(md: &str) -> (String, String) {
    let lines = md.split('\n').collect::<Vec<_>>();
    let heading = String::from(
        lines
            .first()
            .expect("md contains a header")
            .trim_matches('#')
            .trim(),
    );
    let mut md = String::new();
    for line in &lines[1..] {
        md.push_str(line);
        md.push('\n');
    }
    (heading, markdown::to_html(&md))
}

fn convert_all() {
    let mut files = all_files_with_ext("../blog", "md");
    for file in files.iter_mut() {
        while let Some(ch) = file.name.chars().last() {
            file.name.pop();
            if ch == '.' {
                break;
            }
        }
        file.name.push_str(".html");
        let (title, html_body) = convert_to_html(&file.contents);
        let html = String::from(TEMPLATE);
        let html = html.replace("<!-- TITLE_GOES_HERE -->", &title);
        let html = html.replace("<!-- BODY_GOES_HERE -->", &html_body);
        let mut f = fs::File::create(&file.name).unwrap();
        f.write_all(html.as_bytes()).unwrap();
        println!("Created {}", file.name);
    }
}

fn main() {
    convert_all();
}
