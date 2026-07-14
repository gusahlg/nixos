//! Minimal per-output tag and clock bar for Gharial, rendered with Meander.

use std::collections::HashMap;
use std::process::ExitCode;
use std::time::{Duration, Instant};

use chrono::Local;
use meander::{Anchor, App, Color, Event, Font, Layer, SurfaceId};
use meander_gharial::{Gharial, Response};

const BAR_HEIGHT: u32 = 26;
const FONT_SIZE: f32 = 13.0;
const PAD: f32 = 7.0;
const TAG_WIDTH: f32 = 24.0;
const TAG_COUNT: u32 = 10;
const POLL_INTERVAL: Duration = Duration::from_millis(100);

const BACKGROUND: Color = Color::hex(0x0F0F0FFF);
const FOREGROUND: Color = Color::hex(0xD8DEE9FF);
const INACTIVE: Color = Color::hex(0x606778FF);
const ACTIVE_BACKGROUND: Color = Color::hex(0xC8324BFF);

#[derive(Debug)]
struct Bar {
    surface: SurfaceId,
    output_name: String,
    configured: bool,
    dirty: bool,
    closed: bool,
    last_draw_error: Option<String>,
}

#[derive(Clone, Debug, Default, PartialEq, Eq)]
struct OutputTags {
    by_name: HashMap<String, u32>,
    focused: Option<String>,
}

impl OutputTags {
    fn for_output(&self, name: &str) -> u32 {
        self.by_name
            .get(name)
            .copied()
            .or_else(|| {
                self.focused
                    .as_ref()
                    .and_then(|focused| self.by_name.get(focused).copied())
            })
            .or_else(|| self.by_name.values().next().copied())
            .unwrap_or(1)
    }
}

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("meander-bar: {error}");
            ExitCode::FAILURE
        }
    }
}

fn run() -> Result<(), Box<dyn std::error::Error>> {
    let font_path = std::env::var("MEANDER_BAR_FONT").map_err(|_| "MEANDER_BAR_FONT is not set")?;
    let font = Font::from_file(&font_path)
        .map_err(|error| format!("could not load font {font_path}: {error}"))?;

    let mut app = App::connect()?;
    let outputs = app.outputs();
    let mut bars = Vec::new();

    if outputs.is_empty() {
        let surface = build_bar(&mut app, None)?;
        bars.push(new_bar(surface, "1".into()));
    } else {
        for (index, output) in outputs.into_iter().enumerate() {
            let name = output.name.unwrap_or_else(|| (index + 1).to_string());
            let surface = build_bar(&mut app, Some(output.id))?;
            bars.push(new_bar(surface, name));
        }
    }

    let gharial =
        Gharial::connect().map_err(|error| format!("could not reach Gharial: {error}"))?;
    let mut output_tags = fetch_output_tags(&gharial).unwrap_or_default();
    let mut clock = local_time();
    let mut next_poll = Instant::now();
    let mut last_poll_error: Option<String> = None;

    loop {
        while let Some(event) = app.next_event() {
            match event {
                Event::Configure { surface, .. } => {
                    if let Some(bar) = bars.iter_mut().find(|bar| bar.surface == surface) {
                        bar.configured = true;
                        bar.dirty = true;
                    }
                }
                Event::Closed { surface, .. } => {
                    if let Some(bar) = bars.iter_mut().find(|bar| bar.surface == surface) {
                        bar.closed = true;
                    }
                    if bars.iter().all(|bar| bar.closed) {
                        return Ok(());
                    }
                }
                _ => {}
            }
        }

        let now = Instant::now();
        if now >= next_poll {
            next_poll = now + POLL_INTERVAL;
            match fetch_output_tags(&gharial) {
                Ok(latest) => {
                    if latest != output_tags {
                        output_tags = latest;
                        mark_all_dirty(&mut bars);
                    }
                    last_poll_error = None;
                }
                Err(error) => {
                    if last_poll_error.as_deref() != Some(&error) {
                        eprintln!("meander-bar: could not refresh outputs: {error}");
                        last_poll_error = Some(error);
                    }
                }
            }
        }

        let latest_clock = local_time();
        if latest_clock != clock {
            clock = latest_clock;
            mark_all_dirty(&mut bars);
        }

        for bar in bars
            .iter_mut()
            .filter(|bar| !bar.closed && bar.configured && bar.dirty)
        {
            let active_tags = output_tags.for_output(&bar.output_name);
            match app
                .surface(bar.surface)
                .draw(|canvas| draw_bar(canvas, &font, active_tags, &clock))
            {
                Ok(()) => {
                    bar.dirty = false;
                    bar.last_draw_error = None;
                }
                Err(error) => {
                    // NotConfigured and BuffersBusy are transient in current
                    // Meander versions. Keeping the surface dirty makes the
                    // next dispatch tick retry without exiting the session.
                    let message = error.to_string();
                    if bar.last_draw_error.as_deref() != Some(&message) {
                        eprintln!(
                            "meander-bar: draw failed on {} (will retry): {message}",
                            bar.output_name
                        );
                        bar.last_draw_error = Some(message);
                    }
                }
            }
        }

        app.flush()?;
        app.dispatch(Some(POLL_INTERVAL))?;
    }
}

