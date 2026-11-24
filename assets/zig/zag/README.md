# Zag: Mono Repo of my personal zig projects.

A zig is like a bumble bee buzzing around in a particular direction. To zag means to go in a separate direction to it's original zig. The bee neither zigs nor zags, but it's entire motion is a zigzag pattern. This is basically a culmination of my zig projects. Although these projects may zag, I will try and conform them to the zig. Although the zig project may zig or zag occassionally too, I will try and conform my zag to their zigzag patterns, at least until 1.0 hits. Then I will settle on a certain zig or zag to my liking. I will refer to this interpretation as a ZigZag, zigzag, you get it.

I've defined about 2 kinds of zigzag's for the monorepo, with the purpose being the deciding factor: `exe`, and `lib`.

## `exe`: A program with an implementation whose purpose is some run-time/compile-time execution defined thing

### 3dbg: Telemetry Visualizer and Debugger

Goal is to build a small personal tool that makes runtime behavior visible, I think moving some of the data here to Sockman might make sense for potential binary analysis and conformity.

### doop: Duplicator server

TCP enabled clipboard utility that enables copy and pasting between Windows and Linux environments using SSH reverse forwarding. Inspiration taken from lemonade-command.

### nostrum: Sought by the Alchemists

Hypothetical remedy for all ills or diseases. See doc/nostrum.md

### rhei: Window Management

Currently uses river and wlroots, but coming up with a custom way to do this afterwards that may or may not be compatible with Wayland. Definitely not X11 since current format isn't compatible with X11 or XWayland. Currently there's a bug where displays swap after idle and the resolution becomes choppy. Also the bar crashes after idle. So need to likely look at both idle and bar.

### template: Zig Project Initializer

Should be a copy paste project that copies and initializes a zig project the way it is specified under directories listed under a specified directory, likely named `init` within the project, where the first asterisk is the name of the template to use, and everything after is what is to be copied to a destination. This means path matters for the copy. I see overlap with udeploy for this project as well. I can see this being a compile-time program since everything can technically be done at compile time in my head right now.

### udeploy: User Space Project Deployer

A deployment enabling project taht started out with setting up my user environment to enable me to start on a new system quickly. Slowly morphed into a project that also compiles my software from scratch as well, and retains state of where those projects are setup so if anything moves in the state, the project can then update and understand the overall state for any project rebuildings that may need to happen in case things break. Not sure really what this is yet, but I think it's slowly turning into a sort of compiling package manager in a way. At some point I think I would like to add my own custom version controlling system that can more easily track changes between projects independently via tracking configuration changes as well. Hopefully there is a nicer way to do this in the long run, since I've  basically had this prototyped for a while where I keep tweaking things and changing things, and end up back to just using scripts again. Not sure where I should draw the boundary yet for easy installation and understanding at a glance...

### view: Android Text Viewer

Simple text view application without syntax highlighting, or any features at all other than viewing raw text.

### wagon: XML Parser, Scanner, Generator?

A custom XML parser, scanner, and generator for my zig projects. Does Wayland right now, but thinking of also doing MAVLink as well later or any other XML protocol, since the world is so interested in JSON and XML, might do something with this later as well. There should likely also be a translation layer that moves things from XML or JSON to ZON? Just an idea.

### zwe: Zig Workspace Engine

This project should be the backbone to editing text and debugging my zig projects (potentially, idk yet). It should understand where all my projects are, preformantly and gradually replace LSP functionalitty with custom BSP/CSP logic, and stay up to date with the latest stable zig version. At some point this could hopefully be the backend for a custom text editor?

## `lib`: A library whose purpose is in aiding an implementation of some run-time/compile-time execution defined thing

May or may not have a run-time/compile-time aspect, but it's the purpose that matters most. Contains my personal libraries or other libraries. Libraries can be source zip files as well. This keeps the structure lean and clean, and should be handled by the implementor when obtaining a certain library. Contains my personal `ramen` library, which also contains `broth` and `noodles`, which should act similarly to `src/root.zig`, with minor caveats.

### ramen: Is Life!

Ramen is my personal library to be used similar to how `src/root.zig` is generated when running `zig init`. It's my personal `root` library for things that I write to help me with work or my personal projects. Ramen of course, contains broth and noodles.

#### broth: The base of life

Library implementations that do not use Zig's standard library.

##### sockman: Shared Memory Socket Manager

This is always evolving. Will add a detailed sockman.md file for current architecture, but it may be apparent from the actual Sockman.zig file too.

#### noodles: The noodles

Library implementations that use Zig's standard library.

##### project: Zig project helper

Helps with adding project structure that I've noticed I need a lot in my programs when I'm writing my build, either for work or personal projects (although more for work).

- systemd: Helps by integrating with the build graph to deploy projects that couple with systemd unit files. Should keep it simple, and can either generate systemd files via a .zon file (how I currently use it at work) or even simply deploy systemd unit files to either user-space or system-space. Not fully featured yet, like most of my projects...

- archive: Helps with uncompressing archives right now, but should later add functionality for also creating archives.

- scope: Helps with deploy scope or build scope. This would affect prefix and cache paths/destinations, but currently is more like a shim, sham, blam of sorts.

### clift: Command Line Interface Formatter for your Terminal

- Note: Currently not implemented, and not sure where this goes yet, so leaving flat in lib for now.

Potentially a template/library I can use for my CLI applications that contains features for terminal applications I would write, to include my `nostrum` application. I don't necessarily think this will be TUI apps, but it could evolve to that maybe. Keeping it simple.

### sqlite: Yes

A zip of sqlite source code. Idk what version or anything, go unzip it or read it or something.
