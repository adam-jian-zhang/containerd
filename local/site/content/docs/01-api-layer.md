---
title: "containerd API Layer"
weight: 20
---

# containerd API Layer

## Overview

The API layer defines all external interfaces for interacting with containerd. It is implemented using Protocol Buffers (protobuf) and exposed via gRPC and TTRPC protocols. The API is versioned to maintain backward compatibility and stability.

**Location**: `api/`

## API Structure

```
api/
├── services/          # gRPC service definitions
│   ├── containers/v1/ # Container management
│   ├── tasks/v1/      # Task execution
│   ├── images/v1/     # Image management
│   ├── snapshots/v1/  # Snapshot operations
│   ├── content/v1/    # Content store
│   ├── leases/v1/     # Lease management
│   ├── namespaces/v1/ # Namespace operations
│   ├── events/v1/     # Event streaming
│   ├── diff/v1/       # Diff operations
│   ├── sandbox/v1/    # Sandbox management
│   └── transfer/v1/   # Transfer operations
├── runtime/           # Runtime-specific APIs
│   ├── task/v2/       # Shim protocol v2
│   └── sandbox/v1/    # Sandbox runtime
├── events/            # Event type definitions
└── types/             # Common type definitions
```

## Core gRPC Services

### 1. Containers Service

**Package**: `containerd.services.containers.v1`  
**File**: `api/services/containers/v1/containers.proto`

Manages container metadata and lifecycle (state-independent view).

#### Service Definition

```protobuf
service Containers {
    rpc Get(GetContainerRequest) returns (GetContainerResponse);
    rpc List(ListContainersRequest) returns (ListContainersResponse);
    rpc ListStream(ListContainersRequest) returns (stream ListContainerMessage);
    rpc Create(CreateContainerRequest) returns (CreateContainerResponse);
    rpc Update(UpdateContainerRequest) returns (UpdateContainerResponse);
    rpc Delete(DeleteContainerRequest) returns (Empty);
}
```

#### Container Message


{{< figure src="/images/diagrams/diagram-0eeda8285e9c.svg" alt="Diagram" class="diagram" >}}


**Key Fields**:
- `id`: Unique container identifier (immutable)
- `labels`: Arbitrary key-value metadata
- `image`: Reference to the image used
- `runtime`: Runtime configuration (name + options)
- `spec`: OCI runtime specification (platform-specific)
- `snapshotter`: Snapshotter to use for rootfs
- `snapshot_key`: Key for the container's snapshot
- `sandbox`: ID of the sandbox this container belongs to
- `extensions`: Additional metadata for integrations

**Operations**:
- **Get**: Retrieve container by ID
- **List**: List all containers with optional filters
- **ListStream**: Stream container list
- **Create**: Create new container metadata
- **Update**: Update container fields (via field mask)
- **Delete**: Remove container metadata

### 2. Tasks Service

**Package**: `containerd.services.tasks.v1`  
**File**: `api/services/tasks/v1/tasks.proto`

Manages container execution (running processes).

#### Service Definition

```protobuf
service Tasks {
    rpc Create(CreateTaskRequest) returns (CreateTaskResponse);
    rpc Start(StartRequest) returns (StartResponse);
    rpc Delete(DeleteTaskRequest) returns (DeleteResponse);
    rpc DeleteProcess(DeleteProcessRequest) returns (DeleteResponse);
    rpc Get(GetRequest) returns (GetResponse);
    rpc List(ListTasksRequest) returns (ListTasksResponse);
    rpc Kill(KillRequest) returns (Empty);
    rpc Exec(ExecProcessRequest) returns (Empty);
    rpc ResizePty(ResizePtyRequest) returns (Empty);
    rpc CloseIO(CloseIORequest) returns (Empty);
    rpc Pause(PauseTaskRequest) returns (Empty);
    rpc Resume(ResumeTaskRequest) returns (Empty);
    rpc ListPids(ListPidsRequest) returns (ListPidsResponse);
    rpc Checkpoint(CheckpointTaskRequest) returns (CheckpointTaskResponse);
    rpc Update(UpdateTaskRequest) returns (Empty);
    rpc Metrics(MetricsRequest) returns (MetricsResponse);
    rpc Wait(WaitRequest) returns (WaitResponse);
}
```

