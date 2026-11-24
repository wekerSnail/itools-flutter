package scheduler

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"time"
)

const defaultTimeout = 600 * time.Second

func timeoutFor(task Task) time.Duration {
	if task.TimeoutSeconds != nil && *task.TimeoutSeconds > 0 {
		return time.Duration(*task.TimeoutSeconds) * time.Second
	}
	return defaultTimeout
}

func (e *Engine) run(task Task) (code int, timedOut bool, err error) {
	switch task.Type {
	case TypeJS:
		return e.runScript(task)
	default:
		return e.runCommand(task)
	}
}

func (e *Engine) runCommand(task Task) (int, bool, error) {
	command := applyCmdVariables(task.Command, task.RuntimeVariables())
	dir, err := os.MkdirTemp("", "itools_cmd_")
	if err != nil {
		return -1, false, err
	}
	defer os.RemoveAll(dir)

	script := dir + string(os.PathSeparator) + "task_" + safeFileName(task.ID) + ".cmd"
	if err := os.WriteFile(script, []byte(command), 0o600); err != nil {
		return -1, false, err
	}

	var cmd *exec.Cmd
	if runtime.GOOS == "windows" {
		cmd = exec.Command("cmd", "/c", script)
	} else {
		cmd = exec.Command("sh", script)
	}
	hideConsole(cmd)
	return e.runProcess(cmd, task, task.Name, "["+task.Name+"]")
}

func (e *Engine) runScript(task Task) (int, bool, error) {
	script := ""
	if task.Script != nil {
		script = *task.Script
	}
	if script == "" {
		return -1, false, fmt.Errorf("JS 脚本为空")
	}
	node, ok := e.nodePath()
	if !ok {
		return -1, false, fmt.Errorf("未检测到 Node.js，请先安装并配置 PATH")
	}

	variables, err := json.Marshal(task.RuntimeVariables())
	if err != nil {
		return -1, false, err
	}
	dir, err := os.MkdirTemp("", "itools_js_")
	if err != nil {
		return -1, false, err
	}
	defer os.RemoveAll(dir)

	path := dir + string(os.PathSeparator) + "task_" + safeFileName(task.ID) + ".js"
	content := "const vars = " + string(variables) + ";\n" + script
	if err := os.WriteFile(path, []byte(content), 0o600); err != nil {
		return -1, false, err
	}
	cmd := exec.Command(node, path)
	hideConsole(cmd)
	return e.runProcess(cmd, task, task.Name, "["+task.Name+"][JS]")
}

func (e *Engine) runProcess(cmd *exec.Cmd, task Task, label, prefix string) (int, bool, error) {
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return -1, false, err
	}
	stderr, err := cmd.StderrPipe()
	if err != nil {
		return -1, false, err
	}
	if err := cmd.Start(); err != nil {
		return -1, false, err
	}

	var scannerWG sync.WaitGroup
	scannerWG.Add(2)
	go func() {
		defer scannerWG.Done()
		scanLines(stdout, func(line string) {
			e.logs.Append(prefix + " " + line)
		})
	}()
	go func() {
		defer scannerWG.Done()
		scanLines(stderr, func(line string) {
			e.logs.Append(prefix + "[ERR] " + line)
		})
	}()

	done := make(chan error, 1)
	go func() {
		done <- cmd.Wait()
	}()

	timeout := timeoutFor(task)
	select {
	case waitErr := <-done:
		scannerWG.Wait()
		return exitCode(waitErr), false, nil
	case <-time.After(timeout):
		killTree(cmd.Process.Pid)
		<-done
		scannerWG.Wait()
		return -1, true, nil
	}
}

func scanLines(reader io.Reader, fn func(string)) {
	scanner := bufio.NewScanner(reader)
	scanner.Buffer(make([]byte, 64*1024), 1024*1024)
	for scanner.Scan() {
		fn(scanner.Text())
	}
}

func exitCode(err error) int {
	if err == nil {
		return 0
	}
	if exitError, ok := err.(*exec.ExitError); ok {
		return exitError.ExitCode()
	}
	return -1
}

func (e *Engine) nodePath() (string, bool) {
	e.nodeOnce.Do(func() {
		path, err := exec.LookPath("node")
		e.node = path
		e.nodeOK = err == nil
	})
	return e.node, e.nodeOK
}

func safeFileName(value string) string {
	var builder strings.Builder
	for _, r := range value {
		switch {
		case r >= 'a' && r <= 'z',
			r >= 'A' && r <= 'Z',
			r >= '0' && r <= '9',
			r == '-', r == '_':
			builder.WriteRune(r)
		default:
			builder.WriteByte('_')
		}
	}
	if builder.Len() == 0 {
		return "task"
	}
	return builder.String()
}

func killTree(pid int) {
	if pid <= 0 {
		return
	}
	if runtime.GOOS == "windows" {
		kill := exec.Command("taskkill", "/T", "/F", "/PID", strconv.Itoa(pid))
		hideConsole(kill)
		_ = kill.Run()
		return
	}
	if process, err := os.FindProcess(pid); err == nil {
		_ = process.Kill()
	}
}
