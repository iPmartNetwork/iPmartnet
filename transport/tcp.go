package transport

import "net"

type TCP struct{}

func (TCP) Dial(a string) (net.Conn, error)     { return net.Dial("tcp", a) }
func (TCP) Listen(a string) (net.Listener, error) { return net.Listen("tcp", a) }