#### Task Lifecycle


{{< figure src="/images/diagrams/diagram-114aeb726739.svg" alt="Diagram" class="diagram" >}}


**Key Operations**:
- **Create**: Create task from container (allocates shim)
- **Start**: Start the task's init process
- **Kill**: Send signal to task or process
- **Exec**: Execute additional process in task
- **Pause/Resume**: Freeze/unfreeze task execution
- **Checkpoint**: Create checkpoint for migration
- **Update**: Update task resources (CPU, memory)
- **Wait**: Wait for task/process exit
- **Metrics**: Get task metrics (CPU, memory, I/O)

**CreateTaskRequest Fields**:
- `container_id`: Container to create task from
- `rootfs`: Pre-chroot mounts (from snapshots)
- `stdin/stdout/stderr`: I/O configuration
- `terminal`: PTY mode
- `checkpoint`: Restore from checkpoint
- `options`: Runtime-specific options

### 3. Images Service

**Package**: `containerd.services.images.v1`  
**File**: `api/services/images/v1/images.proto`

Manages image metadata (name-to-content mappings).

#### Service Definition

```protobuf
service Images {
    rpc Get(GetImageRequest) returns (GetImageResponse);
    rpc List(ListImagesRequest) returns (ListImagesResponse);
    rpc Create(CreateImageRequest) returns (CreateImageResponse);
    rpc Update(UpdateImageRequest) returns (UpdateImageResponse);
    rpc Delete(DeleteImageRequest) returns (Empty);
}
```

#### Image Message


{{< figure src="/images/diagrams/diagram-125cd3eb576f.svg" alt="Diagram" class="diagram" >}}


**Key Concepts**:
- Images are **metadata only** - just name-to-descriptor mappings
- The `target` descriptor points to the image manifest in content store
- Actual content validation happens when content is accessed
- Images are essentially "tags" or "references"

**Operations**:
- **Get**: Retrieve image by name
- **List**: List all images with filters
- **Create**: Register new image name
- **Update**: Update image target or labels
- **Delete**: Remove image name (optionally sync cleanup)

### 4. Snapshots Service

**Package**: `containerd.services.snapshots.v1`  
**File**: `api/services/snapshots/v1/snapshots.proto`

Manages filesystem snapshots (layered filesystems).

#### Service Definition

```protobuf
service Snapshots {
    rpc Prepare(PrepareSnapshotRequest) returns (PrepareSnapshotResponse);
    rpc View(ViewSnapshotRequest) returns (ViewSnapshotResponse);
    rpc Mounts(MountsRequest) returns (MountsResponse);
    rpc Commit(CommitSnapshotRequest) returns (Empty);
    rpc Remove(RemoveSnapshotRequest) returns (Empty);
    rpc Stat(StatSnapshotRequest) returns (StatSnapshotResponse);
    rpc Update(UpdateSnapshotRequest) returns (UpdateSnapshotResponse);
    rpc List(ListSnapshotsRequest) returns (stream ListSnapshotsResponse);
    rpc Usage(UsageRequest) returns (UsageResponse);
    rpc Cleanup(CleanupRequest) returns (Empty);
}
```

#### Snapshot Lifecycle


{{< figure src="/images/diagrams/diagram-12633f9ed823.svg" alt="Diagram" class="diagram" >}}


**Snapshot Kinds**:
- **ACTIVE**: Writable snapshot being prepared
- **COMMITTED**: Read-only snapshot (immutable)
- **VIEW**: Read-only view (temporary)

**Key Operations**:
- **Prepare**: Create writable snapshot from parent
- **View**: Create read-only view of parent
- **Commit**: Make active snapshot immutable
- **Mounts**: Get mount points for snapshot
- **Remove**: Delete snapshot
- **Usage**: Get disk usage statistics

