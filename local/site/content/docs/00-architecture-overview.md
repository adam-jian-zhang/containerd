---
title: "containerd Architecture Overview"
weight: 10
---

# containerd Architecture Overview

## Introduction

containerd is an industry-standard container runtime with an emphasis on simplicity, robustness, and portability. It is designed to be embedded into a larger system rather than being used directly by developers or end-users. containerd is a CNCF graduated project and serves as the container runtime for Kubernetes and other container orchestration platforms.

**Version**: v2.0+  
**Language**: Go 1.24.3  
**License**: Apache 2.0

## High-Level Architecture

containerd follows a modular, plugin-based architecture that provides flexibility and extensibility. The system is composed of several key layers:


{{< figure src="/images/diagrams/diagram-0eeda8285e9c.svg" alt="Diagram" class="diagram" >}}


## Core Design Principles

### 1. Smart Client Model

containerd implements a "smart client" architecture where high-level operations are performed by the client rather than the daemon. This includes:

- Creating container specifications
- Interacting with image registries
- Loading images from tar archives
- Image pulling and pushing logic

The daemon focuses on:
- Low-level container lifecycle management
- Content and metadata storage
- Snapshot management
- Task execution and supervision

### 2. Plugin-Based Architecture

The entire system is built around a plugin architecture that allows extending functionality without modifying the core daemon. Plugin types include:

- **Service Plugins**: Internal services (containers, images, tasks)
- **GRPC Plugins**: External gRPC service endpoints
- **TTRPC Plugins**: Shim communication services
- **Runtime Plugins**: Container runtime implementations
- **Snapshot Plugins**: Filesystem snapshot implementations
- **Content Plugins**: Content storage backends
- **Diff Plugins**: Filesystem diff/apply implementations
- **GC Plugins**: Garbage collection policies
- **Event Plugins**: Event handling and distribution

### 3. Namespace Isolation

containerd uses namespaces to provide multi-tenancy and isolation:

- Each namespace has its own set of containers, images, and content
- Metadata is stored per-namespace in BoltDB
- Default namespace for Kubernetes: `k8s.io`
- Namespaces are passed via gRPC context

### 4. Content-Addressable Storage

All content (image layers, configs) is stored using content-addressable storage:

- Content is identified by its digest (SHA256)
- Immutable storage prevents corruption
- Deduplication across images and containers
- Efficient layer sharing

## Major Components

### 1. API Layer

**Location**: `api/`

The API layer defines all gRPC and protobuf services:

