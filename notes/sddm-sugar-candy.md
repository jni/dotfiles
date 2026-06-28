# Switching the login greeter to SDDM + Sugar Candy

Future-me notes. Current setup (2026-06): Pop!_OS 24.04 LTS, login handled by
**cosmic-greeter** (greetd). Both `cosmic.desktop` and `sway.desktop` live in
`/usr/share/wayland-sessions/`, so any greeter that reads that folder offers
both desktops automatically.

Repo SDDM is **0.20.0 (Qt5, X11 greeter)**. That's fine: Xorg is already
installed, and an X11 *greeter* launching a Wayland *session* (COSMIC/Sway) has
no effect on the session you log into. The Wayland greeter needs SDDM >= 0.21,
which is NOT in the 24.04 repos — see "Wayland greeter" at the bottom.

## 1. Install SDDM + Sugar Candy's QML deps

```bash
sudo apt install sddm \
    qml-module-qtgraphicaleffects \
    qml-module-qtquick-controls2 \
    qml-module-qtquick2
```

Do NOT let this auto-switch the display manager yet — if apt/debconf asks which
display manager to use, you can pick sddm, but the explicit switch is in step 5
so it's reversible.

## 2. Get the Sugar Candy theme

The original (Marian Arlt) was removed from its old host; use a current mirror/
fork. Verify the URL is alive before cloning.

```bash
# maintained fork that tracks current SDDM:
sudo git clone https://github.com/Kangie/sddm-sugar-candy.git \
    /usr/share/sddm/themes/sugar-candy
```

(Alternatives if that 404s: search "sddm sugar candy" — there are several
mirrors; any copy with a `Main.qml` + `theme.conf` dropped into
`/usr/share/sddm/themes/sugar-candy/` works.)

## 3. Select the theme

```bash
sudo install -d /etc/sddm.conf.d
printf '[Theme]\nCurrent=sugar-candy\n' | sudo tee /etc/sddm.conf.d/theme.conf
```

## 4. Configure Sugar Candy

Don't edit the theme's `theme.conf` directly (a theme update clobbers it).
Sugar Candy reads `theme.conf.user` as an override:

```bash
sudo cp /usr/share/sddm/themes/sugar-candy/theme.conf \
        /usr/share/sddm/themes/sugar-candy/theme.conf.user
sudo $EDITOR /usr/share/sddm/themes/sugar-candy/theme.conf.user
```

Good starting values (keeps it consistent with the Sway desktop wallpaper):

```ini
[General]
Background="/usr/share/backgrounds/cosmic/orion_nebula_nasa_heic0601a.jpg"
ScreenWidth="1920"          # match your panel; only used for the blur preview
ScreenHeight="1080"
DimBackgroundImage="0.2"
ScaleImageCropped="true"
FullBlur="false"            # true = blur whole screen; false = partial behind card
PartialBlur="true"
BlurRadius="40"
HaveFormBackground="true"
FormPosition="center"       # left | center | right
MainColor="white"
AccentColor="#7c5cbf"       # matches the swaylock ring purple
BackgroundColor="#1e1e2e"
Font="DejaVu Sans Mono"
HourFormat="HH:mm"
DateFormat="dddd, d MMMM"
```

## 5. Switch from cosmic-greeter to SDDM (reversible)

Only one `display-manager.service` is active at a time.

```bash
sudo systemctl disable --now cosmic-greeter
sudo systemctl enable sddm          # don't --now from inside a graphical session
```

Then reboot (cleanest) or, from a TTY (Ctrl+Alt+F3), `sudo systemctl start sddm`.

At the SDDM screen there's a **session selector** (dropdown, usually
bottom-left) listing COSMIC and Sway. SDDM remembers the last choice per user.

### Rollback
```bash
sudo systemctl disable --now sddm
sudo systemctl enable --now cosmic-greeter
```
(Keep `cosmic-greeter` installed as the fallback.)

## Wayland greeter (SDDM >= 0.21) — and the dist-upgrade question

The 0.20 greeter runs on X11. To get the native **Wayland** greeter you need
SDDM >= 0.21, which Pop!_OS 24.04 does NOT ship. Getting it would mean building
0.21+ from source (Qt6) — i.e. self-maintaining a core login component on an
LTS. Not worth it just so the *login screen* is Wayland; it changes nothing
about your actual sessions.

Do NOT dist-upgrade for this. This is **Pop!_OS**, not Ubuntu — it upgrades via
System76's path (`pop-upgrade` / System76 repos), not by pointing apt at a newer
Ubuntu (that would break COSMIC, drivers, and pins). 24.04 is the current
COSMIC LTS; there's nowhere newer to go right now that hands you SDDM 0.21.

If a future Pop!_OS release ships SDDM >= 0.21 through normal updates, revisit:
```ini
# /etc/sddm.conf.d/wayland.conf   (0.21+ only)
[General]
DisplayServer=wayland
[Wayland]
CompositorCommand=weston --shell=fullscreen-shell.so   # weston is in the repos
```
and use a Qt6 build of Sugar Candy. Until then, stay on the 0.20 X11 greeter.

If you specifically want a *pure-Wayland* greeter NOW without an OS upgrade, the
proportionate move is to stay on greetd (already installed) and use ReGreet
(GTK, wallpaper) or tuigreet — not to chase SDDM 0.21.
