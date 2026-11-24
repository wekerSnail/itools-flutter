//go:build !windows

package scheduler

import "os/exec"

// hideConsole does nothing outside Windows.
func hideConsole(cmd *exec.Cmd) {}