**Snapshot Info**:
- `name`: Snapshot identifier
- `parent`: Parent snapshot (for layering)
- `kind`: ACTIVE, COMMITTED, or VIEW
- `labels`: Arbitrary metadata

### 5. Content Service

**Package**: `containerd.services.content.v1`  
**File**: `api/services/content/v1/content.proto`

Manages content-addressable storage (immutable blobs).

#### Service Definition

```protobuf
service Content {
    rpc Info(InfoRequest) returns (InfoResponse);
    rpc Update(UpdateRequest) returns (UpdateResponse);
    rpc List(ListContentRequest) returns (stream ListContentResponse);
    rpc Delete(DeleteContentRequest) returns (Empty);
    rpc Read(ReadContentRequest) returns (stream ReadContentResponse);
    rpc Status(StatusRequest) returns (StatusResponse);
    rpc ListStatuses(ListStatusesRequest) returns (ListStatusesResponse);
    rpc Write(stream WriteContentRequest) returns (stream WriteContentResponse);
    rpc Abort(AbortRequest) returns (Empty);
}
```

#### Content Write Flow


{{< figure src="/images/diagrams/diagram-1c8a69c6c7f2.svg" alt="Diagram" class="diagram" >}}


**Key Concepts**:
- **Content-addressable**: Blobs identified by digest (SHA256)
- **Immutable**: Once committed, content never changes
- **Ingest process**: Write → Verify → Commit
- **Deduplication**: Same digest = same content

**Operations**:
- **Write**: Stream content (with expected digest)
- **Read**: Stream content by digest
- **Info**: Get content metadata (size, labels)
- **Status**: Check ongoing write status
- **Abort**: Cancel ongoing write
- **Delete**: Remove content blob

### 6. Leases Service

**Package**: `containerd.services.leases.v1`  
**File**: `api/services/leases/v1/leases.proto`

Manages resource leases for garbage collection.

#### Service Definition

```protobuf
service Leases {
    rpc Create(CreateRequest) returns (CreateResponse);
    rpc Delete(DeleteRequest) returns (Empty);
    rpc List(ListRequest) returns (ListResponse);
    rpc AddResource(AddResourceRequest) returns (Empty);
    rpc DeleteResource(DeleteResourceRequest) returns (Empty);
    rpc ListResources(ListResourcesRequest) returns (ListResourcesResponse);
}
```

**Lease Concept**:
- Leases protect resources from garbage collection
- Resources: snapshots, content, images
- Leases can be temporary (with expiration) or permanent
- Multiple leases can reference the same resource

**Operations**:
- **Create**: Create new lease
- **Delete**: Remove lease (may trigger GC)
- **AddResource**: Add resource to lease
- **DeleteResource**: Remove resource from lease
- **ListResources**: List resources in lease

### 7. Events Service

**Package**: `containerd.services.events.v1`  
**File**: `api/services/events/v1/events.proto`

Streams system events to clients.

#### Service Definition

```protobuf
service Events {
    rpc Publish(PublishRequest) returns (Empty);
    rpc Forward(ForwardRequest) returns (Empty);
    rpc Subscribe(SubscribeRequest) returns (stream Envelope);
}
```

**Event Types**:
- Container events: create, update, delete
- Task events: create, start, exit, delete, pause, resume
- Image events: create, update, delete
- Snapshot events: prepare, commit, remove
- Content events: ingestion progress

**Event Flow**:


{{< figure src="/images/diagrams/diagram-2324b87ae486.svg" alt="Diagram" class="diagram" >}}


### 8. Namespaces Service

**Package**: `containerd.services.namespaces.v1`  
**File**: `api/services/namespaces/v1/namespaces.proto`

Manages containerd namespaces for multi-tenancy.

#### Service Definition

```protobuf
service Namespaces {
    rpc Get(GetNamespaceRequest) returns (GetNamespaceResponse);
    rpc List(ListNamespacesRequest) returns (ListNamespacesResponse);
    rpc Create(CreateNamespaceRequest) returns (CreateNamespaceResponse);
    rpc Update(UpdateNamespaceRequest) returns (UpdateNamespaceResponse);
    rpc Delete(DeleteNamespaceRequest) returns (Empty);
}
```

