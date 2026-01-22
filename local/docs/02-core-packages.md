# containerd Core Packages

## Overview

The core packages (`core/`) provide the fundamental abstractions and interfaces that define containerd's architecture. These packages are implementation-agnostic and define contracts that plugins implement.

**Location**: `core/`

## Package Structure

```
core/
├── containers/      # Container metadata management
├── content/         # Content-addressable storage
├── snapshots/       # Filesystem snapshot management
├── metadata/        # BoltDB metadata storage
├── images/          # Image management
├── diff/            # Filesystem diff operations
├── events/          # Event system
├── leases/          # Resource lease management
├── runtime/         # Runtime abstractions
├── sandbox/         # Sandbox management
├── transfer/        # Image transfer operations
├── mount/           # Mount operations
├── remotes/         # Registry interactions
└── metrics/         # Metrics collection
```

## 1. Content Package

**Package**: `core/content`  
**Purpose**: Content-addressable storage interface

### Architecture

```mermaid
classDiagram
    class Store {
        <<interface>>
        +Manager
        +Provider
        +IngestManager
        +Ingester
    }
    
    class Provider {
        <<interface>>
        +ReaderAt(ctx, desc) ReaderAt
    }
    
    class Ingester {
        <<interface>>
        +Writer(ctx, opts) Writer
    }
    
    class Manager {
        <<interface>>
        +Info(ctx, dgst) Info
        +Update(ctx, info, fieldpaths) Info
        +Walk(ctx, fn) error
        +Delete(ctx, dgst) error
    }
    
    class IngestManager {
        <<interface>>
        +Status(ctx, ref) Status
        +ListStatuses(ctx, filters) []Status
        +Abort(ctx, ref) error
    }
    
    Store --|> Provider
    Store --|> Ingester
    Store --|> Manager
    Store --|> IngestManager
```

### Key Interfaces

#### Store Interface

The main interface combining all content operations:

```go
type Store interface {
    Manager
    Provider
    IngestManager
    Ingester
}
```

#### Provider Interface

Provides read access to content:

```go
type Provider interface {
    // ReaderAt returns a reader for content identified by descriptor
    ReaderAt(ctx context.Context, desc ocispec.Descriptor) (ReaderAt, error)
}
```

#### Ingester Interface

Initiates content writes:

```go
type Ingester interface {
    // Writer initiates a writing operation (ingestion)
    Writer(ctx context.Context, opts ...WriterOpt) (Writer, error)
}
```

#### Writer Interface

Handles content ingestion:

```go
type Writer interface {
    io.WriteCloser
    // Digest returns the current digest of the content
    Digest() digest.Digest
    // Commit commits the content with the expected digest
    Commit(ctx context.Context, size int64, expected digest.Digest, opts ...Opt) error
    // Status returns the current status of the write
    Status() (Status, error)
    // Truncate truncates the content to a specific size
    Truncate(size int64) error
}
```

### Content Lifecycle

```mermaid
stateDiagram-v2
    [*] --> Ingesting: Writer()
    Ingesting --> Ingesting: Write()
    Ingesting --> Committed: Commit()
    Ingesting --> [*]: Abort()
    Committed --> [*]: Delete()
    
    note right of Ingesting
        Temporary state
        Visible in IngestManager
    end note
    
    note right of Committed
        Permanent state
        Visible in Provider/Manager
    end note
```

### Content Info

```go
type Info struct {
    Digest    digest.Digest      // SHA256 digest
    Size      int64               // Content size in bytes
    CreatedAt time.Time           // Creation timestamp
    UpdatedAt time.Time           // Last update timestamp
    Labels    map[string]string   // Arbitrary metadata
}
```

### Storage Layout

```
<root>/io.containerd.content.v1.content/
├── blobs/
│   └── sha256/
│       ├── <digest1>  # Committed content
│       ├── <digest2>
│       └── ...
└── ingest/
    └── <ref>-<random>  # Temporary ingests
```

