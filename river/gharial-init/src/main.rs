//! River's executable init for the typed gharial desktop policy.

mod desktop;

use std::env;
use std::process::{self, Child, Command, ExitStatus, Stdio};
use std::time::Duration;

use gharial_ipc::Client;

fn main() {
    if let Err(error) = run() {
        eprintln!("gharial-init-rs: {error}");
        process::exit(1);
    }
}

fn run() -> Result<(), String> {
    set_session_environment();
    propagate_environment();

    let client = Client::new();
    let mut daemon = Daemon::spawn()?;
    client
        .wait_until_ready(Duration::from_secs(5))
        .map_err(|error| error.to_string())?;

    desktop::configure(&client)?;

    daemon
        .wait()
        .map(|_| ())
        .map_err(|error| format!("failed waiting for gharial: {error}"))
}

fn set_session_environment() {
    env::set_var("XDG_CURRENT_DESKTOP", "river");
    env::set_var("XDG_SESSION_TYPE", "wayland");
}

fn propagate_environment() {
    let vars = [
        "WAYLAND_DISPLAY",
        "XDG_CURRENT_DESKTOP",
        "XDG_SESSION_TYPE",
        "FONT",
    ];
    let _ = Command::new("dbus-update-activation-environment")
        .arg("--systemd")
        .args(vars)
        .status();
    let _ = Command::new("systemctl")
        .args(["--user", "import-environment"])
        .args(vars)
        .status();
}

struct Daemon(Option<Child>);

impl Daemon {
    fn spawn() -> Result<Self, String> {
        let daemon = env::var_os("GHARIAL_DAEMON")
            .ok_or_else(|| "GHARIAL_DAEMON is not set by the River launcher".to_string())?;

        Command::new(daemon)
            .stdin(Stdio::null())
            .stdout(Stdio::inherit())
            .stderr(Stdio::inherit())
            .spawn()
            .map(|child| Self(Some(child)))
            .map_err(|error| format!("failed to start gharial: {error}"))
    }

    fn wait(&mut self) -> std::io::Result<ExitStatus> {
        self.0
            .take()
            .expect("daemon child is present until wait")
            .wait()
    }
}

impl Drop for Daemon {
    fn drop(&mut self) {
        let Some(child) = self.0.as_mut() else {
            return;
        };

        let _ = child.kill();
        let _ = child.wait();
    }
}
