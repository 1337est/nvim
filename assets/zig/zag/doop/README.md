# doop: Windows clipboard server, Linux client

Single-file implementation targeting Zig 0.17.x. No third-party packages, libc,
clipboard helper executables, build.zig, or package manifest. The Windows binary
uses the operating system's user32/kernel32 libraries; networking uses std.Io.
SSH is the existing transport, not a library dependency of this executable.

## Verification status

Verified November 17, 2026.

- Windows 11: Zig 0.17.1, 5/5 unit tests passed.
- Linux aarch64: Zig 0.17.0, 5/5 unit tests passed.
- Windows clipboard server: ping, copy, and paste verified.
- SSH RemoteForward: verified using port 2489.
- Linux-to-Windows clipboard: verified.
- Windows-to-Linux clipboard: verified.
- UTF-8 Unicode and multiline round-trip: passed.
- Neovim clipboard provider: copy, paste, and checkhealth verified.

The implementation is operational for interactive SSH sessions.
Long-running reliability and concurrent-client stress testing
have not yet been performed.

## Scope

Run the server on the Windows desktop where you are logged in, and SSH from
Windows into Linux with a reverse TCP forward. Linux `copy` writes the Windows
clipboard; Linux `paste` reads its current contents. Native Windows application
copy/paste continues to use that same clipboard. No Linux server is required.

This does not synchronize a separate Linux GUI clipboard automatically. A Linux
application must invoke this client (for example, through the Neovim provider
below). The Windows server is a foreground user-session application, not a
Windows service.

This uses a new, deliberately small protocol. BOTH ends must use this source;
it is not wire-compatible with Go Lemonade. Commands provided: server, copy,
paste, ping, help. Not included: open, TOML configuration, automatic server
fallback, Go-compatible flags, images, file-list clipboard formats, or HTML.

Text is UTF-8 on the wire and in stdin/stdout; Windows storage is native UTF-16.
Copy normalizes line endings to CRLF; paste normalizes them to LF. It does not
add a final newline. Embedded NUL and invalid UTF-8 are rejected. Payloads are
limited to 8 MiB. Empty text clears the text clipboard; copying text replaces
other clipboard formats. Reading an empty/non-text clipboard returns empty text.

## Test alongside your current Lemonade

The executable defaults to port 2489, but these instructions use 24890 so you can
leave an existing Go Lemonade installation on 2489 alone. All client and server
commands in the test must use the same test port.

### 1. Windows build and server

Put doop.zig in a working directory. In PowerShell there:

```powershell
zig version
zig test .\doop.zig
zig build-exe .\doop.zig -Osafe -luser32 -lkernel32
.\doop.exe --port 24890 server
```

Use Zig 0.17.x. Leave this PowerShell window running. Stop with Ctrl+C. Do not
run as a Windows service or a different user's desktop session.

From a SECOND PowerShell window in the same directory:

```powershell
.\doop.exe --port 24890 ping
.\doop.exe --port 24890 copy "Local Windows test"
.\doop.exe --port 24890 paste
```

Expected ping output: `pong`. Expected paste output: `Local Windows test`.
Pasting into Notepad should produce that same text. These live copy tests
replace your current clipboard contents. `paste` emits no extra final newline,
so the next terminal prompt may appear on the same line.

### 2. Linux build

Copy the SAME doop.zig file to Linux. In its directory:

```bash
zig version
zig test doop.zig
zig build-exe doop.zig -Osafe
install -Dm755 doop "$HOME/.local/bin/doop"
export PATH="$HOME/.local/bin:$PATH"
```

No wl-copy, wl-paste, xclip, xsel, Go, or Linux desktop session is needed.

### 3. Windows SSH configuration

Edit `%USERPROFILE%\.ssh\config` (normally `$HOME\.ssh\config` in PowerShell).
Add the following settings INSIDE your existing Linux Host block; preserve
its HostName, User, IdentityFile and other existing settings. Replace the alias
shown here with your actual existing alias; do not add a second conflicting
block blindly.

```sshconfig
Host your-existing-linux-alias
    # Keep your current HostName, User, IdentityFile, etc.
    RemoteForward 127.0.0.1:24890 127.0.0.1:24890
    ExitOnForwardFailure yes
    ServerAliveInterval 30
    ServerAliveCountMax 3
```

Reconnect from Windows:

```powershell
ssh your-existing-linux-alias
```

This is REMOTE forwarding, not LocalForward:

    Linux 127.0.0.1:24890 -> SSH tunnel -> Windows 127.0.0.1:24890

Only one independent SSH connection can bind a given remote listening port at
a time. Close an old forwarding session before starting another for that port.
An existing forward on 2489 may also conflict if you open another SSH session
that requests that same old forward; remove duplicate sessions rather than
ignoring a forwarding error.

The Linux sshd must permit TCP forwarding. Keep its GatewayPorts setting at
`no` (the usual default), or use `clientspecified` with this explicit loopback
bind; do not use `yes`, which can force exposure on wildcard addresses. On Linux,
you can inspect the actual listening address with:

```bash
ss -ltn 'sport = :24890'
```

It should be loopback, not 0.0.0.0 or [::]. No public clipboard port or Windows
inbound network firewall exception is needed for this loopback tunnel design.

### 4. Live cross-machine tests

From the Linux shell reached through that SSH connection:

```bash
doop --port 24890 ping
printf 'Copied on Linux\n' | doop --port 24890 copy
```

Expected ping output: `pong`. Now paste into a Windows application. You should
see `Copied on Linux` followed by a newline.

