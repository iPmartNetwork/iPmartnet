package transport

import "net"

type UDP struct{}

func (UDP) Dial(a string) (net.Conn, error) {
	r, _ := net.ResolveUDPAddr("udp", a)
	return net.DialUDP("udp", nil, r)
}
func (UDP) Listen(a string) (net.Listener, error) {
	return net.Listen("udp", a)
}
