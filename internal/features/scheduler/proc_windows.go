//go:build windows

package scheduler

import (
	"os/exec"
	"syscall"
)

// hideConsole runs the child process without a console window: task
// commands and node scripts are console programs, which would flash a
// terminal while they run.
func hideConsole(cmd *exec.Cmd) {
	cmd.SysProcAttr = &syscall.SysProcAttr{
		HideWindow:    true,
		CreationFlags: 0x08000000, // CREATE_NO_WINDOW
	}
}
