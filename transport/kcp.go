package transport

import (
	"net"

	kcp "github.com/xtaci/kcp-go/v5"
)

type KCP struct{}

func (KCP) Dial(a string) (net.Conn, error)     { return kcp.Dial(a) }
func (KCP) Listen(a string) (net.Listener, error) { return kcp.Listen(a) }
