use clap::Parser;
use serde_yaml::{Mapping, Value};
use std::future::Future;
use std::path::PathBuf;
use std::pin::Pin;
use std::process::Command;
use tokio::fs;
use tokio::io::ErrorKind;

/// A CLI tool to decrypt a SOPS file and create directories and files for each key in /run/secrets.
#[derive(Parser, Debug)]
#[clap(author, version, about, long_about = None)]
struct Args {
    /// Path to the SOPS file to decrypt.
    #[clap(value_parser)]
    sops_file_path: String,

    #[arg(short, long, default_value = "/run/secrets")]
    secret_path: String,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args = Args::parse();

    // Ensure secret path exists
    let base_path = PathBuf::from(args.secret_path);
    match fs::create_dir_all(&base_path).await {
        Ok(_) => {}
        Err(e) => match e.kind() {
            ErrorKind::PermissionDenied => {
                eprintln!("Error when trying to create {}: {}", base_path.display(), e);
                std::process::exit(1);
            }
            _ => eprintln!("{e}"),
        },
    }
    // Use `sops` to decrypt the file.
    let output = Command::new("sops")
        .arg("--decrypt")
        .arg(&args.sops_file_path)
        .output()?;

    if !output.status.success() {
        eprintln!(
            "Error decrypting SOPS file: {}",
            String::from_utf8_lossy(&output.stderr)
        );
        std::process::exit(1);
    }
    // TODO add json option

    // Parse the decrypted output as YAML.
    let decrypted_yaml: Value = serde_yaml::from_slice(&output.stdout)?;
    if let Value::Mapping(contents) = decrypted_yaml {
        process_yaml_boxed(contents, base_path).await?;
    } else {
        eprintln!("Decrypted content is not a YAML object.");
        std::process::exit(1);
    }

    Ok(())
}

fn process_yaml_boxed(
    contents: Mapping,
    base_path: PathBuf,
) -> Pin<Box<dyn Future<Output = Result<(), Box<dyn std::error::Error>>>>> {
    Box::pin(async move {
        for (key, value) in contents {
            if let Value::String(key_str) = key {
                let current_path = base_path.join(key_str.clone());
                match value {
                    Value::String(value_str) => {
                        // Write the value to a file named after the key.
                        fs::write(&current_path, value_str).await?;
                        println!("Secret written to: {}", current_path.display());
                    }
                    Value::Mapping(nested) => {
                        // If the value is a nested object, create a directory and process recursively.
                        fs::create_dir_all(&current_path).await?;
                        process_yaml_boxed(nested, current_path).await?;
                    }
                    _ => {
                        eprintln!("Unsupported value type for key: {}", key_str);
                    }
                }
            } else {
                eprintln!("Key is not a string.");
            }
        }

        Ok(())
    })
}
