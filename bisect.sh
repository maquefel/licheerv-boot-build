#!/bin/sh

# an exit code of 125 asks "git bisect"
# to "skip" the current commit
(cd .. && make clean) || exit 125
(cd .. && make distclean) || exit 125
(cd .. && make) || exit 125

# run the application and check that it produces good output
(cd .. && tests/bisect.expect)
