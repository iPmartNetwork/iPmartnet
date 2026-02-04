package main

import (
	"flag"
	"fmt"
	"log"
	"net"
	"os"

	"iPmartnet/reverse"
	"iPmartnet/transport"
)

func main() {
	// CLI flags
	role := flag.String("role", "", "Role: iran or outside")
	proto := flag.String("proto", "tcp", "Protocol: tcp|udp|quic|kcp|icmp|faketcp")
	listen := flag.String("listen", "", "Listen address (outside mode)")
	connect := flag.String("connect", "", "Connect address (iran mode)")
	flag.Parse()

	if *role != "iran" && *role != "outside" {
		log.Fatal("Invalid role. Use --role=iran or --role=outside")
	}

	var t transport.Transport

	switch *proto {
	case "tcp":
		t = transport.TCP{}
	case "udp":
		t = transport.UDP{}
	case "quic":
		t = transport.QUIC{}
	case "kcp":
		t = transport.KCP{}
	case "icmp":
		t = transport.ICMPSystem{}
	case "faketcp":
		t = transport.FakeTCPSystem{}
	default:
		log.Fatalf("Unsupported protocol: %s", *proto)
	}

	if *role == "outside" {
		if *listen == "" {
			log.Fatal("--listen is required in outside mode")
		}

		ln, err := t.Listen(*listen)
		if err != nil {
			log.Fatal(err)
		}

		fmt.Println("iPmartnet outside listening on", *listen)

		for {
			conn, err := ln.Accept()
			if err != nil {
				log.Println(err)
				continue
			}
			go handleOutside(conn)
		}
	} else {
		if *connect == "" {
			log.Fatal("--connect is required in iran mode")
		}

		conn, err := t.Dial(*connect)
		if err != nil {
			log.Fatal(err)
		}

		fmt.Println("iPmartnet iran connected to", *connect)
		handleIran(conn)
	}
}

func handleOutside(conn net.Conn) {
	defer conn.Close()
	log.Println("Outside connection established:", conn.RemoteAddr())
	// TODO: integrate reverse tunnel core
}

func handleIran(conn net.Conn) {
	defer conn.Close()
	log.Println("Iran tunnel connected:", conn.RemoteAddr())
	// TODO: integrate reverse tunnel core
}
