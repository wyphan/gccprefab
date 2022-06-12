# GCCprefab

The `GCCprefab` simple build system for building GNU Compiler Collection (GCC) from sources.
Developed as part of [my GSoC '22 project][gsoc] with GCC.

## Features

- One single script written in Bash
- Takes in a build configuration file with a custom format inspired by [Spack spec syntax][spack]
  and the Windows INI / [TOML][toml] format for configuration files
- Clones the main GCC Git repo, or a custom mirror of your choice
- Upon execution, logs standard output for each phase of the build process into a timestamped log file,
  which is `xz`-compressed after each phase completes successfully
- Licensed under the permissive [Apache 2.0 license][apache]

## Contributing

Any meaningful feedback is welcome (no spam please).
Please feel free to open an issue to report a bug or suggest new features.
You can also fork the repo and submit a pull request (PR) if you have a fix ready for review.
Or simply head over to the [thread at Fortran-lang Discourse forum][forum] to join the discussion!

[gsoc]: https://summerofcode.withgoogle.com/programs/2022/projects/et1mX1zU
[spack]: https://spack.readthedocs.io/en/latest/basic_usage.html#specs-dependencies
[toml]: https://toml.io/en/
[apache]: https://opensource.org/licenses/Apache-2.0
[forum]: https://fortran-lang.discourse.group/t/gsoc-2022-accelerating-fortran-do-concurrent-in-gcc/3269
