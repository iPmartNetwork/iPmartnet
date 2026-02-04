package core

type Stream struct {
	id uint32
	m  *Mux
	in chan []byte
}

func (s *Stream) Write(b []byte) error {
	return WriteFrame(s.m.c, &Frame{
		Type:   FrameData,
		Stream: s.id,
		Data:   b,
	})
}

func (s *Stream) Read() ([]byte, bool) {
	d, ok := <-s.in
	return d, ok
}

func (s *Stream) Close() {
	WriteFrame(s.m.c, &Frame{Type: FrameClose, Stream: s.id})
}
