# Deliberately vulnerable. selftest.yml runs security.yml against this repo and
# passes only if BOTH tools flag this file and nothing else. Do not "fix" it.
import subprocess

# gitleaks aws-access-token. Must NOT end in EXAMPLE: the default rule allowlists .+EXAMPLE$
AWS_ACCESS_KEY_ID = "AKIAQ4XZ7Y2B3C5D6E7F"


def run(cmd):
    # semgrep python.lang.security.audit.subprocess-shell-true (severity ERROR).
    # `cmd` must be a variable: the rule has pattern-not for a string literal.
    return subprocess.run(cmd, shell=True)
