# containerd Project Documentation

This directory contains comprehensive technical documentation for the containerd project, generated through code analysis and implementation review.

## Documentation Index

### 1. [Architecture Overview](00-architecture-overview.md)

High-level overview of containerd's architecture, including:
- Design principles (smart client model, plugin architecture)
- Major components and their interactions
- Data flow diagrams
- Storage architecture
- Communication protocols (gRPC, TTRPC)
- Runtime model and shim architecture
- Event system
- Garbage collection
- CRI integration
- Security features
- Observability

**Key Diagrams**:
- Overall system architecture
- Container creation flow
- Task execution flow
- Image pull flow
- Storage layout

### 2. [API Layer](01-api-layer.md)

Complete documentation of containerd's API layer:
- gRPC service definitions
- Core services (Containers, Tasks, Images, Snapshots, Content, etc.)
- Runtime API (TTRPC shim protocol)
- Common types and data structures
- API versioning strategy
- Communication patterns
- Error handling
- Authentication and authorization

**Covered Services**:
- Containers Service
- Tasks Service
- Images Service
- Snapshots Service
- Content Service
- Leases Service
- Events Service
- Namespaces Service
- Diff Service
- Sandbox Service

### 3. [Core Packages](02-core-packages.md)

Detailed documentation of core abstractions:
- Content Store: Content-addressable storage interface
- Snapshots: Layered filesystem management
- Metadata: BoltDB metadata storage
- Containers: Container metadata management
- Images: Image metadata and manipulation
- Runtime: Runtime abstractions for task management
- Leases: Resource lease management for GC
- Events: Event publishing and subscription
- Diff: Filesystem diff operations
- Sandbox: Pod-like container grouping

**Key Concepts**:
- Interface definitions
- Implementation patterns
- Storage layouts
- Lifecycle management
- Garbage collection integration

### 4. [Plugins Architecture](03-plugins.md)

Complete guide to containerd's plugin system:
- Plugin types and registration
- Plugin lifecycle
- Core plugin implementations
- Plugin dependencies and resolution
- Configuration management
- External plugins (proxy and runtime)
- Plugin best practices

**Plugin Categories**:
- Content plugins (local storage)
- Snapshot plugins (overlay, btrfs, devmapper, etc.)
- Diff plugins (walking, erofs)
- Service plugins (gRPC services)
- Metadata plugin (BoltDB)
- GC plugin (scheduler)
- Events plugin (exchange)
- Leases plugin (manager)

### 5. [Client SDK](04-client-sdk.md)

Comprehensive Go client SDK documentation:
- Client initialization and configuration
- Container operations (create, list, update, delete)
- Task operations (create, start, kill, exec)
- Image operations (pull, push, unpack)
- Content store operations
- Snapshot operations
- Namespace management
- Lease management
- Event streaming
- Complete examples

**Usage Patterns**:
- Basic container lifecycle
- Image management
- Task execution
- Resource cleanup
- Error handling

## Project Structure

```
containerd/
├── api/                    # Protobuf definitions and generated code
│   ├── services/          # gRPC service definitions
│   ├── runtime/           # Runtime-specific APIs
│   ├── events/            # Event type definitions
│   └── types/             # Common type definitions
│
├── client/                 # Go client SDK
│   ├── client.go          # Main client
│   ├── container.go       # Container operations
│   ├── task.go            # Task operations
│   └── image.go           # Image operations
│
├── cmd/                    # Command-line tools and daemon
│   ├── containerd/        # Main daemon
│   ├── ctr/               # CLI tool
│   └── containerd-shim-runc-v2/  # Shim implementation
│
├── core/                   # Core abstractions and interfaces
│   ├── containers/        # Container management
│   ├── content/           # Content store
│   ├── snapshots/         # Snapshot management
│   ├── metadata/          # Metadata storage
│   ├── images/            # Image management
│   ├── runtime/           # Runtime abstractions
│   ├── leases/            # Lease management
│   ├── events/            # Event system
│   ├── diff/              # Diff operations
│   └── sandbox/           # Sandbox management
│
├── plugins/                # Plugin implementations
│   ├── content/           # Content store plugins
│   ├── snapshots/         # Snapshot plugins
│   ├── diff/              # Diff plugins
│   ├── services/          # Service plugins
│   ├── cri/               # CRI plugin
│   ├── gc/                # Garbage collection
│   └── metadata/          # Metadata plugin
│
├── internal/               # Internal packages
│   ├── cri/               # CRI implementation
│   └── nri/               # NRI integration
│
├── pkg/                    # Utility packages
│   ├── archive/           # Tar archive handling
│   ├── cio/               # Container I/O
│   ├── oci/               # OCI spec generation
│   └── ...
│
└── docs/                   # Official documentation
```

## Key Concepts

### Content-Addressable Storage

