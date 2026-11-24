package store

import (
	"sync"
	"testing"
)

func TestReadMissing(t *testing.T) {
	s := New(t.TempDir())
	data, err := s.Read("missing.json")
	if err != nil {
		t.Fatal(err)
	}
	if data != nil {
		t.Fatalf("data = %q, want nil", data)
	}
	if s.Exists("missing.json") {
		t.Fatal("missing file reported as existing")
	}
}

func TestWriteRead(t *testing.T) {
	s := New(t.TempDir())
	if err := s.Write("nested/dir/file.json", []byte(`{"ok":true}`)); err != nil {
		t.Fatal(err)
	}
	data, err := s.Read("nested/dir/file.json")
	if err != nil {
		t.Fatal(err)
	}
	if string(data) != `{"ok":true}` {
		t.Fatalf("data = %q", data)
	}
	if !s.Exists("nested/dir/file.json") {
		t.Fatal("written file does not exist")
	}
}

func TestConcurrentWrites(t *testing.T) {
	s := New(t.TempDir())
	payloads := []string{"one", "two", "three", "four", "five", "six", "seven", "eight"}
	var wg sync.WaitGroup
	for _, payload := range payloads {
		payload := payload
		wg.Add(1)
		go func() {
			defer wg.Done()
			if err := s.Write("same.json", []byte(payload)); err != nil {
				t.Error(err)
			}
		}()
	}
	wg.Wait()

	data, err := s.Read("same.json")
	if err != nil {
		t.Fatal(err)
	}
	for _, payload := range payloads {
		if string(data) == payload {
			return
		}
	}
	t.Fatalf("data = %q, want one complete payload", data)
}