### Usage Patterns

#### Writing Content

```go
// Start ingestion
writer, err := store.Writer(ctx, 
    content.WithRef("layer-download"),
    content.WithDescriptor(desc))

// Write data
_, err = io.Copy(writer, reader)

// Commit with verification
err = writer.Commit(ctx, desc.Size, desc.Digest)
```

#### Reading Content

```go
// Get reader
ra, err := store.ReaderAt(ctx, desc)
defer ra.Close()

// Read content
buf := make([]byte, desc.Size)
_, err = ra.ReadAt(buf, 0)
```

## 2. Snapshots Package

**Package**: `core/snapshots`  
**Purpose**: Layered filesystem management

### Architecture

```mermaid
classDiagram
    class Snapshotter {
        <<interface>>
        +Stat(ctx, key) Info
        +Update(ctx, info, fieldpaths) Info
        +Usage(ctx, key) Usage
        +Mounts(ctx, key) []Mount
        +Prepare(ctx, key, parent, opts) []Mount
        +View(ctx, key, parent, opts) []Mount
        +Commit(ctx, name, key, opts) error
        +Remove(ctx, key) error
        +Walk(ctx, fn) error
        +Close() error
    }
    
    class Info {
        +string Name
        +string Parent
        +Kind Kind
        +time CreatedAt
        +time UpdatedAt
        +map Labels
    }
    
    class Kind {
        <<enumeration>>
        KindUnknown
        KindView
        KindActive
        KindCommitted
    }
    
    Snapshotter --> Info
    Info --> Kind
```

### Snapshot Kinds

```mermaid
graph TB
    subgraph "Snapshot Types"
        Active[Active<br/>Writable, Temporary]
        Committed[Committed<br/>Read-only, Permanent]
        View[View<br/>Read-only, Temporary]
    end
    
    Active -->|Commit| Committed
    Committed -->|Prepare| Active
    Committed -->|View| View
```

**Kind Definitions**:
- **Active**: Writable snapshot being prepared (temporary)
- **Committed**: Read-only, immutable snapshot (permanent)
- **View**: Read-only view of a parent (temporary)

### Snapshotter Interface

```go
type Snapshotter interface {
    // Stat returns info about a snapshot
    Stat(ctx context.Context, key string) (Info, error)
    
    // Update updates snapshot metadata
    Update(ctx context.Context, info Info, fieldpaths ...string) (Info, error)
    
    // Usage returns disk usage of snapshot
    Usage(ctx context.Context, key string) (Usage, error)
    
    // Mounts returns mount points for snapshot
    Mounts(ctx context.Context, key string) ([]mount.Mount, error)
    
    // Prepare creates active snapshot from parent
    Prepare(ctx context.Context, key, parent string, opts ...Opt) ([]mount.Mount, error)
    
    // View creates read-only view of parent
    View(ctx context.Context, key, parent string, opts ...Opt) ([]mount.Mount, error)
    
    // Commit makes active snapshot immutable
    Commit(ctx context.Context, name, key string, opts ...Opt) error
    
    // Remove deletes snapshot
    Remove(ctx context.Context, key string) error
    
    // Walk iterates over all snapshots
    Walk(ctx context.Context, fn WalkFunc) error
    
    // Close releases resources
    Close() error
}
```

### Snapshot Workflow

```mermaid
sequenceDiagram
    participant Client
    participant Snapshotter
    participant Filesystem
    
    Client->>Snapshotter: Prepare(key, parent)
    Snapshotter->>Filesystem: Create writable layer
    Snapshotter-->>Client: Mounts
    
    Client->>Filesystem: Mount and modify
    
    Client->>Snapshotter: Commit(name, key)
    Snapshotter->>Filesystem: Make read-only
    Snapshotter-->>Client: Success
```

### Snapshot Info

