package core

import "sync"

type rw interface {
	Read([]byte) (int, error)
	Write([]byte) (int, error)
}

type Mux struct {
	c  rw
	m  map[uint32]*Stream
	mu sync.Mutex
	id uint32
}

func NewMux(c rw) *Mux {
	m := &Mux{c: c, m: make(map[uint32]*Stream), id: 1}
	go m.loop()
	return m
}

func (m *Mux) Open() *Stream {
	m.mu.Lock()
	id := m.id
	m.id++
	s := &Stream{id: id, m: m, in: make(chan []byte, 32)}
	m.m[id] = s
	m.mu.Unlock()

	WriteFrame(m.c, &Frame{Type: FrameOpen, Stream: id})
	return s
}

func (m *Mux) loop() {
	for {
		f, err := ReadFrame(m.c)
		if err != nil {
			return
		}
		m.mu.Lock()
		s := m.m[f.Stream]
		m.mu.Unlock()
		if s == nil {
			continue
		}
		switch f.Type {
		case FrameData:
			s.in <- f.Data
		case FrameClose:
			close(s.in)
		}
	}
}
