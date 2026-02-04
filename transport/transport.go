package transport

import "net"

type Dialer interface {
	Dial(addr string) (net.Conn, error)
}

type Listener interface {
	Listen(addr string) (net.Listener, error)
}