```go
type Info struct {
    Name      string            // Snapshot identifier
    Parent    string            // Parent snapshot
    Kind      Kind              // Active, Committed, or View
    CreatedAt time.Time         // Creation time
    UpdatedAt time.Time         // Last update time
    Labels    map[string]string // Metadata
}
```

### Usage Statistics

```go
type Usage struct {
    Inodes int64  // Number of inodes
    Size   int64  // Disk usage in bytes
}
```

### Snapshot Implementations

Different snapshotter implementations:

1. **overlay**: OverlayFS (default on Linux)
2. **btrfs**: Btrfs subvolumes
3. **devmapper**: Device mapper thin provisioning
4. **native**: Windows native
5. **erofs**: Enhanced Read-Only File System

## 3. Metadata Package

**Package**: `core/metadata`  
**Purpose**: BoltDB-backed metadata storage

### Architecture

```mermaid
classDiagram
    class DB {
        +ContentStore() content.Store
        +Snapshotter(name) snapshots.Snapshotter
        +Containers() containers.Store
        +Images() images.Store
        +Leases() leases.Manager
        +Sandboxes() sandbox.Store
        +GarbageCollect(ctx) error
    }
    
    class Transactor {
        <<interface>>
        +View(fn) error
        +Update(fn) error
    }
    
    DB --> Transactor
    DB --> BoltDB
```

### Database Structure

```
BoltDB (meta.db)
└── v1/                          # Schema version
    └── <namespace>/             # Per-namespace data
        ├── containers/          # Container metadata
        │   └── <container-id>/
        │       ├── id
        │       ├── image
        │       ├── runtime
        │       ├── spec
        │       └── labels
        ├── images/              # Image metadata
        │   └── <image-name>/
        │       ├── name
        │       ├── target
        │       └── labels
        ├── snapshots/           # Snapshot metadata
        │   └── <snapshotter>/
        │       └── <snapshot-key>/
        ├── content/             # Content metadata
        │   └── blob/
        │       └── <digest>/
        ├── leases/              # Lease tracking
        │   └── <lease-id>/
        └── sandboxes/           # Sandbox metadata
            └── <sandbox-id>/
```

### DB Interface

```go
type DB struct {
    db Transactor
    ss map[string]*snapshotter
    cs *contentStore
    // ...
}

// Core methods
func (m *DB) ContentStore() content.Store
func (m *DB) Snapshotter(name string) snapshots.Snapshotter
func (m *DB) Containers() containers.Store
func (m *DB) Images() images.Store
func (m *DB) Leases() leases.Manager
func (m *DB) Sandboxes() sandbox.Store
func (m *DB) GarbageCollect(ctx context.Context) (gc.Stats, error)
```

### Transaction Model

```go
// Read transaction
err := db.View(func(tx *bolt.Tx) error {
    // Read operations
    return nil
})

// Write transaction
err := db.Update(func(tx *bolt.Tx) error {
    // Write operations
    return nil
})
```

### Garbage Collection

The metadata DB tracks all resource references:

```mermaid
graph TB
    Container[Container] -->|references| Image[Image]
    Image -->|references| Manifest[Manifest]
    Manifest -->|references| Config[Config]
    Manifest -->|references| Layer1[Layer 1]
    Manifest -->|references| Layer2[Layer 2]
    
    Lease[Lease] -.->|protects| Image
    Lease -.->|protects| Snapshot[Snapshot]
    
    GC[Garbage Collector] -.->|marks| Container
    GC -.->|marks| Image
    GC -.->|marks| Manifest
    GC -.->|sweeps unreferenced| Orphan[Orphaned Resources]
```

## 4. Containers Package

**Package**: `core/containers`  
**Purpose**: Container metadata management

### Container Structure

