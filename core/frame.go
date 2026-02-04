package core

import (
	"encoding/binary"
	"io"
)

const (
	FrameData  = 1
	FrameOpen  = 2
	FrameClose = 3
)

type Frame struct {
	Type   uint8
	Stream uint32
	Data   []byte
}

func WriteFrame(w io.Writer, f *Frame) error {
	h := make([]byte, 9)
	h[0] = f.Type
	binary.BigEndian.PutUint32(h[1:], f.Stream)
	binary.BigEndian.PutUint32(h[5:], uint32(len(f.Data)))

	if _, err := w.Write(h); err != nil {
		return err
	}
	_, err := w.Write(f.Data)
	return err
}

func ReadFrame(r io.Reader) (*Frame, error) {
	h := make([]byte, 9)
	if _, err := io.ReadFull(r, h); err != nil {
		return nil, err
	}
	size := binary.BigEndian.Uint32(h[5:])
	d := make([]byte, size)
	if _, err := io.ReadFull(r, d); err != nil {
		return nil, err
	}
	return &Frame{
		Type:   h[0],
		Stream: binary.BigEndian.Uint32(h[1:5]),
		Data:   d,
	}, nil
}
