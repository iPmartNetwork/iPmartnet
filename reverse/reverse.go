package reverse

import (
	"io"
	"net"

	"ipmartnet/core"
)

type Role string

const (
	Iran    Role = "iran"
	Outside Role = "outside"
)

func Run(role Role, ln net.Listener, dial func() (net.Conn, error), key []byte) error {
	if role == Outside {
		for {
			raw, _ := ln.Accept()
			go handleOutside(raw, key)
		}
	}
	raw, err := dial()
	if err != nil {
		return err
	}
	core.Wrap(raw, true, key)
	return nil
}

func handleOutside(raw net.Conn, key []byte) {
	sec, _ := core.Wrap(raw, false, key)
	mux := core.NewMux(sec)
	st := mux.Open()
	dst, _ := net.Dial("tcp", "127.0.0.1:22")
	go io.Copy(dst, streamReader{st})
	io.Copy(streamWriter{st}, dst)
}
