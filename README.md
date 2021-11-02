# BinaryWrappers
[![Build Status](https://github.com/oscar-system/BinaryWrappers.jl/workflows/CI/badge.svg)](https://github.com/oscar-system/BinaryWrappers.jl/actions)

This package provides a scratchspace with wrappers for the binaries and scripts
from JLL packages like [`lib4ti2_jll`](https://github.com/JuliaBinaryWrappers/lib4ti2_jll.jl).
The wrappers allow non-julia code (like in `polymake_jll` or `Singular_jll`) to
execute those directly without having to adjust LIBPATH environment variables.

## Usage
The wrapper generation should be triggered during precompilation with
```
    using BinaryWrappers
    const lib4ti2_binpath = @generate_wrappers(lib4ti2_jll)
```
and the corresponding path might be used in `__init__() as follows:
```
    ENV["PATH"] = lib4ti2_binpath * ":" * ENV["PATH"]
```

## Warning
This was primarily written to provide wrappers for `lib4ti2_jll` but it might work for other JLL packages as well.

