package transport

import (
	"context"
	"crypto/tls"
	"net"

	quic "github.com/quic-go/quic-go"
)

type quicConn struct{ quic.Stream }

func (q quicConn) LocalAddr() net.Addr                { return nil }
func (q quicConn) RemoteAddr() net.Addr               { return nil }
func (q quicConn) SetDeadline(_ time.Time) error      { return nil }
func (q quicConn) SetReadDeadline(_ time.Time) error  { return nil }
func (q quicConn) SetWriteDeadline(_ time.Time) error { return nil }

type QUIC struct{}

func (QUIC) Dial(addr string) (net.Conn, error) {
	s, err := quic.DialAddr(context.Background(), addr,
		&tls.Config{InsecureSkipVerify: true, NextProtos: []string{"ipmartnet"}}, nil)
	if err != nil {
		return nil, err
	}
	st, err := s.OpenStreamSync(context.Background())
	if err != nil {
		return nil, err
	}
	return quicConn{st}, nil
}

func (QUIC) Listen(addr string) (net.Listener, error) {
	l, err := quic.ListenAddr(addr, generateTLS(), nil)
	if err != nil {
		return nil, err
	}
	return quicListener{l}, nil
}
