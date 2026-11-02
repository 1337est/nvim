# Template

Pretty much a copy paste project that copies and initializes a zig project the way it is specified under directories listed here via a template under `src/init/*/**`, where the first asterisk is the name of the template, and everything after is what is to be copied to a destination.

I want to add the concept of builds with versions for the template and specifying build steps and their descriptions at the top level of the `build.zig` file.

I'm thinking something like this:

## Build Local Cache and Prefix

Builds local to the project that contains the `build.zig` manifest file.

### -Dversioned Cache and Prefix

## Build User Cache and Prefix

### -Dversioned Cache and Prefix

## Build System Cache and Prefix

### -Dversioned Cache and Prefix