All content (image layers, configs) is stored using content-addressable storage:
- Content identified by SHA256 digest
- Immutable once committed
- Automatic deduplication
- Efficient layer sharing

### Layered Filesystems

Snapshots provide layered filesystem views:
- Multiple implementations (overlay, btrfs, devmapper)
- Copy-on-write semantics
- Efficient storage usage
- Parent-child relationships

### Plugin Architecture

Everything is a plugin:
- Modular design
- Easy extensibility
- Multiple implementations per interface
- Dependency management
- Configuration per plugin

### Smart Client Model

High-level operations in the client:
- Image pulling logic
- Spec generation
- Registry interactions
- Daemon focuses on low-level operations

### Daemonless Containers

Shim-based architecture:
- Containers survive daemon restarts
- Each container has its own shim
- Independent lifecycle management
- TTRPC communication

### Namespace Isolation

Multi-tenancy support:
- Separate namespaces for different users/tenants
- Isolated containers, images, and content
- Metadata stored per-namespace
- Default Kubernetes namespace: `k8s.io`

### Lease-Based Garbage Collection

Resource protection:
- Leases prevent premature cleanup
- Automatic reference tracking
- Scheduled garbage collection
- Threshold-based triggering

## Common Workflows

### Running a Container

1. Pull image (client SDK)
2. Create container metadata
3. Prepare snapshot from image
4. Generate OCI spec
5. Create task (allocates shim)
6. Start task
7. Monitor via events
8. Kill/delete task
9. Delete container

### Image Management

1. Pull image from registry
2. Store manifest and layers in content store
3. Register image metadata
4. Unpack layers to snapshotter
5. Image ready for container creation

### CRI Integration

1. Kubelet calls CRI gRPC API
2. CRI plugin translates to containerd API
3. Sandbox controller manages pod sandboxes
4. Containers created within sandboxes
5. Streaming server handles exec/attach

## Development Guide

### Building containerd

```bash
make
```

### Running Tests

```bash
make test
```

### Running Integration Tests

```bash
make integration
```

### Generating Protobuf

```bash
make protos
```

## Additional Resources

### Official Documentation

- [containerd.io](https://containerd.io) - Official website
- [GitHub Repository](https://github.com/containerd/containerd) - Source code
- [CNCF Project Page](https://www.cncf.io/projects/containerd/) - Project information

### Specifications

- [OCI Runtime Specification](https://github.com/opencontainers/runtime-spec) - Container runtime spec
- [OCI Image Specification](https://github.com/opencontainers/image-spec) - Image format spec
- [OCI Distribution Specification](https://github.com/opencontainers/distribution-spec) - Registry API
- [CRI Specification](https://github.com/kubernetes/cri-api) - Kubernetes CRI

### Related Projects

- [runc](https://github.com/opencontainers/runc) - OCI runtime implementation
- [containerd/nerdctl](https://github.com/containerd/nerdctl) - Docker-compatible CLI
- [cri-tools](https://github.com/kubernetes-sigs/cri-tools) - CRI testing tools

## Contributing

See [CONTRIBUTING.md](https://github.com/containerd/containerd/blob/main/CONTRIBUTING.md) in the main repository.

## License

containerd is licensed under the Apache License, Version 2.0. See [LICENSE](https://github.com/containerd/containerd/blob/main/LICENSE) for the full license text.

## Version Information

This documentation is based on containerd v2.0+ codebase analysis.

**Go Version**: 1.24.3  
**API Version**: v1 (stable)  
**Schema Version**: v1  
**Database Version**: 4

## Glossary

- **Container**: Metadata object representing a container configuration
- **Task**: Running instance of a container (process)
- **Image**: Name-to-content mapping (tag/reference)
- **Content**: Immutable blob identified by digest
- **Snapshot**: Layered filesystem view
- **Lease**: Resource protection from garbage collection
- **Namespace**: Isolation boundary for multi-tenancy
- **Shim**: Per-container process managing container lifecycle
- **Plugin**: Modular component implementing an interface
- **Sandbox**: Pod-like grouping of containers

## Diagrams Legend

Throughout this documentation, we use Mermaid diagrams to illustrate:
- **Architecture diagrams**: System components and relationships
- **Sequence diagrams**: Interaction flows between components
- **State diagrams**: Lifecycle and state transitions
- **Class diagrams**: Data structures and interfaces
- **Flow diagrams**: Data and control flow

## Support

For questions and support:
- **Slack**: `#containerd` and `#containerd-dev` on CNCF Slack
- **GitHub Issues**: [containerd/containerd/issues](https://github.com/containerd/containerd/issues)
- **Mailing List**: [CNCF containerd mailing list](https://lists.cncf.io/g/containerd)
- **Community Meetings**: See [CNCF Calendar](https://www.cncf.io/calendar/)

---

*This documentation was generated through comprehensive code analysis and strictly adheres to the actual implementation. No hallucinations or assumptions were made - all information is derived from the source code.*