**Namespace Isolation**:
- Each namespace has separate containers, images, content
- Namespace passed via gRPC metadata context
- Default Kubernetes namespace: `k8s.io`

### 9. Diff Service

**Package**: `containerd.services.diff.v1`  
**File**: `api/services/diff/v1/diff.proto`

Computes and applies filesystem diffs.

#### Service Definition

```protobuf
service Diff {
    rpc Apply(ApplyRequest) returns (ApplyResponse);
    rpc Diff(DiffRequest) returns (DiffResponse);
}
```

**Operations**:
- **Apply**: Apply diff (tar stream) to snapshot
- **Diff**: Compute diff between two snapshots

### 10. Sandbox Service

**Package**: `containerd.services.sandbox.v1`  
**File**: `api/services/sandbox/v1/sandbox.proto`

Manages sandbox lifecycle (pod-like constructs).

#### Service Definition

```protobuf
service Controller {
    rpc Create(ControllerCreateRequest) returns (ControllerCreateResponse);
    rpc Start(ControllerStartRequest) returns (ControllerStartResponse);
    rpc Platform(ControllerPlatformRequest) returns (ControllerPlatformResponse);
    rpc Stop(ControllerStopRequest) returns (ControllerStopResponse);
    rpc Wait(ControllerWaitRequest) returns (ControllerWaitResponse);
    rpc Status(ControllerStatusRequest) returns (ControllerStatusResponse);
    rpc Shutdown(ControllerShutdownRequest) returns (ControllerShutdownResponse);
}
```

**Sandbox Concept**:
- Logical grouping of containers (like Kubernetes pods)
- Shared network namespace
- Shared IPC namespace
- Managed by sandbox controllers

## Runtime API (TTRPC)

### Shim Protocol V2

**Package**: `containerd.task.v2`  
**File**: `api/runtime/task/v2/shim.proto`

The shim protocol defines communication between containerd daemon and container shims.

#### Service Definition

```protobuf
service Task {
    rpc State(StateRequest) returns (StateResponse);
    rpc Create(CreateTaskRequest) returns (CreateTaskResponse);
    rpc Start(StartRequest) returns (StartResponse);
    rpc Delete(DeleteRequest) returns (DeleteResponse);
    rpc Pids(PidsRequest) returns (PidsResponse);
    rpc Pause(PauseRequest) returns (Empty);
    rpc Resume(ResumeRequest) returns (Empty);
    rpc Checkpoint(CheckpointTaskRequest) returns (Empty);
    rpc Kill(KillRequest) returns (Empty);
    rpc Exec(ExecProcessRequest) returns (Empty);
    rpc ResizePty(ResizePtyRequest) returns (Empty);
    rpc CloseIO(CloseIORequest) returns (Empty);
    rpc Update(UpdateTaskRequest) returns (Empty);
    rpc Wait(WaitRequest) returns (WaitResponse);
    rpc Stats(StatsRequest) returns (StatsResponse);
    rpc Connect(ConnectRequest) returns (ConnectResponse);
    rpc Shutdown(ShutdownRequest) returns (Empty);
}
```

#### Shim Communication


{{< figure src="/images/diagrams/diagram-23459a661c2a.svg" alt="Diagram" class="diagram" >}}


**Key Features**:
- **Daemonless**: Shim survives daemon restarts
- **Per-container**: Each container has its own shim
- **TTRPC**: Lightweight RPC protocol
- **Event-driven**: Shim publishes events to daemon

## Common Types

### Descriptor

**File**: `api/types/descriptor.proto`

Describes content in the content store (OCI descriptor).

```protobuf
message Descriptor {
    string media_type = 1;
    string digest = 2;
    int64 size = 3;
    map<string, string> annotations = 5;
}
```

**Usage**: Points to manifests, configs, layers in content store.

### Mount

**File**: `api/types/mount.proto`

Describes a filesystem mount.

```protobuf
message Mount {
    string type = 1;
    string source = 2;
    repeated string options = 3;
}
```

