@echo off
grep -rin %1 * | cut -c -300 | more