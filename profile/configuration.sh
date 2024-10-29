#!/bin/sh source-this-script

# Show tasks for the current branch [+ submodule] after switching branches.
export GIT_CHECKOUT_BRANCH_POST_COMMAND='TODOTXT_VERBOSE=0 todo-local.sh here -s 3'