**Usage**: Returned by snapshot service for mounting layers.

### Platform

**File**: `api/types/platform.proto`

Describes target platform (OS/architecture).

```protobuf
message Platform {
    string os = 1;
    string architecture = 2;
    string variant = 3;
}
```

**Usage**: Multi-platform image support.

## API Versioning

### Version Strategy

containerd uses semantic versioning for APIs:

- **v1**: Stable, backward-compatible
- **v2**: Major changes (breaking)
- **v3**: Next generation

### Compatibility

- Old clients can talk to new servers
- New clients can talk to old servers (with feature detection)
- Deprecation warnings for old APIs

### Migration Path


{{< figure src="/images/diagrams/diagram-28f287d3f8b2.svg" alt="Diagram" class="diagram" >}}


## API Communication Patterns

### Request-Response

Standard RPC pattern for most operations:

```
Client → Request → Server → Response → Client
```

### Streaming

Used for large data transfers:

- **Server streaming**: List operations, content read
- **Client streaming**: Content write
- **Bidirectional**: Real-time operations

### Events

Publish-subscribe pattern for system events:

```
Publisher → Event → Exchange → Subscribers
```

## Error Handling

### Error Codes

containerd uses standard gRPC status codes:

- `NOT_FOUND`: Resource doesn't exist
- `ALREADY_EXISTS`: Resource already exists
- `INVALID_ARGUMENT`: Invalid request parameters
- `FAILED_PRECONDITION`: Operation not allowed in current state
- `UNAVAILABLE`: Service temporarily unavailable

### Error Details

Errors include:
- Status code
- Error message
- Additional details (via `errdefs` package)

## Authentication & Authorization

### gRPC Metadata

- Namespace passed via `containerd-namespace` header
- Authentication via Unix socket permissions
- No built-in user authentication (delegated to orchestrator)

### Security Model


{{< figure src="/images/diagrams/diagram-386eec02b7ac.svg" alt="Diagram" class="diagram" >}}


## API Usage Patterns

### Container Creation Pattern


{{< figure src="/images/diagrams/diagram-3f5d074ed5ce.svg" alt="Diagram" class="diagram" >}}


### Image Pull Pattern


{{< figure src="/images/diagrams/diagram-4cdfeee3aa19.svg" alt="Diagram" class="diagram" >}}


## API Extensions

### Custom Extensions

Containers and images support `extensions` field:

```protobuf
map<string, google.protobuf.Any> extensions = 10;
```

**Usage**:
- CRI metadata
- Custom orchestrator data
- Integration-specific information

### Plugin Services

Custom plugins can register additional gRPC services:

```go
registry.Register(&plugin.Registration{
    Type: plugins.GRPCPlugin,
    ID:   "custom",
    InitFn: func(ic *plugin.InitContext) (interface{}, error) {
        // Return gRPC service implementation
    },
})
```

## Performance Considerations

### Batching

- Use `List` with filters instead of multiple `Get` calls
- Stream operations for large datasets

### Caching

- Client-side caching of metadata
- Lease management for resource lifecycle

### Connection Pooling

- Reuse gRPC connections
- Connection multiplexing built into gRPC

## API Tools

### Protocol Buffer Compiler

```bash
protoc --go_out=. --go-grpc_out=. api/services/containers/v1/containers.proto
```

### API Documentation

- Generated from `.proto` files
- Available at pkg.go.dev
- Includes field descriptions and usage

## Summary

The containerd API layer provides:

1. **Comprehensive Services**: All container operations via gRPC
2. **Versioned APIs**: Backward compatibility guarantees
3. **Content-Addressable**: Immutable content storage
4. **Event-Driven**: Real-time system events
5. **Extensible**: Custom extensions and plugins
6. **Efficient**: Streaming for large data transfers
7. **Isolated**: Namespace-based multi-tenancy
8. **Standard**: Based on OCI specifications

The API is designed to be consumed by:
- Go client SDK
- CLI tools (ctr, crictl)
- CRI plugin (Kubernetes)
- Custom integrations
- External orchestrators
