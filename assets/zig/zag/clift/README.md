# Original idea

This will be a template/library I can use for CLI applications that contains the features for certain terminal applications I want to write, to include for my `nostrum` application. I don't necessarily think this will be TUI apps, but it could evolve to that...

Features currently I'm planning on putting into this library includes:
- Making various interactive commands for a terminal application (basically, allowing for more than 1 type of output generation)
- Including flag generation and effects of these flags on the command output
- Having a color system for "painting" the CLI various colors.
- Having an active selection mechanism (inspiration from nushell's interactive selection mechanisms and tools like `fzf`)
- Progress bars in case that's needed in the app
- Full screen rendering
- partial screen rendering
- terminal output via selective commands
- exit conditions and security fail safes
- Defining context window sizes for the render draw/output
- Other features I can't think about right now...

Features I don't think I'll add (currently):
- Mouse support
- Since this is for personal usage, I don't think I'll include complicated glyphs at all, and just focus on pure english text. If I end up using them, then I may include them later.
- Probably others
