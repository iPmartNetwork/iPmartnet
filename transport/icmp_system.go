package transport

import "errors"

type ICMPSystem struct{}
func (ICMPSystem) Dial(string) (net.Conn, error) { return nil, errors.New("use system icmp tunnel") }
func (ICMPSystem) Listen(string) (net.Listener, error) { return nil, errors.New("use system icmp tunnel") }
