# lua-cli
Unix-like CLI in Windows written in Lua and C

# Dependencies
[libffi](https://sourceware.org/libffi/)
[lua-ffi](https://github.com/zhaojh329/lua-ffi)
[srlua (for making standalone)](https://github.com/LuaDist/srlua)
[[LIBGCC_S_DW2-1 (Precompiled)]]()

# Requires (lua modules)
[ansicolors](https://github.com/kikito/ansicolors.lua)

# Build
Use [srlua](https://github.com/LuaDist/srlua) to build lua files to executable files.
Run lua-build.bat to build
> warning the lua source files is readable through hex-editors so obfuscate your code before building.
