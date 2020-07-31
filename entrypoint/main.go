// Icinga 2 Docker image | (c) 2020 Icinga GmbH | GPLv2+

package main

import (
	"bufio"
	"fmt"
	"github.com/otiai10/copy"
	"golang.org/x/crypto/ssh/terminal"
	"io/ioutil"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"strings"
	"syscall"
	"time"
)

const ca = "/var/lib/icinga2/certs/ca.crt"
const crtMode = 0640

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

		logf(info, "Checking %#v", ca)

		if _, errSt := os.Stat(ca); errSt != nil {
			if os.IsNotExist(errSt) {
				nodeSetup := []string{"node", "setup"}
				runNodeSetup := false

				for _, env := range os.Environ() {
					if kv := strings.SplitN(env, "=", 2); len(kv) == 2 {
						if strings.HasPrefix(kv[0], "ICINGA_") {
							switch kv[0] = strings.ToLower(strings.TrimPrefix(kv[0], "ICINGA_")); kv[0] {
							case "accept_commands", "accept_config", "disable_confd", "master":
								runNodeSetup = true
								if kv[1] == "1" {
									nodeSetup = append(nodeSetup, "--"+strings.ReplaceAll(kv[0], "_", "-"))
								}
							case "cn", "endpoint", "global_zones", "listen",
								"parent_host", "parent_zone", "ticket", "zone":
								runNodeSetup = true
								nodeSetup = append(nodeSetup, "--"+kv[0], kv[1])
							case "trustedcert":
								logf(info, "Writing trusted certificate")
								runNodeSetup = true

								dir, errTD := ioutil.TempDir("", "")
								if errTD != nil {
									return errTD
								}

								file := path.Join(dir, "trusted.crt")
								if errWF := ioutil.WriteFile(file, []byte(kv[1]), crtMode); errWF != nil {
									return errWF
								}

								nodeSetup = append(nodeSetup, "--"+kv[0], file)
							case "cacert":
								logf(info, "Writing CA certificate")
								runNodeSetup = true

								if errWF := ioutil.WriteFile(ca, []byte(kv[1]), crtMode); errWF != nil {
									return errWF
								}
							}
						}
					}
				}

				if runNodeSetup {
					logf(info, "Running 'node setup'")

					cmd := exec.Command("icinga2", nodeSetup...)
					cmd.Stdout = os.Stderr
					cmd.Stderr = os.Stderr

					if errRn := cmd.Run(); errRn != nil {
						return errRn
					}
				}
			} else {
				return errSt
			}
		}

		logf(info, "Configuring features")

		for _, env := range os.Environ() {
			if kv := strings.SplitN(env, "=", 2); len(kv) == 2 {
				if strings.HasPrefix(kv[0], "ICINGA_FEATURE_") {
					if kv[0] = strings.TrimPrefix(kv[0], "ICINGA_FEATURE_"); len(kv[0]) > 0 {
						kv[0] = strings.ToLower(strings.ReplaceAll(kv[0], "_", "-"))
						logf(info, "Configuring feature: %#v", kv[0])

						available := path.Join("/etc/icinga2/features-available", kv[0]+".conf")
						if errWF := ioutil.WriteFile(available, []byte(kv[1]), 0750); errWF != nil {
							return errWF
						}

						errSl := os.Symlink(available, path.Join("/etc/icinga2/features-enabled", kv[0]+".conf"))
						if errSl != nil {
							if le, ok := errSl.(*os.LinkError); !ok || !os.IsExist(le.Err) {
								return errSl
							}
						}
					}
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
