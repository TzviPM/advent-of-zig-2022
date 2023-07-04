# Advent of Zig 2022

This is a raw, uneditted playground of me solving the 2022 advent of code (https://adventofcode.com/2022) using Zig as a way to learn the language.

## Thoughts on Zig

So far, after finishing days 1 and 2, I like the language. I found the concept of allocators confusing at first, as well as defer. For day 1, I tried to construct inputs using ArrayList to a function that would accept slices. It turns out this was more convoluted than I would like. Encapsulating the allocation and other logic within structs made it much more seemless to work with Zig.
