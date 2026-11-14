use chrono::Local;
use glib::ControlFlow;
use gtk4::prelude::*;
use gtk4::{Application, ApplicationWindow, Box as GtkBox, CssProvider, Label, Orientation};
use gtk4_layer_shell::{Layer, LayerShell};
use std::cell::RefCell;
use std::fs;
use std::rc::Rc;
use std::time::Duration;

const APP_ID: &str = "com.whrr.ClockOverlay";

#[derive(Clone, PartialEq)]
struct ClockConfig {
    opacity: f64,
    day_size: i32,
    date_size: i32,
    time_size: i32,
    spacing: i32,
    pos_x: i32,
    pos_y: i32,
    shadow: f64,
    r: u8,
    g: u8,
    b: u8,
    is_24h: bool,
    show_seconds: bool,
    show_date: bool,
    show_weekday: bool,
}

impl Default for ClockConfig {
    fn default() -> Self {
        Self {
            opacity: 0.45,
            day_size: 63,
            date_size: 14,
            time_size: 15,
            spacing: 12,
            pos_x: 0,
            pos_y: 450,
            shadow: 0.30,
            r: 255,
            g: 255,
            b: 255,
            is_24h: true,
            show_seconds: false,
            show_date: true,
            show_weekday: true,
        }
    }
}

fn style_conf_path() -> String {
    let home = std::env::var("HOME").unwrap_or_else(|_| String::from("/root"));
    format!("{}/.config/hypr/scripts/clock_style.conf", home)
}

fn parse_bool(val: &str, def: bool) -> bool {
    match val {
        "1" | "true" | "True" | "yes" => true,
        "0" | "false" | "False" | "no" => false,
        _ => def,
    }
}

fn read_clock_config() -> ClockConfig {
    let mut cfg = ClockConfig::default();
    if let Ok(text) = fs::read_to_string(style_conf_path()) {
        for line in text.lines() {
            if let Some((k, v)) = line.split_once('=') {
                let val = v.trim();
                match k.trim() {
                    "opacity" => cfg.opacity = val.parse::<f64>().unwrap_or(0.45).clamp(0.05, 1.0),
                    "size" | "day_size" => cfg.day_size = val.parse::<f64>().unwrap_or(63.0).round() as i32,
                    "date_size" => cfg.date_size = val.parse::<f64>().unwrap_or(14.0).round() as i32,
                    "time_size" => cfg.time_size = val.parse::<f64>().unwrap_or(15.0).round() as i32,
                    "letter_spacing" => cfg.spacing = val.parse::<f64>().unwrap_or(12.0).round() as i32,
                    "pos_x" => cfg.pos_x = val.parse::<f64>().unwrap_or(0.0).round() as i32,
                    "pos_y" => cfg.pos_y = val.parse::<f64>().unwrap_or(450.0).round() as i32,
                    "shadow_alpha" => cfg.shadow = val.parse::<f64>().unwrap_or(0.30).clamp(0.0, 1.0),
                    "color_r" => cfg.r = val.parse::<f64>().unwrap_or(255.0).round() as u8,
                    "color_g" => cfg.g = val.parse::<f64>().unwrap_or(255.0).round() as u8,
                    "color_b" => cfg.b = val.parse::<f64>().unwrap_or(255.0).round() as u8,
                    "is_24h" => cfg.is_24h = parse_bool(val, true),
                    "show_seconds" => cfg.show_seconds = parse_bool(val, false),
                    "show_date" => cfg.show_date = parse_bool(val, true),
                    "show_weekday" => cfg.show_weekday = parse_bool(val, true),
                    _ => {}
                }
            }
        }
    }
    cfg
}

