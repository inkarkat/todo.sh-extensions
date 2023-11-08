#!/bin/bash

: ${TODOTXT_LOCAL_GITREPO_USE_SUPERPROJECT=t}	# Use the topmost repository root if in a submodule.
if [ "$TODOTXT_LOCAL_GITREPO_USE_SUPERPROJECT" ]; then
    : ${TODOTXT_LOCAL_GITREPO_PROJECT_COMMAND='! git-issubmodule 2>/dev/null || git-subname --reponame 2>/dev/null'}   # Add the current submodule name as project to each added task.
else
    : ${TODOTXT_LOCAL_GITREPO_PROJECT_COMMAND=''}
fi
: ${TODOTXT_LOCAL_GITREPO_CONTEXT_COMMAND='git-brname --real-branch-only 2>/dev/null | grep --invert-match --fixed-strings --line-regexp "$(git-mbr --get 2>/dev/null)"'}    # Add the (non-master) branch name as context to each added task.

addRepoData()
{
    local prefix
    if [ -n "$TODOTXT_LOCAL_GITREPO_CONTEXT_COMMAND" ]; then
	prefix="$(eval "$TODOTXT_LOCAL_GITREPO_CONTEXT_COMMAND")"
	export TODOTXT_ADD_PREFIX="${prefix:+@}${prefix}${prefix:+ }${TODOTXT_ADD_PREFIX}"
    fi
    if [ -n "$TODOTXT_LOCAL_GITREPO_PROJECT_COMMAND" ]; then
	prefix="$(eval "$TODOTXT_LOCAL_GITREPO_PROJECT_COMMAND")"
	export TODOTXT_ADD_PREFIX="${prefix:++}${prefix}${prefix:+ }${TODOTXT_ADD_PREFIX}"
    fi
}

determineLocalTodoDir()
{
    TODO_DIR="$(
	[ "$TODOTXT_LOCAL_GITREPO_USE_SUPERPROJECT" ] \
	    && git superproject --print-toplevel 2>/dev/null \
	    || git root 2>/dev/null
    )"
    DONE_DIR=''
    if [ -n "$TODO_DIR" ]; then
	local gitDir="$(cd "$TODO_DIR" && git rev-parse --absolute-git-dir 2>/dev/null)"
	if [ -n "$gitDir" ]; then
	    DONE_DIR="${gitDir}/todo"
	fi
	addRepoData
    else
	typeset -a localTodoDirspecs=(); readarray -t localTodoDirspecs < <(shopt -qs nullglob; cd ~/.local/share/todo-local 2>/dev/null && pathAsFilename --decode -- *)
	[ ${#localTodoDirspecs[@]} -eq 0 ] || TODO_DIR="$(findup --exec negateThis filterArg --first -- {} "${localTodoDirspecs[@]}" \; -- .)"
    fi
    if [ -z "$TODO_DIR" ]; then
	TODO_DIR="$(findup --stop-at-first todo.txt 2>/dev/null | inputToArg dirname)"
    fi

    if [ -z "$DONE_DIR" -a -n "$TODO_DIR" ]; then
	DONE_DIR="${HOME}/.local/share/todo-local/$(pathAsFilename --encode "$TODO_DIR")"
    fi
}

printInitHelp()
{
    printf '    "%s" or "%q %s" (or initialize a Git repo here).\n' 'touch todo.txt' "$(basename "$1")" 'init [DIR]'
}
printNoLocalError()
{
    cat <<ERRORTEXT
ERROR: No local todo.txt found in the current directory or one of its parents
       (and this also isn't a Git working copy). Create an empty task list via
ERRORTEXT
    printInitHelp "$1"
}
printUsage()
{
    local usageHelp; printf -v usageHelp 'Usage: %q %s\n' "$(basename "$1")" '[-g|--global|-l|--local] [TODOTXT_ARGs ...] location|ACTION [TASK_NUMBER] [TASK_DESCRIPTION] [-?|-h|--help]'

    determineLocalTodoDir
    if [ -n "$TODO_DIR" ]; then
	cat <<HELPTEXT
Local task list, using ${TODO_DIR}/todo.txt, and auto-archives into ${DONE_DIR:?}/done.txt
Add -g|--global (or change directory) to access the global task list instead.
HELPTEXT
	echo
	printf %s "$usageHelp"
    else {
	cat <<HELPTEXT
Global or local task list, for the latter using a todo.txt found in the current
directory or one of its parents, and auto-archives into .git/todo if within a
Git working copy or else into ~/.local/share/todo-local/<path+to+dir>/done.txt
Create an empty local task list via
HELPTEXT
	printInitHelp "$1"
	echo
	printf %s "$usageHelp"
	[ "$scope" = 'local' ] || todo.sh help | sed -e '1{ /^[[:space:]]*Usage: /d }'
	} | "${PAGER:-less}" --RAW-CONTROL-CHARS
    fi
}
scope=
while [ $# -ne 0 ]
do
    case "$1" in
	help|--help|-h|-\?)
			if [ $# -gt 1 -o "$scope" = 'global' ]; then
			    exec todo.sh "$@"
			else
			    printUsage "$0"; exit 0
			fi
			;;
	location)	shift
			determineLocalTodoDir
			[ -n "$TODO_DIR" -a -n "$DONE_DIR" ] || exit 1
			printf '%s\n' "$TODO_DIR" "$DONE_DIR"
			exit 0
			;;
	--global|-g)	shift; scope='global';;
	--local|-l)	shift; scope='local';;
	init)		shift
			[ $# -eq 0 ] || cd "$1" || exit $?
			touch todo.txt
			exit $?
			;;
	*)		break;;
    esac
done

[ "$scope" = 'global' ] || determineLocalTodoDir
if [ -z "$TODO_DIR" ]; then
    if [ "$scope" = 'local' ]; then
	printNoLocalError "$0" >&2
	exit 1
    else
	# Global scope.
	exec todo.sh "$@"
    fi
fi

# Local scope.
TODO_FILE="${TODO_DIR:?}/todo.txt"
DONE_FILE="${DONE_DIR:?}/done.txt"
touch-p --no-create -- "$TODO_FILE" "$DONE_FILE"

export TODO_DIR TODO_FILE DONE_FILE REPORT_FILE=/dev/null TODOTXT_BACKUP_DIR=''
finally()
{
    # Move the backup copy into the DONE_DIR so that it's out of sight (but
    # still accessible should it be necessary to undo the last modification).
    [ -r "${TODO_FILE}.bak" ] && mv --force -- "${TODO_FILE}.bak" "${DONE_DIR}/"

    # Remove a completely empty todo.txt file.
    if [ ! -s "$TODO_FILE" ]; then
	rm -- "$TODO_FILE" 2>/dev/null \
	    && echo 'TODO: All local tasks completed.'
    fi
}
trap finally EXIT

todo.sh -A "$@"
