package transport

import "errors"

type FakeTCPSystem struct{}
func (FakeTCPSystem) Dial(string) (net.Conn, error) { return nil, errors.New("use system faketcp tunnel") }
func (FakeTCPSystem) Listen(string) (net.Listener, error) { return nil, errors.New("use system faketcp tunnel") }