fn build_clock_css(cfg: &ClockConfig) -> String {
    let (ml, mr) = if cfg.pos_x >= 0 { (cfg.pos_x, 0) } else { (0, -cfg.pos_x) };
    let (mb, mt) = if cfg.pos_y >= 0 { (cfg.pos_y, 0) } else { (0, -cfg.pos_y) };

    format!(
        "window {{ background-color: transparent; }}
         .main-box {{ margin-left: {}px; margin-right: {}px; margin-top: {}px; margin-bottom: {}px; }}
         .day-label {{ font-family: 'Anurati', 'Blanka', sans-serif; font-size: {}px; font-weight: bold; color: rgba({}, {}, {}, {:.2}); letter-spacing: {}px; text-shadow: 0px 4px 10px rgba(0,0,0,{:.2}); }}
         .date-label {{ font-family: sans-serif; font-size: {}px; font-weight: bold; color: rgba({}, {}, {}, {:.2}); margin-top: 8px; letter-spacing: 2px; text-shadow: 0px 2px 5px rgba(0,0,0,{:.2}); }}
         .time-label {{ font-family: sans-serif; font-size: {}px; font-weight: bold; color: rgba({}, {}, {}, {:.2}); margin-top: 8px; letter-spacing: 3px; text-shadow: 0px 2px 5px rgba(0,0,0,{:.2}); }}",
        ml, mr, mt, mb,
        cfg.day_size, cfg.r, cfg.g, cfg.b, cfg.opacity, cfg.spacing, cfg.shadow,
        cfg.date_size, cfg.r, cfg.g, cfg.b, cfg.opacity, cfg.shadow,
        cfg.time_size, cfg.r, cfg.g, cfg.b, cfg.opacity, cfg.shadow
    )
}

fn refresh_labels(day_label: &Label, date_label: &Label, time_label: &Label, cfg: &ClockConfig) {
    let now = Local::now();
    day_label.set_visible(cfg.show_weekday);
    date_label.set_visible(cfg.show_date);

    day_label.set_text(&now.format("%A").to_string().to_uppercase());
    date_label.set_text(&now.format("%d %B, %Y.").to_string().to_uppercase());

    let fmt = match (cfg.is_24h, cfg.show_seconds) {
        (true, true) => "- %H:%M:%S -",
        (true, false) => "- %H:%M -",
        (false, true) => "- %I:%M:%S %p -",
        (false, false) => "- %I:%M %p -",
    };
    time_label.set_text(&now.format(fmt).to_string());
}

fn main() {
    let app = Application::builder().application_id(APP_ID).build();
    app.connect_activate(build_ui);
    app.run();
}

fn build_ui(app: &Application) {
    let window = ApplicationWindow::builder().application(app).title("Clock").build();

    window.init_layer_shell();
    window.set_layer(Layer::Bottom);
    window.set_namespace(Some("clock_overlay"));

    let vbox = GtkBox::new(Orientation::Vertical, 0);
    vbox.set_valign(gtk4::Align::Center);
    vbox.set_halign(gtk4::Align::Center);
    vbox.add_css_class("main-box");

    let day_label = Label::new(None);
    day_label.add_css_class("day-label");

    let date_label = Label::new(None);
    date_label.add_css_class("date-label");

    let time_label = Label::new(None);
    time_label.add_css_class("time-label");

    vbox.append(&day_label);
    vbox.append(&date_label);
    vbox.append(&time_label);
    window.set_child(Some(&vbox));

    let current_cfg = Rc::new(RefCell::new(read_clock_config()));
    let css_provider = CssProvider::new();
    css_provider.load_from_data(&build_clock_css(&current_cfg.borrow()));

    gtk4::style_context_add_provider_for_display(
        &gtk4::gdk::Display::default().expect("Could not connect to a display."),
        &css_provider,
        gtk4::STYLE_PROVIDER_PRIORITY_APPLICATION,
    );

    refresh_labels(&day_label, &date_label, &time_label, &current_cfg.borrow());

    let last_raw = Rc::new(RefCell::new(
        fs::read_to_string(style_conf_path()).unwrap_or_default(),
    ));
    let provider_clone = css_provider.clone();
    let cfg_clone = current_cfg.clone();
    let d_lbl = day_label.clone();
    let dt_lbl = date_label.clone();
    let t_lbl = time_label.clone();

    glib::timeout_add_local(Duration::from_millis(80), move || {
        let raw = fs::read_to_string(style_conf_path()).unwrap_or_default();
        if raw != *last_raw.borrow() {
            *last_raw.borrow_mut() = raw;
            let new_cfg = read_clock_config();
            provider_clone.load_from_data(&build_clock_css(&new_cfg));
            refresh_labels(&d_lbl, &dt_lbl, &t_lbl, &new_cfg);
            *cfg_clone.borrow_mut() = new_cfg;
        }
        ControlFlow::Continue
    });

    let cfg_for_tick = current_cfg.clone();
    glib::timeout_add_seconds_local(1, move || {
        refresh_labels(&day_label, &date_label, &time_label, &cfg_for_tick.borrow());
        ControlFlow::Continue
    });

    window.present();
}
