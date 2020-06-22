package main

import (
	"bufio"
	"fmt"
	"github.com/otiai10/copy"
	"golang.org/x/crypto/ssh/terminal"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"syscall"
	"time"
)

func main() {
	if err := entrypoint(); err != nil {
		logf(critical, "%s", err.Error())
		os.Exit(1)
	}
}

func entrypoint() error {
	if len(os.Args) < 2 {
		logf(warning, "Nothing to do.")
		return nil
	}

	if os.Getpid() == 1 {
		logf(info, "Initializing /data as we're the init process (PID 1)")

		for _, dir := range []string{"etc", "var/cache", "var/lib", "var/log", "var/run", "var/spool"} {
			dest := path.Join("/data", dir, "icinga2")
			logf(info, "Checking %#v", dest)

			if _, errSt := os.Stat(dest); errSt != nil {
				if os.IsNotExist(errSt) {
					src := path.Join("/data-init", dir, "icinga2")
					logf(info, "Copying %#v to %#v", src, dest)

					if errMA := os.MkdirAll(path.Dir(dest), 0755); errMA != nil {
						return errMA
					}

					if errCp := copy.Copy(src, dest); errCp != nil {
						return errCp
					}
				} else {
					return errSt
				}
			}
		}
	}

	path := os.Args[1]
	if filepath.Base(path) == path {
		logf(info, "Looking up %#v in $PATH", path)

		abs, errLP := exec.LookPath(path)
		if errLP != nil {
			return errLP
		}

		path = abs
	}

	logf(info, "Running %#v", path)
	return syscall.Exec(path, os.Args[1:], os.Environ())
}

type logSeverity uint8

const (
	info logSeverity = iota
	warning
	critical
)

var out = bufio.NewWriter(os.Stderr)
var isTerminal = terminal.IsTerminal(int(os.Stderr.Fd()))

func logf(severity logSeverity, format string, a ...interface{}) {
	var color, colorOff, seeverity string

	switch severity {
	case info:
		color = "\x1b[32m"
		seeverity = "information"
	case warning:
		color = "\x1b[33m\x1b[1m"
		seeverity = "warning"
	case critical:
		color = "\x1b[31m\x1b[1m"
		seeverity = "critical"
	}

	if isTerminal {
		colorOff = "\x1b[0m"
	} else {
		color = ""
	}

	_, _ = fmt.Fprintf(out, "[%s] ", time.Now().Format("2006-01-02 15:04:05 -0700"))
	_, _ = fmt.Fprintf(out, "%s%s%s/DockerEntrypoint: ", color, seeverity, colorOff)
	_, _ = fmt.Fprintf(out, format, a...)

	_, _ = fmt.Fprintln(out)
	_ = out.Flush()
}