```go
type Container struct {
    ID          string            // Unique identifier
    Labels      map[string]string // Arbitrary metadata
    Image       string            // Image reference
    Runtime     RuntimeInfo       // Runtime configuration
    Spec        *types.Any        // OCI spec
    Snapshotter string            // Snapshotter name
    SnapshotKey string            // Snapshot identifier
    CreatedAt   time.Time
    UpdatedAt   time.Time
    Extensions  map[string]types.Any  // Custom extensions
    SandboxID   string            // Optional sandbox ID
}

type RuntimeInfo struct {
    Name    string      // Runtime name (e.g., "io.containerd.runc.v2")
    Options *types.Any  // Runtime-specific options
}
```

### Store Interface

```go
type Store interface {
    Get(ctx context.Context, id string) (Container, error)
    List(ctx context.Context, filters ...string) ([]Container, error)
    Create(ctx context.Context, container Container) (Container, error)
    Update(ctx context.Context, container Container, fieldpaths ...string) (Container, error)
    Delete(ctx context.Context, id string) error
}
```

### Container Lifecycle

```mermaid
stateDiagram-v2
    [*] --> Created: Create
    Created --> Updated: Update
    Updated --> Updated: Update
    Created --> Deleted: Delete
    Updated --> Deleted: Delete
    Deleted --> [*]
    
    note right of Created
        Container metadata exists
        No running process yet
    end note
```

## 5. Images Package

**Package**: `core/images`  
**Purpose**: Image metadata and manipulation

### Image Structure

```go
type Image struct {
    Name      string                 // Image name/tag
    Labels    map[string]string      // Metadata
    Target    ocispec.Descriptor     // Points to manifest
    CreatedAt time.Time
    UpdatedAt time.Time
}
```

### Store Interface

```go
type Store interface {
    Get(ctx context.Context, name string) (Image, error)
    List(ctx context.Context, filters ...string) ([]Image, error)
    Create(ctx context.Context, image Image) (Image, error)
    Update(ctx context.Context, image Image, fieldpaths ...string) (Image, error)
    Delete(ctx context.Context, name string, opts ...DeleteOpt) error
}
```

### Image Handlers

The package provides handlers for image operations:

```go
// Handler processes image content
type Handler interface {
    Handle(ctx context.Context, desc ocispec.Descriptor) (subdescs []ocispec.Descriptor, err error)
}

// HandlerFunc adapter
type HandlerFunc func(ctx context.Context, desc ocispec.Descriptor) ([]ocispec.Descriptor, error)
```

**Common Handlers**:
- **ChildrenHandler**: Walks image tree
- **FilterHandler**: Filters by platform
- **LimitHandler**: Limits concurrency
- **SetChildrenHandler**: Tracks children

### Image Walking

```mermaid
graph TB
    Manifest[Image Manifest]
    Config[Config]
    Layer1[Layer 1]
    Layer2[Layer 2]
    Layer3[Layer 3]
    
    Manifest -->|references| Config
    Manifest -->|references| Layer1
    Manifest -->|references| Layer2
    Manifest -->|references| Layer3
    
    Walker[Image Walker] -.->|visits| Manifest
    Walker -.->|visits| Config
    Walker -.->|visits| Layer1
    Walker -.->|visits| Layer2
    Walker -.->|visits| Layer3
```

## 6. Runtime Package

**Package**: `core/runtime`  
**Purpose**: Runtime abstractions for task management

### PlatformRuntime Interface

```go
type PlatformRuntime interface {
    // ID returns the runtime identifier
    ID() string
    
    // Create creates a task
    Create(ctx context.Context, taskID string, opts CreateOpts) (Task, error)
    
    // Get returns an existing task
    Get(ctx context.Context, taskID string) (Task, error)
    
    // Tasks returns all tasks
    Tasks(ctx context.Context, all bool) ([]Task, error)
    
    // Delete removes a task
    Delete(ctx context.Context, taskID string) (*Exit, error)
}
```

### Task Interface