fn build_bar(
    app: &mut App,
    output: Option<meander::OutputId>,
) -> Result<SurfaceId, meander::Error> {
    let builder = app
        .layer_surface()
        .namespace("gharial.meander-bar")
        .layer(Layer::Top)
        .anchor(Anchor::TOP | Anchor::LEFT | Anchor::RIGHT)
        .size(0, BAR_HEIGHT)
        .exclusive_zone(BAR_HEIGHT as i32);
    match output {
        Some(output) => builder.output(output).build(),
        None => builder.build(),
    }
}

fn new_bar(surface: SurfaceId, output_name: String) -> Bar {
    Bar {
        surface,
        output_name,
        configured: false,
        dirty: false,
        closed: false,
        last_draw_error: None,
    }
}

fn mark_all_dirty(bars: &mut [Bar]) {
    for bar in bars {
        bar.dirty = true;
    }
}

fn local_time() -> String {
    Local::now().format("%H:%M").to_string()
}

fn fetch_output_tags(gharial: &Gharial) -> Result<OutputTags, String> {
    match gharial
        .request("output", &["list"])
        .map_err(|error| error.to_string())?
    {
        Response::Ok(body) => Ok(parse_output_list(&body)),
        Response::Err(error) => Err(error),
    }
}

fn parse_output_list(body: &str) -> OutputTags {
    let mut result = OutputTags::default();
    for entry in body.split(';').map(str::trim) {
        if entry.is_empty() || entry == "no outputs" || entry.starts_with("link ") {
            continue;
        }
        let mut fields = entry.split_whitespace();
        let Some(name) = fields.next() else {
            continue;
        };
        let fields: Vec<&str> = fields.collect();
        let Some(tags) = fields
            .iter()
            .find_map(|field| field.strip_prefix("tags="))
            .and_then(parse_tag_mask)
        else {
            continue;
        };
        result.by_name.insert(name.to_string(), tags);
        if fields.contains(&"focused") {
            result.focused = Some(name.to_string());
        }
    }
    result
}

fn parse_tag_mask(value: &str) -> Option<u32> {
    value
        .strip_prefix("0x")
        .or_else(|| value.strip_prefix("0X"))
        .map(|hex| u32::from_str_radix(hex, 16).ok())
        .unwrap_or_else(|| value.parse().ok())
}

fn draw_bar(canvas: &mut meander::Canvas<'_>, font: &Font, active_tags: u32, clock: &str) {
    let scale = canvas.scale().max(1) as f32;
    let width = canvas.width() as f32;
    let height = canvas.height() as f32;
    let font_size = FONT_SIZE * scale;
    let baseline = (height + font_size) / 2.0 - 2.0 * scale;

    canvas.fill(BACKGROUND);

    let mut x = PAD * scale;
    let cell_width = TAG_WIDTH * scale;
    let cell_height = height - 6.0 * scale;
    let y = 3.0 * scale;
    for tag in 1..=TAG_COUNT {
        let active = active_tags & (1 << (tag - 1)) != 0;
        if active {
            canvas.rounded_rect(
                x,
                y,
                cell_width,
                cell_height,
                3.0 * scale,
                ACTIVE_BACKGROUND,
            );
        }
        let label = tag.to_string();
        let label_width = canvas.text_width(&label, font_size, font);
        canvas.text(
            &label,
            x + (cell_width - label_width) / 2.0,
            baseline,
            font_size,
            if active { FOREGROUND } else { INACTIVE },
            font,
        );
        x += cell_width + 2.0 * scale;
    }

    let clock_width = canvas.text_width(clock, font_size, font);
    canvas.text(
        clock,
        (width - clock_width - PAD * scale).max(PAD * scale),
        baseline,
        font_size,
        FOREGROUND,
        font,
    );
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_each_outputs_tag_mask_and_focus() {
        let parsed = parse_output_list(
            "DP-2 2560x1440+0+0 tags=0x00000005 focused; \
             HDMI-A-1 1920x1080+-1920+0 tags=0x00000002; \
             link DP-2:left<->HDMI-A-1:right",
        );
        assert_eq!(parsed.by_name.get("DP-2"), Some(&0x5));
        assert_eq!(parsed.by_name.get("HDMI-A-1"), Some(&0x2));
        assert_eq!(parsed.focused.as_deref(), Some("DP-2"));
    }

    #[test]
    fn ignores_empty_and_malformed_entries() {
        assert_eq!(parse_output_list("no outputs"), OutputTags::default());
        let parsed = parse_output_list("DP-1 missing-tags; ; link A:left<->B:right");
        assert_eq!(parsed, OutputTags::default());
    }

    #[test]
    fn output_lookup_prefers_the_matching_monitor() {
        let parsed = parse_output_list("DP-1 1x1+0+0 tags=0x1 focused; DP-2 1x1+1+0 tags=0x4");
        assert_eq!(parsed.for_output("DP-2"), 0x4);
        assert_eq!(parsed.for_output("unknown"), 0x1);
    }
}
