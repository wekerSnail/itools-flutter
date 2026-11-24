package scheduler

import (
	"fmt"
	"sync"
	"time"

	corestore "itools/internal/core/store"
)

// Engine owns the task list and runs due tasks.
type Engine struct {
	store    *Store
	logs     *logBuffer
	onChange func()

	mu             sync.Mutex
	tasks          []Task
	lastOccurrence map[string]int
	inFlight       map[string]bool

	stopOnce sync.Once
	stop     chan struct{}
	started  bool

	nodeOnce sync.Once
	node     string
	nodeOK   bool
}

// NewEngine loads the saved tasks and logs and returns an engine.
func NewEngine(st *corestore.Store, onChange func()) *Engine {
	schedulerStore := NewStore(st)
	engine := &Engine{
		store:          schedulerStore,
		onChange:       onChange,
		lastOccurrence: make(map[string]int),
		inFlight:       make(map[string]bool),
		stop:           make(chan struct{}),
	}
	engine.logs = newLogBuffer(schedulerStore, onChange)
	engine.Reload()
	return engine
}

// Start begins the one-second scheduler loop.
func (e *Engine) Start() {
	e.mu.Lock()
	if e.started {
		e.mu.Unlock()
		return
	}
	e.started = true
	e.mu.Unlock()

	go func() {
		ticker := time.NewTicker(time.Second)
		defer ticker.Stop()
		for {
			select {
			case now := <-ticker.C:
				e.tick(now)
			case <-e.stop:
				return
			}
		}
	}()
}

// Stop ends the loop and flushes the log.
func (e *Engine) Stop() {
	e.stopOnce.Do(func() {
		close(e.stop)
		e.logs.Close()
	})
}

// Reload reads the tasks and logs from disk.
func (e *Engine) Reload() {
	tasks, err := e.store.LoadTasks()
	if err == nil {
		e.mu.Lock()
		e.tasks = tasks
		e.lastOccurrence = make(map[string]int)
		e.mu.Unlock()
	}
	e.logs.Load()
	e.notify()
}

// Tasks returns a copy of the task list.
func (e *Engine) Tasks() []Task {
	e.mu.Lock()
	defer e.mu.Unlock()
	return append([]Task(nil), e.tasks...)
}

// Task returns one task.
func (e *Engine) Task(id string) (Task, bool) {
	e.mu.Lock()
	defer e.mu.Unlock()
	for _, task := range e.tasks {
		if task.ID == id {
			return task, true
		}
	}
	return Task{}, false
}

// Logs returns the run log, oldest first.
func (e *Engine) Logs() []string {
	return e.logs.Messages()
}

// Add appends a task and saves the list.
func (e *Engine) Add(task Task) error {
	e.mu.Lock()
	previous := append([]Task(nil), e.tasks...)
	e.tasks = append(e.tasks, task)
	e.mu.Unlock()
	if err := e.store.SaveTasks(e.tasks); err != nil {
		e.mu.Lock()
		e.tasks = previous
		e.mu.Unlock()
		return err
	}
	e.notify()
	return nil
}

// Update replaces a task and saves the list.
func (e *Engine) Update(task Task) error {
	e.mu.Lock()
	previous := append([]Task(nil), e.tasks...)
	for index := range e.tasks {
		if e.tasks[index].ID == task.ID {
			e.tasks[index] = task
			break
		}
	}
	delete(e.lastOccurrence, task.ID)
	e.mu.Unlock()
	if err := e.store.SaveTasks(e.tasks); err != nil {
		e.mu.Lock()
		e.tasks = previous
		e.mu.Unlock()
		return err
	}
	e.notify()
	return nil
}

// Remove deletes a task and saves the list.
func (e *Engine) Remove(id string) error {
	e.mu.Lock()
	previous := append([]Task(nil), e.tasks...)
	filtered := e.tasks[:0]
	for _, task := range e.tasks {
		if task.ID != id {
			filtered = append(filtered, task)
		}
	}
	e.tasks = filtered
	delete(e.lastOccurrence, id)
	delete(e.inFlight, id)
	e.mu.Unlock()
	if err := e.store.SaveTasks(e.tasks); err != nil {
		e.mu.Lock()
		e.tasks = previous
		e.mu.Unlock()
		return err
	}
	e.notify()
	return nil
}

// SetEnabled enables or disables a task.
func (e *Engine) SetEnabled(id string, enabled bool) error {
	task, ok := e.Task(id)
	if !ok {
		return fmt.Errorf("任务不存在")
	}
	task.Enabled = enabled
	return e.Update(task)
}

// RunNow runs a task immediately.
func (e *Engine) RunNow(id string) error {
	task, ok := e.Task(id)
	if !ok {
		return fmt.Errorf("任务不存在")
	}
	e.logs.Append(e.logLine("手动触发任务 " + task.Name))
	go e.execute(task)
	return nil
}