```go
type Task interface {
    // ID of the task
    ID() string
    
    // Namespace of the task
    Namespace() string
    
    // PID of the init process
    PID(ctx context.Context) (uint32, error)
    
    // Start starts the task
    Start(ctx context.Context) error
    
    // State returns task state
    State(ctx context.Context) (State, error)
    
    // Kill sends signal to task
    Kill(ctx context.Context, signal uint32, all bool) error
    
    // Exec creates additional process
    Exec(ctx context.Context, id string, opts ExecOpts) (Process, error)
    
    // Pids returns all process IDs
    Pids(ctx context.Context) ([]ProcessInfo, error)
    
    // Pause pauses the task
    Pause(ctx context.Context) error
    
    // Resume resumes the task
    Resume(ctx context.Context) error
    
    // Wait waits for task exit
    Wait(ctx context.Context) (*Exit, error)
}
```

### CreateOpts

```go
type CreateOpts struct {
    Spec            typeurl.Any      // OCI runtime spec
    Rootfs          []mount.Mount    // Rootfs mounts
    IO              IO               // I/O configuration
    Checkpoint      string           // Checkpoint digest
    Runtime         string           // Runtime name
    RuntimeOptions  typeurl.Any      // Runtime options
    TaskOptions     typeurl.Any      // Task options
    SandboxID       string           // Optional sandbox ID
}
```

## 7. Leases Package

**Package**: `core/leases`  
**Purpose**: Resource lease management for GC

### Lease Structure

```go
type Lease struct {
    ID        string
    CreatedAt time.Time
    Labels    map[string]string
}
```

### Manager Interface

```go
type Manager interface {
    // Create creates a new lease
    Create(ctx context.Context, opts ...Opt) (Lease, error)
    
    // Delete removes a lease
    Delete(ctx context.Context, lease Lease, opts ...DeleteOpt) error
    
    // List returns all leases
    List(ctx context.Context, filters ...string) ([]Lease, error)
    
    // AddResource adds a resource to lease
    AddResource(ctx context.Context, lease Lease, resource Resource) error
    
    // DeleteResource removes resource from lease
    DeleteResource(ctx context.Context, lease Lease, resource Resource) error
    
    // ListResources lists resources in lease
    ListResources(ctx context.Context, lease Lease) ([]Resource, error)
}
```

### Resource Types

```go
type Resource struct {
    ID   string  // Resource identifier
    Type string  // Resource type
}
```

**Resource Types**:
- `content`: Content blobs
- `snapshots/<snapshotter>`: Snapshots
- `ingest`: Active ingestions

### Lease Workflow

```mermaid
sequenceDiagram
    participant Client
    participant Leases
    participant GC
    
    Client->>Leases: Create(lease)
    Leases-->>Client: Lease created
    
    Client->>Leases: AddResource(lease, snapshot)
    Client->>Leases: AddResource(lease, content)
    
    Note over GC: GC runs
    GC->>Leases: Check references
    Leases-->>GC: Resources protected
    
    Client->>Leases: Delete(lease)
    
    Note over GC: GC runs again
    GC->>GC: Resources can be collected
```

### Lease Options

```go
// WithExpiration sets lease expiration
func WithExpiration(d time.Duration) Opt

// WithLabels sets lease labels
func WithLabels(labels map[string]string) Opt

// WithID sets lease ID
func WithID(id string) Opt
```

## 8. Events Package

**Package**: `core/events`  
**Purpose**: Event publishing and subscription

### Publisher Interface

```go
type Publisher interface {
    Publish(ctx context.Context, topic string, event Event) error
}
```

### Subscriber Interface

```go
type Subscriber interface {
    Subscribe(ctx context.Context, filters ...string) (ch <-chan *Envelope, errs <-chan error)
}
```

### Event Envelope

```go
type Envelope struct {
    Timestamp time.Time
    Namespace string
    Topic     string
    Event     *types.Any
}
```

### Event Topics

