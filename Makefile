# baseproof CLI — build, install, verify, and generate install artifacts.
#
# The module is github.com/baseproof/cli, so a bare `go install` would name the
# binary `cli` (the module path's last element). Every target here pins the real
# name — baseproof — and stamps the version from the git tag.

BINARY  := baseproof
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)
LDFLAGS := -ldflags "-s -w -X main.version=$(VERSION)"
GOBIN   := $(or $(shell go env GOBIN),$(shell go env GOPATH)/bin)

# The libs dependency is a private baseproof module: skip the public proxy/sumdb.
export GOPRIVATE := github.com/baseproof/*
# Pure-Go static binaries: no libc dependency, so one build runs on any modern
# linux (glibc or musl) and macOS — the whole point of the cross matrix below.
export CGO_ENABLED := 0

.PHONY: all build install uninstall check test vet fmt completions man cross clean

all: check build

build: ## ./bin/baseproof for the host platform
	go build $(LDFLAGS) -o bin/$(BINARY) .

install: ## $(GOBIN)/baseproof — `baseproof --version` to verify
	go build $(LDFLAGS) -o $(GOBIN)/$(BINARY) .
	@echo "installed $(GOBIN)/$(BINARY) ($(VERSION))"

uninstall:
	rm -f $(GOBIN)/$(BINARY)

check: vet test ## gofmt + vet + test gate
	@test -z "$$(gofmt -l .)" || { gofmt -l .; echo "gofmt: the files above need formatting"; exit 1; }

test:
	go test ./...

vet:
	go vet ./...

fmt:
	gofmt -w .

completions: build ## bash/zsh/fish/powershell completions into ./completions
	mkdir -p completions
	./bin/$(BINARY) completion bash       > completions/$(BINARY).bash
	./bin/$(BINARY) completion zsh        > completions/_$(BINARY)
	./bin/$(BINARY) completion fish       > completions/$(BINARY).fish
	./bin/$(BINARY) completion powershell > completions/$(BINARY).ps1

man: build ## man pages into ./man/man1 (one page per command)
	mkdir -p man/man1
	./bin/$(BINARY) docs --format man --dir man/man1

cross: ## release binaries into ./dist (linux, darwin, windows)
	GOOS=linux   GOARCH=amd64 go build $(LDFLAGS) -o dist/$(BINARY)-linux-amd64 .
	GOOS=linux   GOARCH=arm64 go build $(LDFLAGS) -o dist/$(BINARY)-linux-arm64 .
	GOOS=darwin  GOARCH=amd64 go build $(LDFLAGS) -o dist/$(BINARY)-darwin-amd64 .
	GOOS=darwin  GOARCH=arm64 go build $(LDFLAGS) -o dist/$(BINARY)-darwin-arm64 .
	GOOS=windows GOARCH=amd64 go build $(LDFLAGS) -o dist/$(BINARY)-windows-amd64.exe .

clean:
	rm -rf bin dist completions man