func (e *Engine) tick(now time.Time) {
	for _, task := range e.Tasks() {
		if !e.isDue(task, now) {
			continue
		}
		occurrence := occurrenceIndex(task, now)
		if occurrence < 0 {
			continue
		}
		e.mu.Lock()
		e.lastOccurrence[task.ID] = occurrence
		e.mu.Unlock()
		go e.execute(task)
	}
}

func (e *Engine) isDue(task Task, now time.Time) bool {
	if !task.Enabled || now.Before(task.StartAt.Time) || task.IntervalValue < 1 {
		return false
	}
	current := occurrenceIndex(task, now)
	if current < 0 {
		return false
	}
	e.mu.Lock()
	last, seen := e.lastOccurrence[task.ID]
	e.mu.Unlock()
	return !seen || last != current
}

func (e *Engine) execute(task Task) {
	e.mu.Lock()
	if e.inFlight[task.ID] {
		e.mu.Unlock()
		e.logs.Append(e.logLine(fmt.Sprintf("任务 %s 仍在执行中，跳过本次触发", task.Name)))
		return
	}
	e.inFlight[task.ID] = true
	e.mu.Unlock()
	defer func() {
		e.mu.Lock()
		delete(e.inFlight, task.ID)
		e.mu.Unlock()
	}()

	e.logs.Append(e.logLine("开始执行任务 " + task.Name))
	code, timedOut, err := e.run(task)
	switch {
	case timedOut:
		e.logs.Append(e.logLine(fmt.Sprintf("任务 %s 超过 %s 未结束，已强制终止进程树", task.Name, timeoutFor(task))))
	case err != nil:
		e.logs.Append(e.logLine(fmt.Sprintf("任务 %s 执行失败: %v", task.Name, err)))
	default:
		e.logs.Append(e.logLine(fmt.Sprintf("任务 %s 结束，退出码: %d", task.Name, code)))
	}
}

func (e *Engine) logLine(message string) string {
	return fmt.Sprintf("[%s] %s", time.Now().Format("2006-01-02 15:04:05.000"), message)
}

func (e *Engine) notify() {
	if e.onChange != nil {
		e.onChange()
	}
}

func occurrenceIndex(task Task, now time.Time) int {
	start := task.StartAt.Time
	if now.Before(start) {
		return -1
	}
	if task.IntervalValue < 1 {
		return -1
	}
	switch task.IntervalUnit {
	case UnitSecond:
		return fixedOccurrence(start, now, 1000, task.IntervalValue)
	case UnitMinute:
		return fixedOccurrence(start, now, 60*1000, task.IntervalValue)
	case UnitHour:
		return fixedOccurrence(start, now, 60*60*1000, task.IntervalValue)
	case UnitDay:
		return fixedOccurrence(start, now, 24*60*60*1000, task.IntervalValue)
	case UnitWeek:
		return fixedOccurrence(start, now, 7*24*60*60*1000, task.IntervalValue)
	case UnitMonth:
		return monthOccurrence(start, now, task.IntervalValue)
	default:
		return fixedOccurrence(start, now, 60*1000, task.IntervalValue)
	}
}

func fixedOccurrence(start, now time.Time, unitMilliseconds int64, interval int) int {
	if interval < 1 {
		return -1
	}
	cycle := unitMilliseconds * int64(interval)
	if cycle <= 0 {
		return -1
	}
	delta := now.UnixMilli() - start.UnixMilli()
	return int(delta / cycle)
}

func monthOccurrence(start, now time.Time, interval int) int {
	if interval < 1 {
		return -1
	}
	totalMonths := (now.Year()-start.Year())*12 + int(now.Month()-start.Month())
	index := totalMonths / interval
	scheduled := addMonths(start, index*interval)
	for index > 0 && scheduled.After(now) {
		index--
		scheduled = addMonths(start, index*interval)
	}
	for {
		next := addMonths(start, (index+1)*interval)
		if next.After(now) {
			break
		}
		index++
		if index > 100000 {
			break
		}
	}
	return index
}

func addMonths(date time.Time, months int) time.Time {
	total := int(date.Month()) - 1 + months
	year := date.Year() + total/12
	month := total%12 + 1
	if month <= 0 {
		month += 12
		year--
	}
	day := date.Day()
	if last := daysInMonth(year, month); day > last {
		day = last
	}
	return time.Date(year, time.Month(month), day, date.Hour(), date.Minute(), date.Second(), date.Nanosecond(), date.Location())
}

func daysInMonth(year, month int) int {
	return time.Date(year, time.Month(month)+1, 0, 0, 0, 0, 0, time.Local).Day()
}