**Container Events**:
- `/containers/create`
- `/containers/update`
- `/containers/delete`

**Task Events**:
- `/tasks/create`
- `/tasks/start`
- `/tasks/exit`
- `/tasks/delete`
- `/tasks/paused`
- `/tasks/resumed`

**Image Events**:
- `/images/create`
- `/images/update`
- `/images/delete`

**Snapshot Events**:
- `/snapshot/prepare`
- `/snapshot/commit`
- `/snapshot/remove`

### Event Exchange

```mermaid
graph LR
    P1[Publisher 1] -->|Publish| Exchange[Event Exchange]
    P2[Publisher 2] -->|Publish| Exchange
    P3[Publisher 3] -->|Publish| Exchange
    
    Exchange -->|Filter & Forward| S1[Subscriber 1]
    Exchange -->|Filter & Forward| S2[Subscriber 2]
    Exchange -->|Filter & Forward| S3[Subscriber 3]
```

## 9. Diff Package

**Package**: `core/diff`  
**Purpose**: Filesystem diff computation and application

### Applier Interface

```go
type Applier interface {
    // Apply applies a diff to a snapshot
    Apply(ctx context.Context, desc ocispec.Descriptor, mounts []mount.Mount, opts ...ApplyOpt) (ocispec.Descriptor, error)
}
```

### Comparer Interface

```go
type Comparer interface {
    // Compare computes diff between two snapshots
    Compare(ctx context.Context, a, b []mount.Mount, opts ...Opt) (ocispec.Descriptor, error)
}
```

### Apply Workflow

```mermaid
sequenceDiagram
    participant Client
    participant Differ
    participant Content
    participant Snapshot
    
    Client->>Differ: Apply(layer, mounts)
    Differ->>Content: Read(layer)
    Content-->>Differ: Tar stream
    Differ->>Snapshot: Extract to mounts
    Snapshot-->>Differ: Success
    Differ-->>Client: Applied descriptor
```

## 10. Sandbox Package

**Package**: `core/sandbox`  
**Purpose**: Sandbox (pod) management

### Sandbox Structure

```go
type Sandbox struct {
    ID          string
    Labels      map[string]string
    Runtime     RuntimeInfo
    Spec        *types.Any
    CreatedAt   time.Time
    UpdatedAt   time.Time
    Extensions  map[string]types.Any
}
```

### Controller Interface

```go
type Controller interface {
    // Create creates a sandbox
    Create(ctx context.Context, sandboxID string, opts ...CreateOpt) error
    
    // Start starts the sandbox
    Start(ctx context.Context, sandboxID string) (ControllerInstance, error)
    
    // Platform returns sandbox platform
    Platform(ctx context.Context, sandboxID string) (platforms.Platform, error)
    
    // Stop stops the sandbox
    Stop(ctx context.Context, sandboxID string, opts ...StopOpt) error
    
    // Wait waits for sandbox exit
    Wait(ctx context.Context, sandboxID string) (ExitStatus, error)
    
    // Status returns sandbox status
    Status(ctx context.Context, sandboxID string, verbose bool) (ControllerStatus, error)
    
    // Shutdown shuts down the controller
    Shutdown(ctx context.Context, sandboxID string) error
}
```

## Summary

The core packages provide:

1. **Content Store**: Immutable, content-addressable blob storage
2. **Snapshots**: Layered filesystem management with multiple implementations
3. **Metadata**: Centralized BoltDB storage for all metadata
4. **Containers**: Container metadata and lifecycle
5. **Images**: Image metadata and content walking
6. **Runtime**: Task execution abstractions
7. **Leases**: Resource protection from garbage collection
8. **Events**: Pub/sub event system
9. **Diff**: Filesystem diff operations
10. **Sandbox**: Pod-like container grouping

These packages form the foundation that plugins build upon, providing clean interfaces and separation of concerns throughout the containerd architecture.