Next copy DIFFERENT text in a Windows application using its normal Copy action.
On Linux:

```bash
doop --port 24890 paste
```

It should return the newly copied Windows text, not the earlier Linux text.
This is the check that paste reads the real clipboard rather than a server cache.

An exact Unicode/multiline round-trip test in Bash (overwrites the clipboard):

```bash
(
    set -eu
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    printf 'Line one\nUnicode: café λ 😀\n' > "$tmp/expected"
    doop --port 24890 copy < "$tmp/expected"
    doop --port 24890 paste > "$tmp/actual"
    cmp "$tmp/expected" "$tmp/actual"
    printf 'Unicode and newline round trip passed\n'
)
```

Avoid changing the clipboard in another application during this round trip.

Other client examples:

```bash
doop --port 24890 copy "Text argument"
doop --port 24890 copy -- "--literal text"
doop --port 24890 copy < some-file.txt
doop --port 24890 paste > pasted.txt
doop --port 24890 copy ""  # replace clipboard with empty text
```

### 5. Optional Neovim provider on Linux

Place this in init.lua BEFORE any clipboard provider is initialized. Restart
Neovim after changing it. The absolute executable path avoids PATH ambiguity.

```lua
local doop = vim.fn.expand("~/.local/bin/doop")

vim.g.clipboard = {
    name = "doop",
    copy = {
        ["+"] = { doop, "copy" },
        ["*"] = { doop, "copy" },
    },
    paste = {
        ["+"] = { doop, "paste" },
        ["*"] = { doop, "paste" },
    },
    cache_enabled = 0,
}

vim.opt.clipboard = "unnamedplus"
```

With this provider, ordinary Neovim yanks use the Windows clipboard and Neovim
paste operations read it. Both + and * intentionally refer to the same Windows
clipboard. The protocol transports text, not Vim-specific block-selection or
register-type metadata. Terminal paste shortcuts are a separate mechanism and
continue to be handled by your Windows terminal.

## After testing: use the original port

Stop the old Go server before starting the Zig server on 2489. Start:

```powershell
.\doop.exe server
```

Use this RemoteForward (or retain your equivalent existing 2489 forward):

```sshconfig
RemoteForward 127.0.0.1:2489 127.0.0.1:2489
```

Remove the test-only 24890 forward and reconnect as appropriate. On Linux, omit
`--port 24890` from commands; update the Neovim provider arrays to omit it too.
Keep the executable named doop until you are satisfied with testing.
Do not send an old Go client to this server or a new Zig client to the old server.
Existing Go-specific CLI flags/configuration files are not implemented.

## Safety and operational limits

The program binds/connects only to IPv4 127.0.0.1. Its application protocol has
no authentication or encryption; SSH provides the inter-machine protection.
Loopback is NOT per-user access control: other processes/users on either trusted
machine that can reach these ports can read or replace your Windows clipboard.
Do not forward this service to untrusted shared hosts or expose it to a LAN.

One request is handled at a time. A 10-second cancellation deadline wraps each
network request; stdin collection is outside it. This is not a hard preemptive
deadline for arbitrary Win32 calls: another application's delayed clipboard
rendering can block inside the operating system. Clipboard-open contention is
retried briefly. This is a prototype for a personal trusted-machine workflow,
not a hardened multi-user clipboard service.

Copy/paste errors are reported on stderr; paste stdout contains only the text.
Common errors: ConnectionRefused (server/forward missing or wrong port),
WrongProtocol (wrong server/protocol), ClipboardBusy (another app holds it open),
PayloadTooLarge, InvalidUtf8, and EmbeddedNul. SSH remote forwarding failures
usually mean the port is occupied or forwarding is denied. A successful SSH
login alone does not establish that the Windows clipboard server is running;
use `ping` to check the whole path.

## Inline tests

`zig test doop.zig` includes five pure tests:

1. Golden protocol header and exact-length multi-frame parsing.
2. Wrong magic, reserved bits, excessive length, and truncated payload rejection.
3. Unicode/UTF-16 round trip and newline handling; invalid UTF-8/NUL rejection.
4. Empty text and mixed line-ending normalization.
5. CLI port options, literal/empty text, and invalid arguments.

These do not access the system clipboard and do not replace the live tests.

## Protocol and implementation

Header (12 bytes): ASCII LZC1, kind:u8, three zero reserved bytes, payload length
as u32 big endian. Request kinds: 1 copy, 2 paste, 3 ping. Response kinds: 0 OK,
255 error (payload is an error name). One request/response per TCP connection.
All payload allocations are length-bounded. TCP reads consume the exact framed
length, never wait for EOF to determine a message boundary.

Windows uses an internal message-only window owned by a dedicated native message
thread. Clipboard calls use that valid HWND; CF_UNICODETEXT is rendered eagerly.
After successful SetClipboardData, Windows owns the movable global allocation.
The separate message loop remains available while network work is waiting.

## References used in implementation/setup

- Zig 0.17.0 language reference: https://ziglang.org/documentation/0.17.0/
- Windows SetClipboardData: https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setclipboarddata
- Windows OpenClipboard: https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-openclipboard
- Windows GetMessage: https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getmessagew
- Windows OpenSSH configuration: https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh-server-configuration
- OpenSSH client configuration: https://man.openbsd.org/ssh_config
- OpenSSH server configuration: https://man.openbsd.org/sshd_config
- Neovim clipboard providers: https://neovim.io/doc/user/provider/