- **services/**: GRPC service definitions (containers, images, tasks, etc.)
- **events/**: Event type definitions
- **types/**: Common type definitions
- **runtime/**: Runtime-specific APIs (shim protocol)

All services are versioned (v1, v2, v3) for API stability.

### 2. Core Layer

**Location**: `core/`

The core layer implements the fundamental abstractions:

- **containers/**: Container metadata and lifecycle
- **content/**: Content store interface and implementations
- **snapshots/**: Snapshot interface for filesystem layers
- **metadata/**: BoltDB-backed metadata storage
- **images/**: Image management and manipulation
- **diff/**: Filesystem diff and apply operations
- **events/**: Event publishing and subscription
- **leases/**: Resource lease management for garbage collection
- **runtime/**: Runtime abstraction and task management
- **sandbox/**: Sandbox controller for pod-like constructs
- **transfer/**: Image transfer operations

### 3. Plugin Layer

**Location**: `plugins/`

Plugin implementations for various subsystems:

- **content/local/**: Local filesystem content store
- **snapshots/**: Snapshot implementations (overlay, btrfs, devmapper, etc.)
- **diff/**: Diff implementations (walking, erofs)
- **services/**: GRPC service plugin implementations
- **cri/**: Kubernetes CRI plugin
- **gc/**: Garbage collection scheduler
- **metadata/**: Metadata store plugin

### 4. Client Layer

**Location**: `client/`

Go SDK for interacting with containerd:

- High-level container operations
- Image pull/push
- Task creation and management
- Event streaming
- Namespace management

### 5. Command Layer

**Location**: `cmd/`

Command-line tools and daemons:

- **containerd/**: Main daemon
- **ctr/**: CLI tool for containerd
- **containerd-shim-runc-v2/**: Shim for runc runtime
- **containerd-stress/**: Stress testing tool

### 6. Internal Layer

**Location**: `internal/`

Internal packages not exposed as public APIs:

- **cri/**: CRI implementation internals
- **nri/**: Node Resource Interface integration
- **oom/**: Out-of-memory handling
- **userns/**: User namespace support

### 7. Package Layer

**Location**: `pkg/`

Utility packages used across the codebase:

- **archive/**: Tar archive handling
- **cio/**: Container I/O management
- **oci/**: OCI spec generation and manipulation
- **sys/**: System-level utilities
- **tracing/**: OpenTelemetry tracing

## Data Flow

### Container Creation Flow


{{< figure src="/images/diagrams/diagram-114aeb726739.svg" alt="Diagram" class="diagram" >}}


### Task Execution Flow


{{< figure src="/images/diagrams/diagram-125cd3eb576f.svg" alt="Diagram" class="diagram" >}}


### Image Pull Flow


{{< figure src="/images/diagrams/diagram-12633f9ed823.svg" alt="Diagram" class="diagram" >}}


## Storage Architecture

### Content Store

The content store manages immutable content blobs:

```
<root>/io.containerd.content.v1.content/
├── blobs/
│   └── sha256/
│       ├── <digest1>
│       ├── <digest2>
│       └── ...
└── ingest/
    └── <temporary-ingests>
```

- **blobs/**: Finalized, immutable content
- **ingest/**: Temporary location for content being written

### Metadata Store

Metadata is stored in BoltDB:

```
<root>/io.containerd.metadata.v1.bolt/
└── meta.db (BoltDB)
    ├── v1/
    │   └── <namespace>/
    │       ├── containers/
    │       ├── images/
    │       ├── snapshots/
    │       ├── leases/
    │       └── sandboxes/
```

### Snapshot Store

Snapshots provide layered filesystem views:

```
<root>/io.containerd.snapshotter.v1.overlayfs/
├── snapshots/
│   ├── 1/
│   │   └── fs/
│   ├── 2/
│   │   └── fs/
│   └── ...
└── metadata.db
```

Different snapshot implementations:
- **overlay**: OverlayFS (default on Linux)
- **btrfs**: Btrfs subvolumes
- **devmapper**: Device mapper thin provisioning
- **native**: Windows native snapshotter
- **erofs**: Enhanced Read-Only File System

## Communication Protocols

### gRPC Services

Primary communication protocol for clients:

- **Address**: Unix socket (Linux/macOS) or Named pipe (Windows)
- **Default**: `/run/containerd/containerd.sock`
- **Services**: All high-level APIs (containers, images, tasks, etc.)
- **Authentication**: Unix socket permissions

### TTRPC Services

Lightweight RPC for shim communication:

- **Purpose**: Daemon-to-shim communication
- **Address**: Separate socket per shim
- **Protocol**: TTRPC (simpler than gRPC)
- **Services**: Task management, events

## Runtime Model

### Shim Architecture

containerd uses a shim-based architecture for container management:


{{< figure src="/images/diagrams/diagram-1c8a69c6c7f2.svg" alt="Diagram" class="diagram" >}}


Benefits:
- **Daemonless**: Containers survive daemon restarts
- **Isolation**: Each shim is independent
- **Resource efficiency**: Shims are lightweight

### Runtime V2 Protocol

The shim implements the Runtime V2 protocol:

1. **Binary discovery**: Runtime binaries in `$PATH`
2. **Naming convention**: `containerd-shim-<runtime>-<version>`
3. **Example**: `containerd-shim-runc-v2`
4. **Protocol**: TTRPC-based task service

## Event System

containerd has a comprehensive event system:


{{< figure src="/images/diagrams/diagram-2324b87ae486.svg" alt="Diagram" class="diagram" >}}


Event types:
- Container lifecycle (create, delete, update)
- Task lifecycle (start, exit, pause, resume)
- Image lifecycle (create, update, delete)
- Snapshot lifecycle (prepare, commit, remove)
- Content ingestion events

## Garbage Collection

containerd uses a lease-based garbage collection system:

### Lease Model


{{< figure src="/images/diagrams/diagram-23459a661c2a.svg" alt="Diagram" class="diagram" >}}


- **Leases**: Temporary or permanent references to resources
- **Reference tracking**: Metadata store tracks all references
- **Scheduled GC**: Periodic garbage collection runs
- **Manual GC**: Can be triggered via API

## CRI Integration

The CRI (Container Runtime Interface) plugin provides Kubernetes integration:


{{< figure src="/images/diagrams/diagram-28f287d3f8b2.svg" alt="Diagram" class="diagram" >}}


Key features:
- **Pod sandboxes**: Managed via sandbox controllers
- **Container lifecycle**: Full CRI container operations
- **Image management**: CRI image service operations
- **Streaming**: Exec, attach, port-forward via streaming server
- **CNI integration**: Network plugin support
- **Runtime handlers**: Multiple runtime configurations

## Security Features

### 1. Namespace Isolation

- Process isolation via Linux namespaces
- User namespace support for rootless containers
- Network namespace management

### 2. Capabilities

- Fine-grained Linux capability control
- Default capability dropping
- Custom capability sets per container

### 3. Seccomp

- Seccomp profile support
- Default seccomp profiles
- Custom profile loading

### 4. AppArmor/SELinux

- Mandatory Access Control (MAC) support
- Profile management
- Label-based security

### 5. Image Verification

- Image signature verification
- Content trust integration
- Custom verifier plugins

## Observability

### Metrics

- Prometheus metrics endpoint
- Container metrics (CPU, memory, I/O)
- Runtime metrics
- API operation metrics

### Tracing

- OpenTelemetry integration
- Distributed tracing support
- Span propagation across components

### Logging

- Structured logging (logrus)
- Configurable log levels
- Per-plugin logging configuration

## Configuration

containerd is configured via TOML configuration file:

**Default location**: `/etc/containerd/config.toml`

Key configuration sections:
- **root**: Data directory
- **state**: Runtime state directory
- **grpc**: gRPC server configuration
- **ttrpc**: TTRPC server configuration
- **plugins**: Per-plugin configuration
- **debug**: Debug and metrics endpoints
- **timeouts**: Operation timeouts

## Extension Points

containerd can be extended through:

1. **External plugins**: Proxy plugins via gRPC
2. **Runtime plugins**: Custom OCI runtimes
3. **Snapshot plugins**: Custom snapshot implementations
4. **Content plugins**: Custom content stores
5. **NRI plugins**: Node Resource Interface plugins
6. **Image verifiers**: Custom image verification

## Performance Characteristics

### Scalability

- Supports thousands of containers per node
- Efficient resource usage
- Minimal memory footprint per container

### Optimization

- Content deduplication
- Lazy pulling support
- Parallel layer extraction
- Efficient snapshot management

## Directory Structure Summary

```
containerd/
├── api/                    # Protobuf definitions and generated code
├── client/                 # Go client SDK
├── cmd/                    # Command-line tools and daemon
│   ├── containerd/        # Main daemon
│   ├── ctr/               # CLI tool
│   └── containerd-shim-runc-v2/  # Shim implementation
├── core/                   # Core abstractions and interfaces
│   ├── containers/        # Container management
│   ├── content/           # Content store
│   ├── snapshots/         # Snapshot management
│   ├── metadata/          # Metadata storage
│   ├── images/            # Image management
│   ├── runtime/           # Runtime abstractions
│   └── sandbox/           # Sandbox management
├── plugins/                # Plugin implementations
│   ├── content/           # Content store plugins
│   ├── snapshots/         # Snapshot plugins
│   ├── services/          # Service plugins
│   └── cri/               # CRI plugin
├── internal/               # Internal packages
│   ├── cri/               # CRI implementation
│   └── nri/               # NRI integration
├── pkg/                    # Utility packages
└── docs/                   # Documentation
```

## Conclusion

containerd's architecture is designed for:

- **Modularity**: Plugin-based extensibility
- **Reliability**: Daemonless containers via shims
- **Performance**: Efficient resource usage
- **Standards compliance**: OCI and CRI compatibility
- **Simplicity**: Focused scope as a container runtime

The architecture supports various use cases from Kubernetes integration to standalone container management, while maintaining a clean separation of concerns and extensibility.
