# Zag: Mono Repo of my personal zig projects.

A zig is like a bumble bee buzzing around in a particular direction. To zag means to go in a separate direction to it's original zig. The bee neither zigs nor zags, but it's entire motion is a zigzag pattern. This is basically a culmination of my zig projects. Although these projects may zag, I will try and conform them to the zig. Although the zig project may zig or zag occassionally too, I will try and conform my zag to their zigzag patterns, at least until 1.0 hits. Then I will settle on a certain zig or zag to my liking.

## 3dbg: Telemetry Visualizer and Debugger

Goal is to build a small personal tool that makes runtime behavior visible, I think moving some of the data here to Sockman might make sense for potential binary analysis and conformity.

## clift: Command Line Interface Formatter for your Terminal

Potentially a template/library I can use for my CLI applications that contains features for terminal applications I would write, to include my `nostrum` application. I don't necessarily think this will be TUI apps, but it could evolve to that maybe. Keeping it simple.

## doop: Duplicator server

TCP enabled clipboard utility that enables copy and pasting between Windows and Linux environments using SSH reverse forwarding. Inspiration taken from lemonade-command.

## nostrum: Sought by the Alchemists

Hypothetical remedy for all ills or diseases. See doc/nostrum.md

## rhei: Window Management

Currently uses river and wlroots, but coming up with a custom way to do this afterwards that may or may not be compatible with Wayland. Definitely not X11 since current format isn't compatible with X11 or XWayland.

## wagon: XML Parser, Scanner, Generator?

Currently this is in rhei, but need to move it out. Not sure if it will be moved out yet though. Basically a custom xml parser, scanner, and generator. Does Wayland right now, but thinking of also doing MAVLink as well.

## view: Android Text Viewer

Simple text view application without syntax highlighting, or any features at all other than viewing raw text.

## zwe: Zig Workspace Engine

This project should be the backbone to editing text and debugging my zig projects (potentially, idk yet). It should understand where all my projects are, preformantly and gradually replace LSP functionalitty with custom BSP/CSP logic, and stay up to date with the latest stable zig version. At some point this could hopefully be the backend for a custom text editor?

## systemd: Systemd Unit File Deployer

Helps by integrating with the build graph to deploy projects that couple with systemd unit files. Should keep it simple, and can either generate systemd files via a .zon file (how I currently use it at work) or even simply deploy systemd unit files to either user-space or system-space. Not fully featured yet, like most of my projects...

## ramen: Is Life!

I need to combine linux.zig (now renamed ramen.zig) into broth.zig. It would be nice for this to be a single file. Not exactly sure the distinction between broth.zig and noodles.zig yet, but I think that's where the line is drawn. I don't see any other files other than these 2 for the library in totality. Basically broth should be what is needed for the base of a project, and noodles would be supplemental in case a project already has a base? I see overlap with this and udeploy and other projects of mine, so we'll see how this develops over time.

## sockman: Shared Memory Socket Manager

This is always evolving. Will add a detailed doc/sockman.md file for current architecture, but it may be apparent from the lib/sockman.zig file too.

## template: Zig Project Initializer

Should be a copy paste project that copies and initializes a zig project the way it is specified under directories listed under `src/init/*/**`, where the first asterisk is the name of the template to use, and everything after is what is to be copied to a destination. This means path matters for the copy. I see overlap with udeploy for this project as well.
